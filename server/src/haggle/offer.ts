export type Offer = { side?: "buy" | "sell"; qty?: number; unitPrice?: number; total?: number; item?: string };

/** Item names (English + Indonesian) -> item id. Longest first so "golden koi" wins over "koi". */
const ALIASES: [string, string][] = [
  ["golden koi", "fish_koi"],
  ["ancient redwood", "wood_redwood"],
  ["sardine", "fish_sardine"],
  ["trout", "fish_trout"],
  ["salmon", "fish_salmon"],
  ["koi", "fish_koi"],
  ["pine", "wood_pine"],
  ["oak", "wood_oak"],
  ["maple", "wood_maple"],
  ["redwood", "wood_redwood"],
  ["copper", "ore_copper"],
  ["tembaga", "ore_copper"],
  ["iron", "ore_iron"],
  ["besi", "ore_iron"],
  ["gold", "ore_gold"],
  ["emas", "ore_gold"],
  ["crystal", "ore_crystal"],
  ["kristal", "ore_crystal"],
];
const ITEM_RE = ALIASES.map(([w, id]) => [new RegExp(`\\b${w}s?\\b`), id] as const);
const GOOD = `(?:(?:${[...ALIASES.map((a) => a[0]), "wood", "kayu", "logs?", "fish", "ikan", "ore"].join("|")})s?)`;
const FOR_QTY = /(\d+)\s*(?:c|coins?|koin)?\s*(?:for|untuk|buat)\s*(\d+)\b/; // "40 for 5 wood"
const AT_UNIT = new RegExp(`(\\d+)\\s*(?:x\\s*)?${GOOD}?\\s*(?:at|@)\\s*(\\d+)`); // "5 iron at 30"
const QTY_TOTAL = new RegExp(`(\\d+)\\s*${GOOD}\\s*(?:for|untuk|buat|seharga|=)?\\s*(\\d+)`); // "3 ikan 90", "2 trout for 200"

/** Rule-based reading of an offer. Used by the fallback merchant and to pick the item being haggled. */
export function parseOffer(text: string): Offer {
  const t = text.toLowerCase();
  const out: Offer = {};
  if (/\b(sell|selling|jual)\b/.test(t)) out.side = "sell";
  else if (/\b(buy|buying|beli)\b/.test(t)) out.side = "buy";
  const hit = ITEM_RE.find(([re]) => re.test(t));
  if (hit) out.item = hit[1];
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
