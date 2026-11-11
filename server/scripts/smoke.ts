// Testnet smoke (v2): node --env-file=../.env scripts/smoke.ts [userId]
// Joins a throwaway player, picks Logger, plays one wood session (real wait), flushes the batch,
// reads the item back from chain, then sells it to the Woodcutter through a signed deal.
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db/db.ts";
import { createNearChain } from "../src/chain/near.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { Classes } from "../src/game/classes.ts";
import { MarketCache } from "../src/chain/market.ts";
import { HaggleEngine } from "../src/haggle/engine.ts";

const config = loadConfig();
const db = openDb(":memory:");
const chain = createNearChain(config);
const queue = createQueue();
const classes = new Classes(db, chain, queue);
const gather = new Gather(db, chain, queue, Date.now, { classOf: (id) => classes.get(id) });
const players = new Players(db, chain, queue, gather);
const fail = (why: string) => {
  console.error(`SMOKE FAILED (${why})`);
  process.exit(1);
};

const id = `roblox:${process.argv[2] ?? "999002"}`;
console.log("join", id, await players.join(id, "smoke"));
console.log("class", await classes.choose(id, "logger"));
const s = gather.start(id, "wood");
console.log("start", s);
await new Promise((r) => setTimeout(r, s.params.minMs + 200));
const c = gather.finish(id, s.sessionId, 0.8);
console.log("catch", c);
await gather.flush();
const tx = (db.prepare("SELECT batch_tx FROM pending_gather LIMIT 1").get() as any)?.batch_tx;
console.log("batch tx", tx);
const after = await players.balances(id);
console.log("on chain", after);
if (!tx || after[c.item] < c.qty) fail("gather");
if ((await players.view(id))?.class !== "logger") fail("class");

const market = new MarketCache(chain);
await market.refresh();
const engine = new HaggleEngine({
  db, chain, queue, market, players, contractId: config.CONTRACT_ID, dayLengthMs: config.DAY_LENGTH_MS,
  merchantKeys: { woodcutter: config.WOODCUTTER_PRIVATE_KEY, fishmonger: config.FISHMONGER_PRIVATE_KEY, smith: config.SMITH_PRIVATE_KEY },
  classOf: (pid) => classes.get(pid),
});
const q = await engine.haggle(id, "woodcutter", `sell 1 ${c.name}`);
console.log("haggle", q.line, q.counter);
const a = await engine.accept(id, q.counter!.dealId);
console.log("accept", a);
const end = await players.balances(id);
if (a.status !== "settled" || end[c.item] !== after[c.item] - 1 || end.coin !== after.coin + q.counter!.unitPrice) fail("haggle");
console.log("SMOKE OK");
