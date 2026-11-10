import type { Chain } from "./near.ts";
import type { MarketView } from "../types.ts";

export class MarketCache {
  private rows: MarketView[] = [];
  private chain: Chain;
  /** Called after each refresh (Task 12 writes price points here). */
  onRefresh?: (rows: MarketView[]) => void;

  constructor(chain: Chain) {
    this.chain = chain;
  }

  get(): MarketView[] {
    return this.rows;
  }

  byAccount(id: string): MarketView | undefined {
    return this.rows.find((m) => m.account_id === id);
  }

  async refresh(): Promise<void> {
    const raw = await this.chain.view<any[]>("get_market", {});
    this.rows = raw.map((m) => ({
      account_id: m.account_id,
      good: m.good,
      stock: Number(m.stock),
      purse: Number(m.purse),
      target: Number(m.target),
      ask: Number(m.ask),
      bid: Number(m.bid),
      floor: Number(m.floor),
      ceiling_one: m.ceiling_one == null ? null : Number(m.ceiling_one),
      day: Number(m.day),
      last_tick_ns: String(m.last_tick_ns),
    }));
    this.onRefresh?.(this.rows);
  }
}
