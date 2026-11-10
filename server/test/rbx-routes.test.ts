import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.ts";
import { openDb } from "../src/db/db.ts";
import { loadConfig } from "../src/config.ts";
import { signHmac } from "../src/auth/hmac.ts";
import { createQueue } from "../src/chain/queue.ts";
import { MarketCache } from "../src/chain/market.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { rbxRoutes } from "../src/routes/rbx.ts";
import { FakeChain, PLAYER_VIEW, marketView } from "./fakes.ts";
import { TEST_ENV } from "./app.test.ts";

async function setup() {
  const chain = new FakeChain();
  chain.views.get_player = () => PLAYER_VIEW;
  chain.views.get_market = () => marketView();
  const db = openDb(":memory:");
  const queue = createQueue();
  const market = new MarketCache(chain);
  await market.refresh();
  const gather = new Gather(db, chain, queue);
  const players = new Players(db, chain, queue, gather);
  const app = buildApp({ config: loadConfig(TEST_ENV), db, routes: [rbxRoutes({ players, gather, market })] });
  return { app, chain, db };
}

function post(app: any, url: string, payload: object) {
  const body = JSON.stringify(payload);
  const ts = String(Date.now());
  return app.inject({
    method: "POST",
    url,
    headers: { "content-type": "application/json", "x-timestamp": ts, "x-signature": signHmac("secret", ts, body) },
    payload: body,
  });
}

test("/rbx/join registers once and returns balances", async () => {
  const { app, chain, db } = await setup();
  const r = await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  assert.equal(r.statusCode, 200);
  assert.deepEqual(r.json().balances, { coin: 1000, wood: 0, fish: 0, iron: 0 });
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  assert.equal(chain.calls.filter((c) => c.method === "register_player").length, 1);
  assert.deepEqual(chain.calls[0].args, { player_id: "roblox:42" });
  assert.equal((db.prepare("SELECT display_name FROM player_profile").get() as any).display_name, "Rina");
});

test("/rbx/gather adds pending and enforces cooldown", async () => {
  const { app } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  const a = await post(app, "/rbx/gather", { userId: "42", good: "wood" });
  assert.equal(a.statusCode, 200);
  assert.equal(a.json().balances.wood, 1);
  const b = await post(app, "/rbx/gather", { userId: "42", good: "wood" });
  assert.equal(b.statusCode, 429);
  assert.equal(b.json().error, "cooldown");
});

test("/rbx/gather rejects unknown good and bad userId", async () => {
  const { app } = await setup();
  assert.equal((await post(app, "/rbx/gather", { userId: "42", good: "gold" })).statusCode, 400);
  assert.equal((await post(app, "/rbx/gather", { userId: "abc", good: "wood" })).statusCode, 400);
});

test("/rbx/state returns balances and board", async () => {
  const { app } = await setup();
  const body = "";
  const ts = String(Date.now());
  const r = await app.inject({
    method: "GET",
    url: "/rbx/state?userId=42",
    headers: { "x-timestamp": ts, "x-signature": signHmac("secret", ts, body) },
  });
  assert.equal(r.statusCode, 200);
  assert.equal(r.json().board.length, 3);
  assert.equal(r.json().board[0].ask, 50);
  assert.equal(r.json().balances.coin, 1000);
});
