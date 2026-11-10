import { test } from "node:test";
import assert from "node:assert/strict";
import { KeyPair } from "near-api-js";
import { dealMessage, signDeal, newNonce } from "../src/haggle/deal.ts";

const DEAL = {
  merchant: "woodcutter.haggletown.testnet",
  player: "roblox:1",
  good: "wood",
  qty: 5,
  unit_price: "21",
  side: "buy",
  nonce: "7",
  expires_at_ns: "1700000000000000000",
} as const;

test("dealMessage matches contract format", () => {
  assert.equal(dealMessage(DEAL), "haggle:v1|woodcutter.haggletown.testnet|roblox:1|wood|5|21|buy|7|1700000000000000000");
});

test("signDeal verifies with the merchant public key", () => {
  const kp = KeyPair.fromRandom("ed25519");
  const sig = Buffer.from(signDeal(DEAL, kp.toString()), "base64");
  assert.equal(sig.length, 64);
  assert.equal(kp.verify(new TextEncoder().encode(dealMessage(DEAL)), sig), true);
});

test("nonces are unique and increasing", () => {
  const a = newNonce();
  const b = newNonce();
  assert.ok(b > a);
  assert.ok(Number.isSafeInteger(b));
});
