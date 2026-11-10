import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { ask, bid, buyRoom, sellRoom, burn } from "../src/haggle/pricing.ts";

const vectors = JSON.parse(readFileSync(new URL("../../economy/test-vectors.json", import.meta.url), "utf8"));

test("pricing port matches every Rust vector", () => {
  assert.equal(vectors.length, 297);
  for (const v of vectors) {
    const at = JSON.stringify(v);
    assert.equal(ask(v.good, v.stock, v.target), v.ask, at);
    assert.equal(bid(v.good, v.stock, v.target), v.bid, at);
    assert.deepEqual(buyRoom(v.good, v.stock, v.target), v.buy_room, at);
    assert.deepEqual(sellRoom(v.good, v.stock, v.target, v.purse, v.qty), v.sell_room, at);
    assert.equal(burn(v.stock), v.burn, at);
  }
});
