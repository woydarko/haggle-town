import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { openDb } from "../src/db/db.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { FakeChain } from "./fakes.ts";

/** rand() returns the given values in order (then repeats the last). */
const seq = (...xs: number[]) => () => (xs.length > 1 ? xs.shift()! : xs[0]);

function setup(o: { path?: string; rand?: () => number; cls?: string } = {}) {
  const chain = new FakeChain();
  const db = openDb(o.path ?? ":memory:");
  const clock = { t: 1_000_000 };
  const g = new Gather(db, chain, createQueue(), () => clock.t, { rand: o.rand ?? seq(0.5), classOf: () => o.cls ?? null });
  /** start, wait `ms`, finish */
  const play = (node: string, quality = 0.5, ms = 7_000, player = "roblox:1") => {
    const s = g.start(player, node);
    clock.t += ms;
    return g.finish(player, s.sessionId, quality);
  };
  return { chain, db, g, clock, play };
}

const code = (status: number, c: string) => (e: any) => e.statusCode === status && e.code === c;

test("finish faster than the minigame minimum -> 422", () => {
  const { g, clock } = setup();
  const s = g.start("roblox:1", "fish");
  assert.equal(s.params.minMs, 6_000);
  clock.t += 2_000;
  assert.throws(() => g.finish("roblox:1", s.sessionId, 1), code(422, "too_fast"));
});

test("unknown or foreign session -> 404", () => {
  const { g, clock } = setup();
  const s = g.start("roblox:1", "wood");
  clock.t += 4_000;
  assert.throws(() => g.finish("roblox:2", s.sessionId, 1), code(404, "no_session"));
  assert.throws(() => g.finish("roblox:1", "nope", 1), code(404, "no_session"));
});

test("double finish and expired sessions -> 409", () => {
  const { g, clock } = setup();
  const s = g.start("roblox:1", "wood");
  clock.t += 4_000;
  g.finish("roblox:1", s.sessionId, 1);
  assert.throws(() => g.finish("roblox:1", s.sessionId, 1), code(409, "session_closed"));
  const late = g.start("roblox:1", "wood");
  clock.t += 61_000;
  assert.throws(() => g.finish("roblox:1", late.sessionId, 1), code(409, "session_closed"));
});

test("a new start closes the earlier open session", () => {
  const { g, clock } = setup();
  const a = g.start("roblox:1", "wood");
  g.start("roblox:1", "fish");
  clock.t += 7_000;
  assert.throws(() => g.finish("roblox:1", a.sessionId, 1), code(409, "session_closed"));
});

test("quality is clamped to 0..1 (NaN counts as 0)", () => {
  // roll 6900: q0 -> common (cum 7000), q100 -> rare (cum 5000, 8400)
  const tierAt = (quality: number) => setup({ rand: seq(0.69) }).play("fish", quality).item;
  assert.equal(tierAt(NaN), "fish_sardine");
  assert.equal(tierAt(-1), "fish_sardine");
  assert.equal(tierAt(0), "fish_sardine");
  assert.equal(tierAt(5), "fish_trout");
  assert.equal(tierAt(1), "fish_trout");
});

test("cave mouth never yields crystal; deep cave can", () => {
  assert.equal(setup({ rand: seq(0.9999) }).play("ore_mouth", 1).item, "ore_gold");
  assert.equal(setup({ rand: seq(0.9999) }).play("ore_deep", 0).item, "ore_crystal");
});

test("exploration nodes: wood_old and fish_deep get the deep +20 quality bonus", () => {
  // roll 6900: q0 -> common; +20 bonus -> rare; same rule as ore_deep
  const at = (node: string, q = 0) => setup({ rand: seq(0.69) }).play(node, q).item;
  assert.equal(at("wood"), "wood_pine");
  assert.equal(at("wood_old"), at("wood", 0.2));
  assert.equal(at("fish_deep"), at("fish", 0.2));
  assert.equal(at("wood_old"), "wood_maple", "roll 6900 q0 -> rare");
  assert.equal(at("fish_deep"), "fish_salmon", "roll 6900 q0 -> rare");
  const s = setup({ rand: seq(0.99) }).g.start("roblox:1", "fish_deep");
  assert.equal(s.params.minMs, 6_000);
  assert.equal(s.params.fishSpeed, 1.99, "deep fish dart like lake fish");
  assert.equal(setup().g.start("roblox:1", "wood_old").params.minMs, 3_000);
});

