import { loadConfig } from "./config.ts";
import { openDb } from "./db/db.ts";
import { buildApp } from "./app.ts";
import { createNearChain } from "./chain/near.ts";
import { createQueue } from "./chain/queue.ts";
import { MarketCache } from "./chain/market.ts";
import { Gather } from "./game/gather.ts";
import { Players } from "./game/players.ts";
import { rbxRoutes } from "./routes/rbx.ts";
import { startJobs } from "./jobs.ts";

const config = loadConfig();
const db = openDb(config.DB_PATH);
const chain = createNearChain(config);
const queue = createQueue();
const market = new MarketCache(chain);
const gather = new Gather(db, chain, queue);
const players = new Players(db, chain, queue, gather);

const app = buildApp({ config, db, routes: [rbxRoutes({ players, gather, market })] });

await market.refresh();
startJobs({ chain, queue, market, gather, dayLengthMs: config.DAY_LENGTH_MS, log: app.log });

app.listen({ port: config.PORT, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
