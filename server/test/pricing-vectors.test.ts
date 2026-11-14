import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { ask, bid, buyRoom, sellRoom, burn, restock, rollTier, priceOk, TOOL_PRICE } from "../src/haggle/pricing.ts";
import { ITEMS, itemById } from "../src/items.ts";

const v = JSON.parse(readFileSync(new URL("../../economy/test-vectors.json", import.meta.url), "utf8"));

test("tool price matches pricing.rs", () => assert.equal(TOOL_PRICE, v.tool_price));

test("items table matches the Rust ids", () => {
  assert.equal(ITEMS.length, 12);
  assert.equal(itemById("fish_koi")?.name, "Golden Koi");
  assert.equal(itemById("ore_iron")?.tier, "rare");
  assert.equal(itemById("wood"), undefined);
});

test("pricing port matches every Rust price vector", () => {
  assert.equal(v.prices.length, 768);
  for (const p of v.prices) {
    const at = JSON.stringify(p);
    assert.equal(ask(p.item, p.stock), p.ask, at);
    assert.equal(bid(p.item, p.stock), p.bid, at);
    assert.deepEqual(buyRoom(p.item, p.stock), p.buy_room, at);
    assert.deepEqual(sellRoom(p.item, p.stock, p.purse, p.qty, p.specialist), p.sell_room, at);
    assert.equal(burn(p.stock), p.burn, at);
    assert.equal(restock(p.stock, itemById(p.item)!.target), p.restock, at);
  }
});

test("drop rolls match every Rust roll vector", () => {
  for (const r of v.rolls) assert.equal(rollTier(r.roll, r.specialist, r.quality), r.tier, JSON.stringify(r));
});

test("priceOk mirrors pricing.rs price_ok_guards_only_the_merchant", () => {
  assert.ok(priceOk(true, 6, [6, 10]) && priceOk(true, 50, [6, 10]) && !priceOk(true, 5, [6, 10]));
  assert.ok(priceOk(false, 10, [6, 10]) && priceOk(false, 1, [6, 10]) && !priceOk(false, 11, [6, 10]));
  assert.ok(!priceOk(false, 0, [6, 10]) && !priceOk(true, 0, [0, 10]));
});
