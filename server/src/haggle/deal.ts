import { KeyPair, type KeyPairString } from "near-api-js";

/** Deal as the contract's settle_deal expects it (U128/U64 as strings). */
export type ChainDeal = {
  merchant: string;
  player: string;
  good: string;
  qty: number;
  unit_price: string;
  side: string;
  nonce: string;
  expires_at_ns: string;
};

/** Byte-identical to contract/src/deals.rs deal_message. */
export function dealMessage(d: ChainDeal): string {
  return `haggle:v1|${d.merchant}|${d.player}|${d.good}|${d.qty}|${d.unit_price}|${d.side}|${d.nonce}|${d.expires_at_ns}`;
}

/** Base64 ed25519 signature by the merchant's own key. */
export function signDeal(d: ChainDeal, merchantKey: string): string {
  const sig = KeyPair.fromString(merchantKey as KeyPairString).sign(new TextEncoder().encode(dealMessage(d)));
  return Buffer.from(sig.signature).toString("base64");
}

let last = 0;
/** Microsecond clock, strictly increasing within the process; DB UNIQUE guards the rest. */
export function newNonce(): number {
  last = Math.max(Date.now() * 1000, last + 1);
  return last;
}
