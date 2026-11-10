import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { openDb } from "../src/db/db.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { FakeChain } from "./fakes.ts";

function setup(path = ":memory:", clock = { t: 1_000_000 }) {
  const chain = new FakeChain();
  const db = openDb(path);
  const g = new Gather(db, chain, createQueue(), () => clock.t);
  return { chain, db, g, clock };
}

test("gather respects cooldown", () => {
  const { g, clock } = setup();
  const a = g.request("roblox:1", "wood");
  assert.ok(!("error" in a));
  const b = g.request("roblox:1", "wood");
  assert.ok("error" in b && b.error === "cooldown" && b.cooldownMs > 0);
  clock.t += 3_000;
  assert.ok(!("error" in g.request("roblox:1", "wood")));
});

test("cooldowns differ per good and player", () => {
  const { g, clock } = setup();
  g.request("roblox:1", "iron");
  clock.t += 6_000;
  assert.ok("error" in g.request("roblox:1", "iron"), "iron cooldown 10s");
  assert.ok(!("error" in g.request("roblox:1", "fish")));
  assert.ok(!("error" in g.request("roblox:2", "iron")));
});

test("pending counts are returned", () => {
  const { g, clock } = setup();
  g.request("roblox:1", "wood");
  clock.t += 3_000;
  const r = g.request("roblox:1", "wood");
  assert.ok(!("error" in r));
  assert.equal(r.pending.wood, 2);
});

test("flush batches pending and marks them", async () => {
  const { g, chain, db, clock } = setup();
  g.request("roblox:1", "wood");
  clock.t += 3_000;
  g.request("roblox:1", "wood");
  g.request("roblox:2", "fish");
  await g.flush();
  assert.equal(chain.calls.length, 1);
  assert.equal(chain.calls[0].method, "gather_batch");
  const entries = chain.calls[0].args.entries;
  assert.deepEqual(
    entries.sort((x: any, y: any) => x.player_id.localeCompare(y.player_id)),
    [{ player_id: "roblox:1", good: "wood", qty: 2 }, { player_id: "roblox:2", good: "fish", qty: 1 }],
  );
  assert.equal((db.prepare("SELECT COUNT(*) n FROM pending_gather WHERE batch_tx IS NULL").get() as any).n, 0);
  assert.equal(g.pending("roblox:1").wood, 0);
  await g.flush();
  assert.equal(chain.calls.length, 1, "nothing left to flush");
});

test("flush failure keeps rows pending", async () => {
  const { g, chain } = setup();
  g.request("roblox:1", "wood");
  chain.failNext = new Error("rpc down");
  await g.flush();
  assert.equal(g.pending("roblox:1").wood, 1);
  await g.flush();
  assert.equal(chain.calls.length, 2);
  assert.equal(g.pending("roblox:1").wood, 0);
});

test("pending survives restart", async () => {
  const path = join(mkdtempSync(join(tmpdir(), "haggle-")), "db.sqlite");
  const first = setup(path);
  first.g.request("roblox:1", "wood");
  first.db.close();
  const second = setup(path);
  await second.g.flush();
  assert.equal(second.chain.calls.length, 1);
  assert.deepEqual(second.chain.calls[0].args.entries, [{ player_id: "roblox:1", good: "wood", qty: 1 }]);
  await second.g.flush();
  assert.equal(second.chain.calls.length, 1, "no double mint");
});
