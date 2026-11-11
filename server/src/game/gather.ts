import { randomUUID } from "node:crypto";
import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import { HttpError } from "../errors.ts";
import { CLASS_CATEGORY, itemById, itemOf, type Category, type Tier } from "../items.ts";
import { rollTier } from "../haggle/pricing.ts";

/** Gather nodes. minMs = shortest human run of that minigame; faster finishes are rejected. */
export const NODES: Record<string, { category: Category; minMs: number }> = {
  fish: { category: "fish", minMs: 6_000 },
  wood: { category: "wood", minMs: 3_000 },
  ore_mouth: { category: "ore", minMs: 3_500 },
  ore_deep: { category: "ore", minMs: 3_500 },
  wood_old: { category: "wood", minMs: 3_000 },
  fish_deep: { category: "fish", minMs: 6_000 },
};
/** Remote spots (deep cave, ancient grove, sea): same odds tables, +DEEP_QUALITY_BONUS quality. */
const DEEP_NODES = new Set(["ore_deep", "wood_old", "fish_deep"]);
const SESSION_TTL_MS = 60_000;
const SPECIALIST_ZONE = 1.3;
const DOUBLE_DROP = 0.15;
const DEEP_QUALITY_BONUS = 20;
const BATCH = 100;

export type StartResult = { sessionId: string; node: string; params: { zoneScale: number; fishSpeed: number; minMs: number } };
export type Catch = { item: string; name: string; tier: Tier; qty: number };
export type GatherOpts = { rand?: () => number; classOf?: (playerId: string) => string | null };

type SessionRow = { id: string; player_id: string; node: string; roll_bp: number; started_at: number; closed_at: number | null };

/** Minigame sessions decide the catch server-side; catches are credited instantly (pending rows)
 *  and minted on chain in one gather_batch call per flush. */
export class Gather {
  private flushing = false;
  private db: Db;
  private chain: Chain;
  private queue: Queue;
  private now: () => number;
  private rand: () => number;
  private classOf: (playerId: string) => string | null;

  constructor(db: Db, chain: Chain, queue: Queue, now: () => number = Date.now, opts: GatherOpts = {}) {
    this.db = db;
    this.chain = chain;
    this.queue = queue;
    this.now = now;
    this.rand = opts.rand ?? Math.random;
    this.classOf = opts.classOf ?? (() => null);
  }

  /** Opens a session (closing any earlier open one: one minigame at a time). The tier roll is fixed now; quality shifts it at finish. */
  start(playerId: string, node: string): StartResult {
    const n = NODES[node];
    if (!n) throw new HttpError(400, "bad_node", "Nothing to gather here.");
    const t = this.now();
    this.db.prepare("UPDATE gather_session SET closed_at = ? WHERE player_id = ? AND closed_at IS NULL").run(t, playerId);
    const id = randomUUID();
    const roll = Math.min(Math.floor(this.rand() * 10_000), 9_999);
    this.db
      .prepare("INSERT INTO gather_session (id, player_id, node, roll_bp, started_at) VALUES (?, ?, ?, ?, ?)")
      .run(id, playerId, node, roll, t);
    const specialist = this.specialist(playerId, n.category);
    return {
      sessionId: id,
      node,
      params: {
        zoneScale: specialist ? SPECIALIST_ZONE : 1,
        fishSpeed: n.category === "fish" ? Math.round((1 + roll / 10_000) * 100) / 100 : 1, // rarer rolls dart faster
        minMs: n.minMs,
      },
    };
  }

