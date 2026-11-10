// TypeScript port of economy/src/pricing.rs. Must stay byte-for-byte equivalent:
// test/pricing-vectors.test.ts checks it against economy/test-vectors.json.
import type { Good } from "../types.ts";

const BASE: Record<Good, number> = { wood: 50, fish: 80, iron: 150 };

export function ask(good: Good, stock: number, target: number): number {
  const b = BASE[good];
  const raw = Math.floor((b * target) / Math.max(stock, 1));
  return Math.min(Math.max(raw, Math.floor(b / 2)), b * 3);
}

export function bid(good: Good, stock: number, target: number): number {
  return Math.floor((ask(good, stock, target) * 80) / 100);
}

/** [floor, ask] for a player buying. */
export function buyRoom(good: Good, stock: number, target: number): [number, number] {
  const a = ask(good, stock, target);
  const d = pctOver(stock, target, 40);
  return [Math.floor((a * (100 - d)) / 100), a];
}

/** [bid, ceiling] for a player selling `qty`; null when the purse cannot cover bid x qty. */
export function sellRoom(good: Good, stock: number, target: number, purse: number, qty: number): [number, number] | null {
  const b = bid(good, stock, target);
  const q = Math.max(qty, 1);
  if (purse < b * q) return null;
  const p = pctOver(target, stock, 40);
  const ceil = Math.min(Math.floor((b * (100 + p)) / 100), Math.floor(purse / q));
  return [b, Math.max(ceil, b)];
}

export function burn(stock: number): number {
  return stock - Math.floor((stock * 10) / 100);
}

function pctOver(a: number, b: number, cap: number): number {
  if (a <= b || b === 0) return 0;
  return Math.min(Math.floor(((a - b) * 100) / b), cap);
}
