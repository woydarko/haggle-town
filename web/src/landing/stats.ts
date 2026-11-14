import { MERCHANT_NAME, merchantKey, type Chat, type Deal, type Market } from "../api.ts";
import { itemName } from "../items.ts";

export type MerchantKey = "woodcutter" | "fishmonger" | "smith";
export type MerchantStat = { key: MerchantKey; purse: number; cheapest: { item: string; ask: number } | null };

export const MERCHANT_KEYS: MerchantKey[] = ["woodcutter", "fishmonger", "smith"];

export const ago = (t: number, now: number) => {
  const s = Math.max(0, Math.round((now - t) / 1000));
  return s < 60 ? `${s}s ago` : s < 3600 ? `${Math.round(s / 60)}m ago` : `${Math.round(s / 3600)}h ago`;
};

/** One row per merchant, always in the same order; cheapest is the lowest ask the merchant has in stock. */
export function merchantStats(market: Market[]): MerchantStat[] {
  return MERCHANT_KEYS.map((key) => {
    const rows = market.filter((r) => merchantKey(r.merchant) === key);
    const best = rows.filter((r) => r.stock > 0).sort((a, b) => a.ask - b.ask)[0];
    return { key, purse: rows[0]?.purse ?? 0, cheapest: best ? { item: best.item, ask: best.ask } : null };
  });
}

/** Newest deal as one line from the merchant's side ("buy" is the player buying, so the merchant sold). */
export function lastDealLine(deals: Deal[], now: number): string {
  const d = deals.reduce<Deal | undefined>((a, b) => (!a || b.at > a.at ? b : a), undefined);
  if (!d) return "Market just opened";
  const key = merchantKey(d.merchant);
  return `${MERCHANT_NAME[key] ?? key} ${d.side === "buy" ? "sold" : "bought"} ${d.qty} ${itemName(d.good)} @ ${d.unitPrice} C, ${ago(d.at, now)}`;
}

/** The newest chat line each merchant said, or null when it has said nothing yet. */
export function latestLines(chat: Chat[]): Record<MerchantKey, Chat | null> {
  const out: Record<MerchantKey, Chat | null> = { woodcutter: null, fishmonger: null, smith: null };
  for (const c of chat) {
    const k = merchantKey(c.merchant) as MerchantKey;
    if (k in out && (!out[k] || c.at > out[k]!.at)) out[k] = c;
  }
  return out;
}

/** Items whose ask moved since the previous poll; unchanged and new items are left out. */
export function priceMoves(prev: Market[] | null, next: Market[]): Record<string, "up" | "down"> {
  const before = new Map(prev?.map((r) => [r.item, r.ask]));
  const out: Record<string, "up" | "down"> = {};
  for (const r of next) {
    const b = before.get(r.item);
    if (b !== undefined && b !== r.ask) out[r.item] = r.ask > b ? "up" : "down";
  }
  return out;
}
