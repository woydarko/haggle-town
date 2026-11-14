import { test } from "node:test";
import assert from "node:assert/strict";
import { ago, lastDealLine, merchantStats } from "../src/landing/stats.ts";
import type { Deal, Market } from "../src/api.ts";

const NOW = 1_800_000_000_000;
const row = (merchant: string, item: string, ask: number, stock: number, purse: number): Market => ({
  merchant, category: "wood", item, tier: "common", stock, purse, target: 10, ask, bid: ask - 2, floor: 1, ceiling_one: null, day: 1,
});
const deal = (at: number, side: string, merchant = "fishmonger"): Deal => ({
  at, player: "lyrzabil", merchant, good: "fish_trout", qty: 3, unitPrice: 14, side, txHash: String(at),
});

test("merchantStats: fixed order, cheapest in-stock ask, empty merchants", () => {
  const out = merchantStats([
    row("woodcutter.haggletown-v2.testnet", "wood_pine", 30, 0, 500),
    row("woodcutter.haggletown-v2.testnet", "wood_oak", 40, 5, 500),
    row("woodcutter.haggletown-v2.testnet", "wood_maple", 55, 2, 500),
  ]);
  assert.deepEqual(out.map((m) => m.key), ["woodcutter", "fishmonger", "smith"]);
  assert.deepEqual(out[0], { key: "woodcutter", purse: 500, cheapest: { item: "wood_oak", ask: 40 } });
  assert.deepEqual(out[1], { key: "fishmonger", purse: 0, cheapest: null });
  assert.deepEqual(out[2], { key: "smith", purse: 0, cheapest: null });
});

test("lastDealLine: empty feed", () => {
  assert.equal(lastDealLine([], NOW), "Market just opened");
});

test("lastDealLine: newest deal, worded from the merchant's side", () => {
  const older = deal(NOW - 600_000, "sell", "smith.haggletown-v2.testnet");
  assert.equal(lastDealLine([older, deal(NOW - 12_000, "buy")], NOW), "Fishmonger sold 3 Trout @ 14 C, 12s ago");
  assert.equal(lastDealLine([deal(NOW - 12_000, "sell")], NOW), "Fishmonger bought 3 Trout @ 14 C, 12s ago");
});

test("ago: minutes round, future clamps to zero", () => {
  assert.equal(ago(NOW - 90_000, NOW), "2m ago");
  assert.equal(ago(NOW + 5_000, NOW), "0s ago");
});
