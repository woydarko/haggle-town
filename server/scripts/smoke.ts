// Testnet smoke: node --env-file=../.env scripts/smoke.ts
// Joins a throwaway player, gathers wood, flushes the batch and reads the balance back from chain.
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db/db.ts";
import { createNearChain } from "../src/chain/near.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";

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
console.log("SMOKE OK");
