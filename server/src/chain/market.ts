import type { Chain } from "./near.ts";
import type { MarketView } from "../types.ts";
import { itemById } from "../items.ts";

export class MarketCache {
  private rows: MarketView[] = [];
  private chain: Chain;
  /** Called after each refresh (price history writes points here). */
  onRefresh?: (rows: MarketView[]) => void;

  constructor(chain: Chain) {
    this.chain = chain;
  }

  get(): MarketView[] {
    return this.rows;
  }

  forMerchant(account: string): MarketView[] {
    return this.rows.filter((m) => m.merchant === account);
  }

  byItem(id: string): MarketView | undefined {
    return this.rows.find((m) => m.item === id);
  }

  async refresh(): Promise<void> {
    const raw = await this.chain.view<any[]>("get_market", {});
    this.rows = raw
      .filter((m) => itemById(m.item))
      .map((m) => ({
        merchant: m.merchant,
        category: m.category,
        item: m.item,
        tier: m.tier,
        stock: Number(m.stock),
        target: itemById(m.item)!.target,
        purse: Number(m.purse),
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
