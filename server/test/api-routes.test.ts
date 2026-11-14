import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.ts";
import { openDb } from "../src/db/db.ts";
import { loadConfig } from "../src/config.ts";
import { MarketCache } from "../src/chain/market.ts";
import { apiRoutes } from "../src/routes/api.ts";
import { recordPrices } from "../src/game/history.ts";
import { FakeChain, marketView } from "./fakes.ts";
import { TEST_ENV } from "./app.test.ts";

async function setup() {
  const chain = new FakeChain();
  chain.views.get_market = () => marketView();
  const market = new MarketCache(chain);
  await market.refresh();
  const db = openDb(":memory:");
  db.prepare("INSERT INTO player_profile (player_id, display_name, first_seen, last_seen) VALUES ('roblox:42', 'Rina', 1, 1)").run();
  db.prepare("INSERT INTO haggle_session (id, player_id, merchant, opened_at) VALUES ('s1', 'roblox:42', 'smith', 1)").run();
  db.prepare(
    "INSERT INTO deal (id, session_id, merchant, player_id, good, side, qty, unit_price, nonce, expires_at, status, tx_hash, created_at) VALUES ('d1', 's1', 'smith', 'roblox:42', 'iron', 'buy', 2, 140, 1, 9, 'settled', 'TXHASH', 1000)",
  ).run();
  db.prepare(
    "INSERT INTO deal (id, session_id, merchant, player_id, good, side, qty, unit_price, nonce, expires_at, status, created_at) VALUES ('d2', 's1', 'smith', 'roblox:42', 'iron', 'buy', 1, 150, 2, 9, 'quoted', 1001)",
  ).run();
  db.prepare(
    "INSERT INTO chat_turn (session_id, role, text, mood, source, reasoning, created_at) VALUES ('s1', 'merchant', 'Ten? I have 3 iron left.', 'amused', 'llm', 'Stock 3/100 - running low.', 1002)",
  ).run();
  db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at, batch_tx) VALUES ('roblox:42', 'wood', 1, 900, 'BATCH1')").run();
  db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at) VALUES ('roblox:42', 'wood', 1, 950)").run();
  chain.views.get_player = ({ player_id }: any) => (player_id === "roblox:42" ? { class: "miner", balances: { coin: "860", wood_pine: "2", ore_iron: "2" } } : null);
  const app = buildApp({
    config: loadConfig(TEST_ENV),
    db,
    routes: [apiRoutes({ db, chain, market, leaderboard: () => [{ name: "Rina", netWorth: 1200 }], config: loadConfig(TEST_ENV) })],
  });
  return { app, db, market, chain };
}

test("/api/players lists players with deal counts, newest first", async () => {
  const { app } = await setup();
  const j = (await app.inject({ method: "GET", url: "/api/players" })).json();
  assert.deepEqual(j, [{ id: "roblox:42", name: "Rina", lastSeen: 1, deals: 1 }]);
});

test("/api/players/:id shows on-chain balances, deals and gathers with tx hashes", async () => {
  const { app } = await setup();
  const j = (await app.inject({ method: "GET", url: "/api/players/roblox:42" })).json();
  assert.equal(j.name, "Rina");
  assert.equal(j.class, "miner");
  assert.equal(j.balances.coin, 860);
  assert.equal(j.balances.ore_iron, 2);
  assert.equal(j.balances.fish_koi, 0);
  assert.equal(j.deals.length, 2); // settled and still-quoted deals, newest first
  assert.equal(j.deals[1].txHash, "TXHASH");
  assert.equal(j.deals[1].status, "settled");
  assert.deepEqual(j.gathers, [
    { at: 950, good: "wood", qty: 1, batchTx: null },
    { at: 900, good: "wood", qty: 1, batchTx: "BATCH1" },
  ]);
});

test("/api/players/:id rejects bad ids and 404s unknown players", async () => {
  const { app } = await setup();
  assert.equal((await app.inject({ method: "GET", url: "/api/players/steam:1" })).statusCode, 400);
  assert.equal((await app.inject({ method: "GET", url: "/api/players/roblox:7" })).statusCode, 404);
});

test("/api/config exposes only public values", async () => {
  const { app } = await setup();
  const r = await app.inject({ method: "GET", url: "/api/config" });
  assert.deepEqual(r.json(), { contractId: "haggle.testnet", network: "testnet", explorerBase: "https://testnet.nearblocks.io", dayLengthMs: 300_000 });
  assert.doesNotMatch(r.body, /PRIVATE|SECRET|ed25519:/i);
});

test("/api/feed shows settled deals with display names, never player ids", async () => {
  const { app } = await setup();
  const r = await app.inject({ method: "GET", url: "/api/feed" });
  const j = r.json();
  assert.equal(j.deals.length, 1);
  assert.deepEqual(j.deals[0], { at: 1000, player: "Rina", merchant: "smith", good: "iron", qty: 2, unitPrice: 140, side: "buy", txHash: "TXHASH" });
  assert.doesNotMatch(r.body, /roblox:42/);
  assert.equal(j.chat[0].line, "Ten? I have 3 iron left.");
  assert.equal(j.chat[0].reasoning, "Stock 3/100 - running low.");
});

test("/api/market and /api/leaderboard", async () => {
  const { app } = await setup();
  assert.equal((await app.inject({ method: "GET", url: "/api/market" })).json().length, 12);
  assert.deepEqual((await app.inject({ method: "GET", url: "/api/leaderboard" })).json(), [{ name: "Rina", netWorth: 1200 }]);
});

test("/api/history groups minute points by item", async () => {
  const { app, db, market } = await setup();
  const base = Math.floor(Date.now() / 60_000) * 60_000 - 10 * 60_000;
  recordPrices(db, market.get(), base);
  recordPrices(db, market.get(), base + 60_000);
  recordPrices(db, market.get(), base + 60_500); // same minute bucket -> replaces
  const j = (await app.inject({ method: "GET", url: "/api/history?minutes=60" })).json();
  assert.equal(j.length, 12);
  const wood = j.find((m: any) => m.item === "wood_pine");
  assert.equal(wood.name, "Pine");
  assert.equal(wood.tier, "common");
  assert.equal(wood.points.length, 2);
  assert.deepEqual(Object.keys(wood.points[0]).sort(), ["ask", "bid", "purse", "stock", "ts"]);
});

test("/api/coins returns each coin's info and its recent rebases", async () => {
  const { app, chain } = await setup();
  const asked: unknown[] = [];
  chain.view = async (method: string, args: object, contractId?: string) => {
    asked.push([method, contractId, args]);
    return (method === "info" ? { symbol: "SMITH", rebases: 40, total_supply: "1050000000" } : [{ day: 9, worth: "29000", step_bp: 120, supply: "1050000000" }]) as any;
  };
  const r = await app.inject({ method: "GET", url: "/api/coins" });
  assert.equal(r.statusCode, 200);
  const coins = r.json();
  assert.equal(coins.length, 3, "one per merchant (config default)");
  assert.equal(coins[0].recent[0].step_bp, 120);
  assert.ok(asked.some((a) => JSON.stringify(a) === JSON.stringify(["rebases", coins[0].id, { from: 10, limit: 30 }])), "last 30 rebases of that coin");
});
