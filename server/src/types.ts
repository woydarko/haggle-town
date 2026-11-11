import type { Category, Tier } from "./items.ts";

/** Token id -> amount: "coin" plus the 12 item ids (missing = 0). */
export type Balances = Record<string, number>;

/** Contract `get_market` row (one per merchant item) with numbers instead of U128 strings, plus the item's target stock. */
export type MarketView = {
  merchant: string;
  category: Category;
  item: string;
  tier: Tier;
  stock: number;
  target: number;
  purse: number;
  ask: number;
  bid: number;
  floor: number;
  ceiling_one: number | null;
  day: number;
  last_tick_ns: string;
};

/** Contract `get_player` view. */
export type PlayerView = { class: string | null; balances: Record<string, string> };
