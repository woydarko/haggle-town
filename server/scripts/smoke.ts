// Testnet smoke: node --env-file=../.env scripts/smoke.ts
// Joins a throwaway player, gathers wood, flushes the batch and reads the balance back from chain.
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db/db.ts";
import { createNearChain } from "../src/chain/near.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { MarketCache } from "../src/chain/market.ts";
import { HaggleEngine } from "../src/haggle/engine.ts";

const config = loadConfig();
const db = openDb(":memory:");
const chain = createNearChain(config);
const queue = createQueue();
const gather = new Gather(db, chain, queue);
const players = new Players(db, chain, queue, gather);

const id = `roblox:${process.argv[2] ?? "999001"}`;
console.log("join", id, await players.join(id, "smoke"));
const g = gather.request(id, "wood");
console.log("gather", g);
await gather.flush();
const tx = (db.prepare("SELECT batch_tx FROM pending_gather LIMIT 1").get() as any)?.batch_tx;
console.log("batch tx", tx);
const after = await chain.view<any>("get_player", { player_id: id });
console.log("on chain", after);
if (!tx || Number(after.wood) < 1) {
  console.error("SMOKE FAILED");
  process.exit(1);
}
const market = new MarketCache(chain);
await market.refresh();
const engine = new HaggleEngine({
  db, chain, queue, market, players, contractId: config.CONTRACT_ID, dayLengthMs: config.DAY_LENGTH_MS,
  merchantKeys: { woodcutter: config.WOODCUTTER_PRIVATE_KEY, fishmonger: config.FISHMONGER_PRIVATE_KEY, smith: config.SMITH_PRIVATE_KEY },
});
const before = await players.balances(id);
const q = await engine.haggle(id, "woodcutter", "sell 1 wood for 40");
console.log("haggle", q.line, q.counter);
const a = await engine.accept(id, q.counter!.dealId);
console.log("accept", a);
const end = await players.balances(id);
if (a.status !== "settled" || end.wood !== before.wood - 1 || end.coin !== before.coin + q.counter!.unitPrice) {
  console.error("SMOKE FAILED (haggle)");
  process.exit(1);
}
console.log("SMOKE OK");
