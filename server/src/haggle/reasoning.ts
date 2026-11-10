import type { MarketView } from "../types.ts";

/** The tooltip under a merchant line. Built from the numbers only, so it is always true. */
export function reasoningLine(v: MarketView, side: "buy" | "sell", room: [number, number] | null): string {
  const stock = `Stock ${v.stock}/${v.target}`;
  if (side === "buy") {
    if (v.stock > v.target) {
      const off = Math.round((1 - room![0] / room![1]) * 100);
      return `${stock} - I want it gone: up to ${off}% off.`;
    }
    return `${stock} - running low, no discounts today.`;
  }
  if (!room) return "Purse is empty - not buying today.";
  if (v.stock < v.target) return `${stock} - I'll pay up to ${room[1]} C each.`;
  return `${stock} - I have plenty; ${room[0]} C each.`;
}
