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
import { Classes } from "../src/game/classes.ts";
import { rbxRoutes } from "../src/routes/rbx.ts";
import { FakeChain, marketView } from "./fakes.ts";
import { TEST_ENV } from "./app.test.ts";

async function setup() {
  const chain = new FakeChain();
  const wallets: Record<string, { class: string | null; balances: Record<string, string> }> = {};
  chain.views["register_player:result"] = ({ player_id }) => (wallets[player_id] = { class: null, balances: { coin: "1000" } });
  chain.views["set_class:result"] = ({ player_id, class: cls }) => (wallets[player_id].class = cls);
  chain.views.get_player = ({ player_id }) => wallets[player_id] ?? null;
  chain.views.get_market = () => marketView();
  const db = openDb(":memory:");
  const queue = createQueue();
  const clock = { t: 1_700_000_000_000 };
  const market = new MarketCache(chain);
  await market.refresh();
  const classes = new Classes(db, chain, queue, () => clock.t);
  const gather = new Gather(db, chain, queue, () => clock.t, { rand: () => 0, classOf: (id) => classes.get(id) });
  const players = new Players(db, chain, queue, gather);
  const leaderboard = { get: () => [], rank: (id: string) => (id === "roblox:42" ? 1 : null) };
  const app = buildApp({ config: loadConfig(TEST_ENV), db, routes: [rbxRoutes({ players, gather, market, classes, leaderboard })] });
  return { app, chain, db, clock, wallets };
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

function get(app: any, url: string) {
  const ts = String(Date.now());
  return app.inject({ method: "GET", url, headers: { "x-timestamp": ts, "x-signature": signHmac("secret", ts, "") } });
}

test("/rbx/join registers once and returns the full balances map", async () => {
  const { app, chain, db } = await setup();
  const r = await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  assert.equal(r.statusCode, 200);
  const b = r.json().balances;
  assert.equal(b.coin, 1000);
  assert.equal(Object.keys(b).length, 13);
  assert.equal(b.fish_koi, 0);
  assert.equal(r.json().class, null);
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  assert.equal(chain.calls.filter((c) => c.method === "register_player").length, 1);
  assert.equal((db.prepare("SELECT display_name FROM player_profile").get() as any).display_name, "Rina");
});

test("join re-registers a known profile that the (new) contract does not know", async () => {
  const { app, chain, db } = await setup();
  db.prepare("INSERT INTO player_profile (player_id, display_name, first_seen, last_seen) VALUES ('roblox:42', 'Rina', 1, 1)").run();
  const r = await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  assert.equal(r.json().balances.coin, 1000);
  assert.equal(chain.calls.filter((c) => c.method === "register_player").length, 1);
});

test("gather start -> finish credits a pending item", async () => {
  const { app, clock } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  const s = await post(app, "/rbx/gather/start", { userId: "42", node: "wood" });
  assert.equal(s.statusCode, 200);
  assert.equal(s.json().params.minMs, 3_000);
  const early = await post(app, "/rbx/gather/finish", { userId: "42", sessionId: s.json().sessionId, quality: 1 });
  assert.equal(early.statusCode, 422);
  clock.t += 3_500;
  const f = await post(app, "/rbx/gather/finish", { userId: "42", sessionId: s.json().sessionId, quality: 1 });
  assert.equal(f.statusCode, 200);
  assert.deepEqual(f.json().catch, { item: "wood_pine", name: "Pine", tier: "common", qty: 1 });
  assert.equal(f.json().balances.wood_pine, 1);
  assert.equal((await post(app, "/rbx/gather/finish", { userId: "42", sessionId: s.json().sessionId, quality: 1 })).statusCode, 409);
});

test("gather rejects bad node, bad userId and the removed v1 route", async () => {
  const { app } = await setup();
  assert.equal((await post(app, "/rbx/gather/start", { userId: "42", node: "lava" })).statusCode, 400);
  assert.equal((await post(app, "/rbx/gather/start", { userId: "abc", node: "wood" })).statusCode, 400);
  assert.equal((await post(app, "/rbx/gather/finish", { userId: "42", sessionId: "x", quality: "high" })).statusCode, 400);
  assert.equal((await post(app, "/rbx/gather", { userId: "42", good: "wood" })).statusCode, 404);
});

test("class: first pick free, switch waits a game day, then costs coin", async () => {
  const { app, chain, clock } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  const a = await post(app, "/rbx/class", { userId: "42", class: "fisher" });
  assert.equal(a.statusCode, 200);
  assert.equal(a.json().fee, 0);
  const again = await post(app, "/rbx/class", { userId: "42", class: "fisher" });
  assert.equal(again.json().fee, 0, "same class is a no-op");
  const soon = await post(app, "/rbx/class", { userId: "42", class: "miner" });
  assert.equal(soon.statusCode, 429);
  clock.t += 300_000;
  chain.panicOn.set_class = ["InsufficientFunds"];
  const broke = await post(app, "/rbx/class", { userId: "42", class: "miner" });
  assert.equal(broke.statusCode, 409);
  assert.equal(broke.json().error, "insufficient_funds");
  const ok = await post(app, "/rbx/class", { userId: "42", class: "miner" });
  assert.equal(ok.json().fee, 100);
  assert.equal(chain.calls.filter((c) => c.method === "set_class").length, 3);
  assert.equal((await post(app, "/rbx/class", { userId: "42", class: "wizard" })).statusCode, 400);
});

test("specialist gets the bigger catch zone", async () => {
  const { app } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  await post(app, "/rbx/class", { userId: "42", class: "logger" });
  assert.equal((await post(app, "/rbx/gather/start", { userId: "42", node: "wood" })).json().params.zoneScale, 1.3);
  assert.equal((await post(app, "/rbx/gather/start", { userId: "42", node: "fish" })).json().params.zoneScale, 1);
});

test("/rbx/stats shape", async () => {
  const { app, clock, db } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  await post(app, "/rbx/class", { userId: "42", class: "miner" });
  const s = await post(app, "/rbx/gather/start", { userId: "42", node: "ore_mouth" });
  clock.t += 4_000;
  await post(app, "/rbx/gather/finish", { userId: "42", sessionId: s.json().sessionId, quality: 0 });
  db.prepare("INSERT INTO haggle_session (id, player_id, merchant, opened_at) VALUES ('s', 'roblox:42', 'smith', 1)").run();
  db.prepare("INSERT INTO deal (id, session_id, merchant, player_id, good, side, qty, unit_price, nonce, expires_at, status, created_at) VALUES ('d', 's', 'smith', 'roblox:42', 'ore_copper', 'sell', 1, 24, 1, 9, 'settled', 1)").run();
  const r = await get(app, "/rbx/stats?userId=42");
  assert.equal(r.statusCode, 200);
  const j = r.json();
  assert.equal(j.class, "miner");
  assert.equal(j.balances.ore_copper, 2); // miner + rand 0 -> double drop
  assert.equal(j.netWorth, 1000 + 2 * 24); // copper bid at target stock
  assert.deepEqual(j.bestCatch, { item: "ore_copper", name: "Copper", tier: "common" });
  assert.equal(j.deals, 1);
  assert.equal(j.rank, 1);
});

test("/rbx/state returns balances and the per-item board", async () => {
  const { app } = await setup();
  await post(app, "/rbx/join", { userId: "42", name: "Rina" });
  const r = await get(app, "/rbx/state?userId=42");
  assert.equal(r.statusCode, 200);
  assert.equal(r.json().board.length, 12);
  assert.equal(r.json().board.find((m: any) => m.item === "ore_crystal").ask, 900);
  assert.equal(r.json().balances.coin, 1000);
});
