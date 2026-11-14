import { test } from "node:test";
import assert from "node:assert/strict";
import { openDb } from "../src/db/db.ts";
import { MarketCache } from "../src/chain/market.ts";
import { Leaderboard } from "../src/game/leaderboard.ts";
import { FakeChain, marketView } from "./fakes.ts";

const NOW = 1_700_000_000_000;

async function setup() {
  const chain = new FakeChain();
  chain.views.get_market = () => marketView(); // bids at target: pine 12, iron 72
  const wallets: Record<string, any> = {
    "roblox:1": { class: null, balances: { coin: "1000" } }, // 1000
    "roblox:2": { class: "logger", balances: { coin: "900", wood_pine: "5", ore_iron: "1" } }, // 900 + 60 + 72 = 1032
    "roblox:3": { class: null, balances: { coin: "5000" } }, // inactive
  };
  chain.views.get_player = ({ player_id }) => wallets[player_id] ?? null;
  const db = openDb(":memory:");
  const add = db.prepare("INSERT INTO player_profile (player_id, display_name, first_seen, last_seen) VALUES (?, ?, ?, ?)");
  add.run("roblox:1", "Ana", NOW, NOW - 60_000);
  add.run("roblox:2", "Budi", NOW, NOW - 3_600_000);
  add.run("roblox:3", "Old", NOW, NOW - 25 * 3_600_000);
  const market = new MarketCache(chain);
  await market.refresh();
  const lb = new Leaderboard(db, chain, market, () => NOW);
  return { lb, chain };
}

test("ranks active players by net worth at current bid", async () => {
  const { lb } = await setup();
  await lb.refresh();
  assert.deepEqual(lb.get(), [
    { name: "Budi", netWorth: 1032, userId: "2" },
    { name: "Ana", netWorth: 1000, userId: "1" },
  ]);
});

test("players inactive for more than 24 h are excluded", async () => {
  const { lb } = await setup();
  await lb.refresh();
  assert.ok(!lb.get().some((r) => r.name === "Old"));
});

test("top limits the list", async () => {
  const { lb } = await setup();
  await lb.refresh();
  assert.equal(lb.get(1).length, 1);
});

test("a failing view keeps the previous board", async () => {
  const { lb, chain } = await setup();
  await lb.refresh();
  chain.views.get_player = () => {
    throw new Error("rpc down");
  };
  await lb.refresh().catch(() => undefined);
  assert.equal(lb.get().length, 2);
});

test("rank is 1-based and null for unknown players", async () => {
  const { lb } = await setup();
  await lb.refresh();
  assert.equal(lb.rank("roblox:2"), 1);
  assert.equal(lb.rank("roblox:1"), 2);
  assert.equal(lb.rank("roblox:3"), null);
});
