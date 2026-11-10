import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.ts";
import { openDb } from "../src/db/db.ts";
import { loadConfig } from "../src/config.ts";
import { signHmac } from "../src/auth/hmac.ts";

export const TEST_ENV = {
  CONTRACT_ID: "haggle.testnet",
  GAME_ACCOUNT_ID: "game.haggle.testnet",
  GAME_PRIVATE_KEY: "ed25519:x",
  WOODCUTTER_PRIVATE_KEY: "ed25519:x",
  FISHMONGER_PRIVATE_KEY: "ed25519:x",
  SMITH_PRIVATE_KEY: "ed25519:x",
  RBX_HMAC_SECRET: "secret",
};

function app() {
  const a = buildApp({ config: loadConfig(TEST_ENV), db: openDb(":memory:") });
  a.post("/rbx/echo", async (req) => ({ ok: true, body: req.body }));
  return a;
}

test("config lists every missing required var", () => {
  assert.throws(() => loadConfig({}), /CONTRACT_ID.*RBX_HMAC_SECRET/s);
});

test("config defaults", () => {
  const c = loadConfig(TEST_ENV);
  assert.equal(c.DAY_LENGTH_MS, 300_000);
  assert.equal(c.PORT, 8080);
  assert.equal(c.REPLAY_MODE, "off");
  assert.equal(c.NEAR_RPC_URL, "https://test.rpc.fastnear.com");
  assert.equal(c.LLM_BASE_URL, "https://cloud-api.near.ai/v1");
});

test("db applies schema", () => {
  const db = openDb(":memory:");
  const names = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all().map((r) => r.name);
  for (const t of ["chat_turn", "deal", "haggle_session", "llm_cache", "patience", "pending_gather", "player_profile", "price_point"]) {
    assert.ok(names.includes(t), t);
  }
});

test("/health", async () => {
  const r = await app().inject({ method: "GET", url: "/health" });
  assert.equal(r.statusCode, 200);
  assert.deepEqual(r.json(), { ok: true });
});

test("/rbx without hmac -> 401", async () => {
  const r = await app().inject({ method: "POST", url: "/rbx/echo", payload: { a: 1 } });
  assert.equal(r.statusCode, 401);
  assert.equal(r.json().error, "auth");
});

test("/rbx with valid hmac reaches handler", async () => {
  const body = JSON.stringify({ a: 1 });
  const ts = String(Date.now());
  const r = await app().inject({
    method: "POST",
    url: "/rbx/echo",
    headers: { "content-type": "application/json", "x-timestamp": ts, "x-signature": signHmac("secret", ts, body) },
    payload: body,
  });
  assert.equal(r.statusCode, 200);
  assert.deepEqual(r.json(), { ok: true, body: { a: 1 } });
});

test("errors use {error, message}", async () => {
  const a = app();
  a.get("/api/boom", async () => {
    throw Object.assign(new Error("nope"), { statusCode: 409, code: "deal_expired" });
  });
  const r = await a.inject({ method: "GET", url: "/api/boom" });
  assert.equal(r.statusCode, 409);
  assert.deepEqual(r.json(), { error: "deal_expired", message: "nope" });
});
