import { test } from "node:test";
import assert from "node:assert/strict";
import { ago, lastDealLine, latestLines, merchantStats, priceMoves } from "../src/landing/stats.ts";
import type { Chat, Deal, Market } from "../src/api.ts";

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

const chat = (at: number, merchant: string, line: string): Chat => ({ at, merchant, line, mood: "pleased", source: "llm", reasoning: null });

test("latestLines: newest line per merchant, null when a merchant said nothing", () => {
  const out = latestLines([
    chat(NOW - 50_000, "woodcutter", "old"),
    chat(NOW - 10_000, "woodcutter.haggletown-v2.testnet", "new"),
    chat(NOW - 20_000, "smith", "iron"),
  ]);
  assert.equal(out.woodcutter?.line, "new");
  assert.equal(out.smith?.line, "iron");
  assert.equal(out.fishmonger, null);
});

test("priceMoves: up/down only for items whose ask changed since the last poll", () => {
  const prev = [row("w", "wood_pine", 30, 1, 0), row("w", "wood_oak", 40, 1, 0), row("w", "wood_maple", 50, 1, 0)];
  const next = [row("w", "wood_pine", 33, 1, 0), row("w", "wood_oak", 38, 1, 0), row("w", "wood_maple", 50, 1, 0), row("w", "wood_redwood", 90, 1, 0)];
  assert.deepEqual(priceMoves(prev, next), { wood_pine: "up", wood_oak: "down" });
  assert.deepEqual(priceMoves(null, next), {});
});
