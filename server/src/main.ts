import { loadConfig } from "./config.ts";
import { openDb } from "./db/db.ts";
import { buildApp } from "./app.ts";

const config = loadConfig();
const db = openDb(config.DB_PATH);
const app = buildApp({ config, db });

app.listen({ port: config.PORT, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
