import type { Good } from "../types.ts";

export type Offer = { side?: "buy" | "sell"; qty?: number; unitPrice?: number; total?: number };

const GOOD = "(?:wood|kayu|logs?|fish|ikan|iron|besi|ore)";
const FOR_QTY = /(\d+)\s*(?:c|coins?|koin)?\s*(?:for|untuk|buat)\s*(\d+)\b/; // "40 for 5 wood"
const AT_UNIT = new RegExp(`(\\d+)\\s*(?:x\\s*)?${GOOD}?\\s*(?:at|@)\\s*(\\d+)`); // "5 iron at 30"
const QTY_TOTAL = new RegExp(`(\\d+)\\s*${GOOD}\\s*(?:for|untuk|buat|seharga|=)?\\s*(\\d+)`); // "3 ikan 90", "2 wood for 60"

/** Rule-based reading of an offer. Used by the fallback merchant and to sanity-check LLM replies. */
export function parseOffer(text: string, _good: Good): Offer {
  const t = text.toLowerCase();
  const out: Offer = {};
  if (/\b(sell|selling|jual)\b/.test(t)) out.side = "sell";
  else if (/\b(buy|buying|beli)\b/.test(t)) out.side = "buy";
  let m: RegExpMatchArray | null;
  if ((m = t.match(FOR_QTY))) {
    out.total = Number(m[1]);
    out.qty = Number(m[2]);
  } else if ((m = t.match(AT_UNIT))) {
    out.qty = Number(m[1]);
    out.unitPrice = Number(m[2]);
  } else if ((m = t.match(QTY_TOTAL))) {
    out.qty = Number(m[1]);
    out.total = Number(m[2]);
  } else if ((m = t.match(/(\d+)/))) {
    out.unitPrice = Number(m[1]);
  }
  return out;
}
