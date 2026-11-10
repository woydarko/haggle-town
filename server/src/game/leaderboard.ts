import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { MarketCache } from "../chain/market.ts";

export type Row = { name: string; netWorth: number };

const ACTIVE_MS = 24 * 3_600_000;
const MAX_PLAYERS = 50;

/** Net worth = coin + goods valued at each merchant's current bid. Refreshed by a job every 30 s. */
export class Leaderboard {
  private rows: Row[] = [];
  private db: Db;
  private chain: Chain;
  private market: MarketCache;
  private now: () => number;

  constructor(db: Db, chain: Chain, market: MarketCache, now: () => number = Date.now) {
    this.db = db;
    this.chain = chain;
    this.market = market;
    this.now = now;
  }

  get(top = 10): Row[] {
    return this.rows.slice(0, top);
  }

  async refresh(): Promise<void> {
    const players = this.db
      .prepare("SELECT player_id, display_name FROM player_profile WHERE last_seen >= ? ORDER BY last_seen DESC LIMIT ?")
      .all(this.now() - ACTIVE_MS, MAX_PLAYERS) as { player_id: string; display_name: string }[];
    const bid: Record<string, number> = {};
    for (const m of this.market.get()) bid[m.good] = m.bid;
    const rows = await Promise.all(
      players.map(async (p) => {
        const v = await this.chain.view<Record<string, string> | null>("get_player", { player_id: p.player_id });
        const n = (k: string) => Number(v?.[k] ?? 0);
        const netWorth = n("coin") + n("wood") * (bid.wood ?? 0) + n("fish") * (bid.fish ?? 0) + n("iron") * (bid.iron ?? 0);
        return { name: p.display_name, netWorth };
      }),
    );
    this.rows = rows.sort((a, b) => b.netWorth - a.netWorth);
  }
}
