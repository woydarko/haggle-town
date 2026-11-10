export type Good = "wood" | "fish" | "iron";
export const GOODS: Good[] = ["wood", "fish", "iron"];

export type Balances = { coin: number; wood: number; fish: number; iron: number };
export const ZERO: Balances = { coin: 0, wood: 0, fish: 0, iron: 0 };

/** Contract `get_market` row with numbers instead of U128 strings. */
export type MarketView = {
  account_id: string;
  good: Good;
  stock: number;
  purse: number;
  target: number;
  ask: number;
  bid: number;
  floor: number;
  ceiling_one: number | null;
  day: number;
  last_tick_ns: string;
};
