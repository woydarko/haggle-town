import { test } from "node:test";
import assert from "node:assert/strict";
import { openDb } from "../src/db/db.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { Forge, RECIPES } from "../src/game/forge.ts";
import { FakeChain, PLAYER_VIEW } from "./fakes.ts";

const P = "roblox:1";

function setup(held: Record<string, string> = {}) {
  const chain = new FakeChain();
  chain.views.get_player = () => ({ ...PLAYER_VIEW, balances: { coin: "1000", ...held } });
  const db = openDb(":memory:");
  const queue = createQueue();
  const gather = new Gather(db, chain, queue);
  const players = new Players(db, chain, queue, gather);
  const forge = new Forge(db, chain, queue, players, gather, () => 1_700_000_000_000);
  return { chain, db, forge, gather };
}

const code = (status: number, c: string) => (e: any) => e.statusCode === status && e.code === c;

test("every tool starts Worn with a Sturdy recipe from the other trades", () => {
  const { forge } = setup();
  const v = forge.view(P);
  assert.deepEqual(
    v.map((t) => [t.tool, t.level, t.name, t.next?.name]),
    [
      ["axe", 1, "Worn Axe", "Sturdy Axe"],
      ["pickaxe", 1, "Worn Pickaxe", "Sturdy Pickaxe"],
      ["rod", 1, "Worn Rod", "Sturdy Rod"],
    ],
  );
  const axe = v[0].next!;
  assert.equal(axe.bonus, 0.25);
  assert.deepEqual(axe.cost, [
    { item: "ore_copper", name: "Copper", qty: 3, merchant: "smith" },
    { item: "fish_sardine", name: "Sardine", qty: 3, merchant: "fishmonger" },
  ]);
  for (const [tool, cat] of [["axe", "wood"], ["pickaxe", "ore"], ["rod", "fish"]]) {
    for (const lvl of [2, 3]) for (const id of Object.keys(RECIPES[tool as "axe"][lvl])) assert.ok(!id.startsWith(cat), `${tool} needs goods from other trades`);
  }
});

test("forging burns the recipe on chain and raises the level", async () => {
  const { forge, chain, db } = setup({ ore_copper: "3", fish_sardine: "4" });
  const r = await forge.upgrade(P, "axe");
  assert.equal(r.level, 2);
  assert.equal(r.name, "Sturdy Axe");
  const burn = chain.calls.find((c) => c.method === "use_items");
  assert.deepEqual(burn?.args, { player_id: P, items: [["ore_copper", "3"], ["fish_sardine", "3"]] });
  assert.equal(forge.level(P, "axe"), 2);
  assert.equal(forge.view(P)[0].next?.name, "Master Axe");
  assert.deepEqual(forge.bonus(P, "wood"), { chance: 0.25, name: "Sturdy Axe" });
  const ev = db.prepare("SELECT tool, level, cost, tx_hash FROM forge_event").get() as any;
  assert.deepEqual({ ...ev }, { tool: "axe", level: 2, cost: '{"ore_copper":3,"fish_sardine":3}', tx_hash: r.txHash });
});

test("missing goods -> 409 with how many, nothing burned", async () => {
  const { forge, chain } = setup({ ore_copper: "1", fish_sardine: "3" });
  await assert.rejects(forge.upgrade(P, "axe"), (e: any) => code(409, "missing")(e) && /2 more Copper/.test(e.message));
  assert.equal(chain.calls.filter((c) => c.method === "use_items").length, 0);
  assert.equal(forge.level(P, "axe"), 1);
});

test("goods caught but not on chain yet -> 409 packing", async () => {
  const { forge, chain, db } = setup({ ore_copper: "2", fish_sardine: "3" });
  db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at) VALUES (?, ?, ?, ?)").run(P, "ore_copper", 1, 1);
  chain.failNext = new Error("rpc down"); // the flush fails, so the copper stays pending
  await assert.rejects(forge.upgrade(P, "axe"), code(409, "packing"));
});

test("chain says the goods are gone -> 409 missing, level unchanged", async () => {
  const { forge, chain } = setup({ wood_pine: "3", ore_copper: "3" });
  chain.panicOn.use_items = ["InsufficientGoods"];
  await assert.rejects(forge.upgrade(P, "rod"), code(409, "missing"));
  assert.equal(forge.level(P, "rod"), 1);
});

test("master tool cannot go higher; unknown tool rejected", async () => {
  const { forge, db } = setup({ wood_oak: "9", ore_iron: "9" });
  db.prepare("INSERT INTO player_tool (player_id, tool, level, updated_at) VALUES (?, 'rod', 3, 0)").run(P);
  await assert.rejects(forge.upgrade(P, "rod"), code(409, "max_level"));
  await assert.rejects(forge.upgrade(P, "hammer"), code(400, "bad_tool"));
  assert.equal(forge.view(P)[2].next, null);
});

test("a tool's bonus gives a second item and names the tool", () => {
  const db = openDb(":memory:");
  const chain = new FakeChain();
  const clock = { t: 1_000_000 };
  const play = (rand: number, cls: string | null) => {
    const g = new Gather(db, chain, createQueue(), () => clock.t, {
      rand: () => rand,
      classOf: () => cls,
      toolBonus: () => ({ chance: 0.25, name: "Sturdy Axe" }),
    });
    const s = g.start(P, "wood");
    clock.t += 5_000;
    return g.finish(P, s.sessionId, 0.5);
  };
  assert.deepEqual([play(0.2, null).qty, play(0.2, null).bonus], [2, "Sturdy Axe"]);
  assert.equal(play(0.3, null).qty, 1);
  assert.equal(play(0.1, "logger").bonus, "trade", "the trade's 15% comes first");
  assert.equal(play(0.35, "logger").bonus, "Sturdy Axe", "tool chance sits on top: 0.15 + 0.25");
});
