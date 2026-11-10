import { loadConfig } from "./config.ts";
import { openDb } from "./db/db.ts";
import { buildApp } from "./app.ts";
import { createNearChain } from "./chain/near.ts";
import { createQueue } from "./chain/queue.ts";
import { MarketCache } from "./chain/market.ts";
import { Gather } from "./game/gather.ts";
import { Players } from "./game/players.ts";
import { rbxRoutes } from "./routes/rbx.ts";
import { haggleRoutes } from "./routes/haggle.ts";
import { HaggleEngine } from "./haggle/engine.ts";
import { createLlm } from "./llm/client.ts";
import { startJobs } from "./jobs.ts";
import { Leaderboard } from "./game/leaderboard.ts";
import { apiRoutes } from "./routes/api.ts";
import { recordPrices } from "./game/history.ts";
import fastifyStatic from "@fastify/static";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const config = loadConfig();
const db = openDb(config.DB_PATH);
const chain = createNearChain(config);
const queue = createQueue();
const market = new MarketCache(chain);
const gather = new Gather(db, chain, queue);
const players = new Players(db, chain, queue, gather);
const leaderboard = new Leaderboard(db, chain, market);

const engine = new HaggleEngine({
  db,
  chain,
  queue,
  market,
  players,
  contractId: config.CONTRACT_ID,
  merchantKeys: { woodcutter: config.WOODCUTTER_PRIVATE_KEY, fishmonger: config.FISHMONGER_PRIVATE_KEY, smith: config.SMITH_PRIVATE_KEY },
  dayLengthMs: config.DAY_LENGTH_MS,
  llm: createLlm(config, db),
});

const app = buildApp({ config, db, routes: [rbxRoutes({ players, gather, market, leaderboard: () => leaderboard.get() }), haggleRoutes(engine), apiRoutes({ db, market, leaderboard: () => leaderboard.get(), config })] });

const webDist = fileURLToPath(new URL("../../web/dist", import.meta.url));
if (existsSync(webDist)) app.register(fastifyStatic, { root: webDist });
market.onRefresh = (rows) => recordPrices(db, rows);

await market.refresh();
startJobs({ chain, queue, market, gather, dayLengthMs: config.DAY_LENGTH_MS, log: app.log });
setInterval(() => leaderboard.refresh().catch((e) => app.log.warn({ err: String(e) }, "leaderboard refresh failed")), 30_000);

app.listen({ port: config.PORT, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
