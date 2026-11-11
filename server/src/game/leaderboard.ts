import type { Db } from "../db/db.ts";
import type { Chain } from "../chain/near.ts";
import type { MarketCache } from "../chain/market.ts";
import type { Balances, PlayerView } from "../types.ts";

export type Row = { name: string; netWorth: number };

const ACTIVE_MS = 24 * 3_600_000;
const MAX_PLAYERS = 50;

/** Coin plus every item valued at its merchant's current bid. */
export function netWorth(b: Balances, market: MarketCache): number {
  let sum = b.coin ?? 0;
  for (const [id, qty] of Object.entries(b)) if (id !== "coin" && qty > 0) sum += qty * (market.byItem(id)?.bid ?? 0);
  return sum;
}

/** Refreshed by a job every 30 s. Player ids stay internal (rank lookup); rows are public. */
export class Leaderboard {
  private rows: (Row & { id: string })[] = [];
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
    return this.rows.slice(0, top).map(({ name, netWorth }) => ({ name, netWorth }));
  }

  /** 1-based rank among active players, null when not ranked yet. */
  rank(playerId: string): number | null {
    const i = this.rows.findIndex((r) => r.id === playerId);
    return i < 0 ? null : i + 1;
  }

  async refresh(): Promise<void> {
    const players = this.db
      .prepare("SELECT player_id, display_name FROM player_profile WHERE last_seen >= ? ORDER BY last_seen DESC LIMIT ?")
      .all(this.now() - ACTIVE_MS, MAX_PLAYERS) as { player_id: string; display_name: string }[];
    const rows = await Promise.all(
      players.map(async (p) => {
        const v = await this.chain.view<PlayerView | null>("get_player", { player_id: p.player_id });
        const b = Object.fromEntries(Object.entries(v?.balances ?? {}).map(([k, x]) => [k, Number(x)]));
        return { id: p.player_id, name: p.display_name, netWorth: netWorth(b, this.market) };
      }),
    );
    this.rows = rows.sort((a, b) => b.netWorth - a.netWorth);
  }
}
