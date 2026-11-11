import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import type { Gather } from "./gather.ts";
import type { Balances, PlayerView } from "../types.ts";
import { TOKEN_IDS } from "../items.ts";

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

  /** Registers on chain (1000 Coin once) whenever the contract does not know the player yet - also after a
   *  contract switch, when the profile row already exists. Later joins only refresh the profile. */
  async join(playerId: string, name: string): Promise<Balances> {
    const now = Date.now();
    if (!(await this.view(playerId))) await this.queue(() => this.chain.call("register_player", { player_id: playerId }));
    this.db
      .prepare(
        "INSERT INTO player_profile (player_id, display_name, first_seen, last_seen) VALUES (?, ?, ?, ?) ON CONFLICT DO UPDATE SET display_name = excluded.display_name, last_seen = excluded.last_seen",
      )
      .run(playerId, name, now, now);
    return this.balances(playerId);
  }

  view(playerId: string): Promise<PlayerView | null> {
    return this.chain.view<PlayerView | null>("get_player", { player_id: playerId });
  }

  /** Confirmed on-chain balances plus catches still waiting for the next batch; every token id present. */
  async balances(playerId: string, v?: PlayerView | null): Promise<Balances> {
    const view = v === undefined ? await this.view(playerId) : v;
    const p = this.gather.pending(playerId);
    return Object.fromEntries(TOKEN_IDS.map((k) => [k, Number(view?.balances?.[k] ?? 0) + (p[k] ?? 0)]));
  }

  deals(playerId: string): number {
    return (this.db.prepare("SELECT COUNT(*) n FROM deal WHERE player_id = ? AND status = 'settled'").get(playerId) as { n: number }).n;
  }

  touch(playerId: string) {
    this.db.prepare("UPDATE player_profile SET last_seen = ? WHERE player_id = ?").run(Date.now(), playerId);
  }
}
