import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import { GOODS, type Good } from "../types.ts";

export const COOLDOWN_MS: Record<Good, number> = { wood: 3_000, fish: 6_000, iron: 10_000 };
const BATCH = 100;

type Pending = Record<Good, number>;

/** Gathers are credited instantly (pending rows) and minted on chain in one batch call per flush. */
export class Gather {
  private last = new Map<string, number>();
  private flushing = false;
  private db: Db;
  private chain: Chain;
  private queue: Queue;
  private now: () => number;

  constructor(db: Db, chain: Chain, queue: Queue, now: () => number = Date.now) {
    this.db = db;
    this.chain = chain;
    this.queue = queue;
    this.now = now;
  }

  request(playerId: string, good: Good): { pending: Pending; cooldownMs: number } | { error: "cooldown"; cooldownMs: number } {
    const key = `${playerId}|${good}`;
    const t = this.now();
    const wait = (this.last.get(key) ?? -Infinity) + COOLDOWN_MS[good] - t;
    if (wait > 0) return { error: "cooldown", cooldownMs: wait };
    this.last.set(key, t);
    this.db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at) VALUES (?, ?, 1, ?)").run(playerId, good, t);
    return { pending: this.pending(playerId), cooldownMs: COOLDOWN_MS[good] };
  }

  pending(playerId: string): Pending {
    const out: Pending = { wood: 0, fish: 0, iron: 0 };
    const rows = this.db
      .prepare("SELECT good, SUM(qty) n FROM pending_gather WHERE player_id = ? AND batch_tx IS NULL GROUP BY good")
      .all(playerId) as { good: Good; n: number }[];
    for (const r of rows) if (GOODS.includes(r.good)) out[r.good] = r.n;
    return out;
  }

  async flush(): Promise<void> {
    if (this.flushing) return;
    this.flushing = true;
    try {
      const rows = this.db
        .prepare("SELECT id, player_id, good, qty FROM pending_gather WHERE batch_tx IS NULL ORDER BY id LIMIT ?")
        .all(BATCH) as { id: number; player_id: string; good: Good; qty: number }[];
      if (!rows.length) return;
      const grouped = new Map<string, { player_id: string; good: Good; qty: number }>();
      for (const r of rows) {
        const k = `${r.player_id}|${r.good}`;
        const g = grouped.get(k) ?? { player_id: r.player_id, good: r.good, qty: 0 };
        g.qty += r.qty;
        grouped.set(k, g);
      }
      // shortcut: a crash between a successful tx and this UPDATE re-mints once; acceptable for testnet demo, fix with tx-hash reconciliation post-hackathon.
      const entries = [...grouped.values()].flatMap((g) => splitQty(g));
      try {
        const { txHash } = await this.queue(() => this.chain.call("gather_batch", { entries }));
        const mark = this.db.prepare("UPDATE pending_gather SET batch_tx = ? WHERE id = ?");
        for (const r of rows) mark.run(txHash, r.id);
      } catch {
        // rows stay pending; next flush retries
      }
    } finally {
      this.flushing = false;
    }
  }
}

/** Contract caps qty per entry at 20. */
function splitQty(g: { player_id: string; good: Good; qty: number }) {
  const out = [];
  for (let left = g.qty; left > 0; left -= 20) out.push({ ...g, qty: Math.min(20, left) });
  return out;
}
