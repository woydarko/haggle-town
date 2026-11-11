import type { Db } from "../db/db.ts";
import { ChainError, type Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import { HttpError } from "../errors.ts";
import { CLASS_CATEGORY } from "../items.ts";

export const CLASSES = Object.keys(CLASS_CATEGORY);
export const SWITCH_COOLDOWN_MS = 300_000; // one game day
export const SWITCH_FEE = 100; // burned on chain by set_class

/** Player class: first pick free, switching costs 100 C (contract) and waits one game day (here). */
export class Classes {
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

  get(playerId: string): string | null {
    const r = this.db.prepare("SELECT class FROM player_class WHERE player_id = ?").get(playerId) as { class: string } | undefined;
    return r?.class ?? null;
  }

  async choose(playerId: string, cls: string): Promise<{ class: string; fee: number }> {
    if (!CLASS_CATEGORY[cls]) throw new HttpError(400, "bad_class", "Pick Fisher, Logger or Miner.");
    const cur = this.db.prepare("SELECT class, changed_at FROM player_class WHERE player_id = ?").get(playerId) as
      | { class: string; changed_at: number }
      | undefined;
    if (cur?.class === cls) return { class: cls, fee: 0 };
    const wait = cur ? cur.changed_at + SWITCH_COOLDOWN_MS - this.now() : 0;
    if (wait > 0) throw new HttpError(429, "cooldown", `You can switch class again in ${Math.ceil(wait / 1000)} s.`);
    try {
      await this.queue(() => this.chain.call("set_class", { player_id: playerId, class: cls }));
    } catch (e) {
      if (e instanceof ChainError && e.code === "InsufficientFunds") throw new HttpError(409, "insufficient_funds", `Switching class costs ${SWITCH_FEE} C.`);
      if (e instanceof ChainError && e.code === "UnknownPlayer") throw new HttpError(409, "not_joined", "Join the game first.");
      throw e;
    }
    this.db
      .prepare("INSERT INTO player_class (player_id, class, changed_at) VALUES (?, ?, ?) ON CONFLICT DO UPDATE SET class = excluded.class, changed_at = excluded.changed_at")
      .run(playerId, cls, this.now());
    return { class: cls, fee: cur ? SWITCH_FEE : 0 };
  }
}
