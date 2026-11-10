import { test } from "node:test";
import assert from "node:assert/strict";
import { signHmac, verifyHmac } from "../src/auth/hmac.ts";

test("known vector (shared with roblox/tests/Hmac.spec.luau)", () => {
  assert.equal(
    signHmac("test-secret", "1700000000000", '{"userId":"1"}'),
    "fd8fa3b67297a5c514c607c493427bc035f17115d2679ef65cd8f0be55207782",
  );
});

test("roundtrip verifies", () => {
  const now = 1_700_000_000_000;
  const sig = signHmac("s", String(now), "{}");
  assert.equal(verifyHmac("s", String(now), "{}", sig, now), true);
});

test("tampered body fails", () => {
  const now = 1_700_000_000_000;
  const sig = signHmac("s", String(now), "{}");
  assert.equal(verifyHmac("s", String(now), '{"x":1}', sig, now), false);
});

test("stale timestamp fails", () => {
  const ts = 1_700_000_000_000;
  const sig = signHmac("s", String(ts), "{}");
  assert.equal(verifyHmac("s", String(ts), "{}", sig, ts + 61_000), false);
  assert.equal(verifyHmac("s", String(ts), "{}", sig, ts - 61_000), false);
});

test("garbage signature fails without throwing", () => {
  assert.equal(verifyHmac("s", "1", "{}", "zz", 1), false);
  assert.equal(verifyHmac("s", "abc", "{}", "00", 1), false);
});
