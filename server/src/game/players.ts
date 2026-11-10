import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import type { Gather } from "./gather.ts";
import type { Balances } from "../types.ts";

export class Players {
  private db: Db;
  private chain: Chain;
  private queue: Queue;
  private gather: Gather;

  constructor(db: Db, chain: Chain, queue: Queue, gather: Gather) {
    this.db = db;
    this.chain = chain;
    this.queue = queue;
    this.gather = gather;
  }

  /** First join registers on chain (1000 Coin once); later joins only refresh the profile. */
  async join(playerId: string, name: string): Promise<Balances> {
    const now = Date.now();
    const known = this.db.prepare("SELECT 1 FROM player_profile WHERE player_id = ?").get(playerId);
    if (!known) {
      await this.queue(() => this.chain.call("register_player", { player_id: playerId }));
      this.db
        .prepare("INSERT INTO player_profile (player_id, display_name, first_seen, last_seen) VALUES (?, ?, ?, ?)")
        .run(playerId, name, now, now);
    } else {
      this.db.prepare("UPDATE player_profile SET display_name = ?, last_seen = ? WHERE player_id = ?").run(name, now, playerId);
    }
    return this.balances(playerId);
  }

  /** Confirmed on-chain balances plus gathers still waiting for the next batch. */
  async balances(playerId: string): Promise<Balances> {
    const v = await this.chain.view<Record<string, string> | null>("get_player", { player_id: playerId });
    const p = this.gather.pending(playerId);
    const n = (k: string) => Number(v?.[k] ?? 0);
    return { coin: n("coin"), wood: n("wood") + p.wood, fish: n("fish") + p.fish, iron: n("iron") + p.iron };
  }

  touch(playerId: string) {
    this.db.prepare("UPDATE player_profile SET last_seen = ? WHERE player_id = ?").run(Date.now(), playerId);
  }
}
