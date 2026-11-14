// TypeScript port of economy/src/pricing.rs. Must stay byte-for-byte equivalent:
// test/pricing-vectors.test.ts checks it against economy/test-vectors.json.
import { itemById, TIERS, type Tier } from "../items.ts";

const ODDS = [7000, 2200, 700, 100];
const SPECIALIST_ODDS = [5500, 3000, 1200, 300];

function def(id: string) {
  const it = itemById(id);
  if (!it) throw new Error(`unknown item ${id}`);
  return it;
}

export function ask(id: string, stock: number): number {
  const { base, target } = def(id);
  const raw = Math.floor((base * target) / Math.max(stock, 1));
  return Math.min(Math.max(raw, Math.floor(base / 2)), base * 3);
}

export function bid(id: string, stock: number): number {
  return Math.floor((ask(id, stock) * 80) / 100);
}

/** [floor, ask] for a player buying. */
export function buyRoom(id: string, stock: number): [number, number] {
  const a = ask(id, stock);
  const d = pctOver(stock, def(id).target, 40);
  return [Math.floor((a * (100 - d)) / 100), a];
}

/** [bid, ceiling] for a player selling `qty`; null when the purse cannot cover bid x qty. */
export function sellRoom(id: string, stock: number, purse: number, qty: number, specialist: boolean): [number, number] | null {
  const b = bid(id, stock);
  const q = Math.max(qty, 1);
  if (purse < b * q) return null;
  const p = pctOver(def(id).target, stock, 40);
  let ceil = Math.floor((b * (100 + p)) / 100);
  if (specialist) ceil = Math.floor((ceil * 110) / 100);
  return [b, Math.max(Math.min(ceil, Math.floor(purse / q)), b)];
}

/** Tier for a roll in 0..9999 basis points; quality 0..100 (clamped). */
export function rollTier(rollBp: number, specialist: boolean, quality: number): Tier {
  const base = specialist ? SPECIALIST_ODDS : ODDS;
  const q = Math.min(Math.max(Math.floor(Number.isFinite(quality) ? quality : 0), 0), 100);
  const shift = q * 20;
  const odds = [base[0] - shift, base[1] + Math.floor((shift * 6) / 10), base[2] + Math.floor((shift * 3) / 10), base[3] + Math.floor(shift / 10)];
  let acc = 0;
  for (let i = 0; i < 4; i++) {
    acc += odds[i];
    if (rollBp < acc) return TIERS[i];
  }
  return "legendary";
}

export function restock(stock: number, target: number): number {
  return Math.floor((Math.max(target - stock, 0) * 40) / 100);
}

export function burn(stock: number): number {
  return stock - Math.floor((stock * 10) / 100);
}

/** Port of pricing.rs price_ok: the room guards only the merchant; never 0. */
export function priceOk(buying: boolean, price: number, [lo, hi]: [number, number]): boolean {
  return price >= 1 && (buying ? price >= lo : price <= hi);
}

function pctOver(a: number, b: number, cap: number): number {
  if (a <= b || b === 0) return 0;
  return Math.min(Math.floor(((a - b) * 100) / b), cap);
}