test("specialist: bigger zone and 15% double drop; others never double", () => {
  const spec = setup({ cls: "logger", rand: seq(0.5, 0.1) });
  assert.equal(spec.g.start("roblox:9", "fish").params.zoneScale, 1, "logger is not a fish specialist");
  const s = spec.g.start("roblox:1", "wood");
  assert.equal(s.params.zoneScale, 1.3);
  spec.clock.t += 4_000;
  assert.equal(spec.g.finish("roblox:1", s.sessionId, 0.5).qty, 2);
  assert.equal(setup({ cls: "logger", rand: seq(0.5, 0.2) }).play("wood").qty, 1);
  assert.equal(setup({ rand: seq(0.5, 0.01) }).play("wood").qty, 1);
});

test("fish speed grows with the hidden roll", () => {
  assert.equal(setup({ rand: seq(0) }).g.start("roblox:1", "fish").params.fishSpeed, 1);
  assert.equal(setup({ rand: seq(0.99) }).g.start("roblox:1", "fish").params.fishSpeed, 1.99);
  assert.throws(() => setup().g.start("roblox:1", "lava"), code(400, "bad_node"));
});

test("catches are pending until flushed in one batch per item", async () => {
  const { g, chain, play } = setup({ rand: seq(0) });
  play("wood");
  play("wood");
  play("fish", 0.5, 7_000, "roblox:2");
  assert.deepEqual(g.pending("roblox:1"), { wood_pine: 2 });
  await g.flush();
  assert.equal(chain.calls.length, 1);
  assert.equal(chain.calls[0].method, "gather_batch");
  assert.deepEqual(
    chain.calls[0].args.entries.sort((x: any, y: any) => x.player_id.localeCompare(y.player_id)),
    [{ player_id: "roblox:1", good: "wood_pine", qty: 2 }, { player_id: "roblox:2", good: "fish_sardine", qty: 1 }],
  );
  assert.deepEqual(g.pending("roblox:1"), {});
  await g.flush();
  assert.equal(chain.calls.length, 1, "nothing left to flush");
});

test("v1 pending rows are parked, not sent to the v2 contract", async () => {
  const { g, db, chain } = setup();
  db.prepare("INSERT INTO pending_gather (player_id, good, qty, created_at) VALUES ('roblox:1', 'wood', 1, 1)").run();
  await g.flush();
  assert.equal(chain.calls.length, 0);
  assert.equal((db.prepare("SELECT batch_tx FROM pending_gather").get() as any).batch_tx, "invalid");
});

test("flush failure keeps rows pending", async () => {
  const { g, chain, play } = setup({ rand: seq(0) });
  play("wood");
  chain.failNext = new Error("rpc down");
  await g.flush();
  assert.deepEqual(g.pending("roblox:1"), { wood_pine: 1 });
  await g.flush();
  assert.equal(chain.calls.length, 2);
  assert.deepEqual(g.pending("roblox:1"), {});
});

test("pending survives restart without double mint", async () => {
  const path = join(mkdtempSync(join(tmpdir(), "haggle-")), "db.sqlite");
  const first = setup({ path, rand: seq(0) });
  first.play("wood");
  first.db.close();
  const second = setup({ path });
  await second.g.flush();
  assert.deepEqual(second.chain.calls[0].args.entries, [{ player_id: "roblox:1", good: "wood_pine", qty: 1 }]);
  await second.g.flush();
  assert.equal(second.chain.calls.length, 1);
});

test("best catch is the most valuable item ever caught", () => {
  const { g, play } = setup({ rand: seq(0.75) }); // roll 7500 -> rare at q0 and q0.5
  assert.equal(g.bestCatch("roblox:1"), null);
  play("fish", 0.5);
  play("ore_mouth", 0);
  assert.deepEqual(g.bestCatch("roblox:1"), { item: "ore_iron", name: "Iron", tier: "rare" });
});