  /** quality 0..1 from the client minigame (clamped; it can shift odds by at most one tier step). */
  finish(playerId: string, sessionId: string, quality: number): Catch {
    const s = this.db.prepare("SELECT * FROM gather_session WHERE id = ?").get(sessionId) as SessionRow | undefined;
    if (!s || s.player_id !== playerId) throw new HttpError(404, "no_session", "No such gathering.");
    if (s.closed_at !== null) throw new HttpError(409, "session_closed", "That gathering is already over.");
    const t = this.now();
    const elapsed = t - s.started_at;
    if (elapsed > SESSION_TTL_MS) {
      this.db.prepare("UPDATE gather_session SET closed_at = ? WHERE id = ?").run(t, s.id);
      throw new HttpError(409, "session_closed", "Took too long - it got away.");
    }
    const n = NODES[s.node];
    if (elapsed < n.minMs) throw new HttpError(422, "too_fast", "Too fast.");

    const q01 = Number.isFinite(quality) ? Math.min(Math.max(quality, 0), 1) : 0;
    const q = Math.min(Math.round(q01 * 100) + (DEEP_NODES.has(s.node) ? DEEP_QUALITY_BONUS : 0), 100);
    const specialist = this.specialist(playerId, n.category);
    let tier = rollTier(s.roll_bp, specialist, q);
    if (s.node === "ore_mouth" && tier === "legendary") tier = "epic"; // crystal only grows deep in the cave
    const item = itemOf(n.category, tier);
    const qty = specialist && this.rand() < DOUBLE_DROP ? 2 : 1;
    this.db.prepare("UPDATE gather_session SET closed_at = ?, item = ?, qty = ? WHERE id = ?").run(t, item.id, qty, s.id);
    this.db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at) VALUES (?, ?, ?, ?)").run(playerId, item.id, qty, t);
    return { item: item.id, name: item.name, tier, qty };
  }

  /** Highest-value item this player has ever caught. */
  bestCatch(playerId: string): { item: string; name: string; tier: Tier } | null {
    const rows = this.db.prepare("SELECT DISTINCT item FROM gather_session WHERE player_id = ? AND item IS NOT NULL").all(playerId) as { item: string }[];
    const best = rows
      .map((r) => itemById(r.item))
      .filter((i) => i !== undefined)
      .sort((a, b) => b.base - a.base)[0];
    return best ? { item: best.id, name: best.name, tier: best.tier } : null;
  }

  /** Item id -> qty caught but not yet minted. */
  pending(playerId: string): Record<string, number> {
    const rows = this.db
      .prepare("SELECT good, SUM(qty) n FROM pending_gather WHERE player_id = ? AND batch_tx IS NULL GROUP BY good")
      .all(playerId) as { good: string; n: number }[];
    return Object.fromEntries(rows.filter((r) => itemById(r.good)).map((r) => [r.good, r.n]));
  }

  async flush(): Promise<void> {
    if (this.flushing) return;
    this.flushing = true;
    try {
      const all = this.db
        .prepare("SELECT id, player_id, good, qty FROM pending_gather WHERE batch_tx IS NULL ORDER BY id LIMIT ?")
        .all(BATCH) as { id: number; player_id: string; good: string; qty: number }[];
      // v1 rows ("wood", "iron") would make every batch panic on the v2 contract: park them.
      const mark = this.db.prepare("UPDATE pending_gather SET batch_tx = ? WHERE id = ?");
      for (const r of all) if (!itemById(r.good)) mark.run("invalid", r.id);
      const rows = all.filter((r) => itemById(r.good));
      if (!rows.length) return;
      const grouped = new Map<string, { player_id: string; good: string; qty: number }>();
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
        for (const r of rows) mark.run(txHash, r.id);
      } catch {
        // rows stay pending; next flush retries
      }
    } finally {
      this.flushing = false;
    }
  }

  private specialist(playerId: string, category: Category): boolean {
    const cls = this.classOf(playerId);
    return cls !== null && CLASS_CATEGORY[cls] === category;
  }
}

/** Contract caps qty per entry at 20. */
function splitQty(g: { player_id: string; good: string; qty: number }) {
  const out = [];
  for (let left = g.qty; left > 0; left -= 20) out.push({ ...g, qty: Math.min(20, left) });
  return out;
}
