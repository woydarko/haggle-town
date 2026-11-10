import type { FastifyInstance } from "fastify";
import type { Db } from "../db/db.ts";
import type { Config } from "../config.ts";
import type { MarketCache } from "../chain/market.ts";
import { history } from "../game/history.ts";

export interface ApiDeps {
  db: Db;
  market: MarketCache;
  leaderboard: () => unknown[];
  config: Config;
}

/** Public read-only routes for the web dashboard. Display names only, never player ids or secrets. */
export function apiRoutes(d: ApiDeps) {
  const deals = d.db.prepare(
    `SELECT d.created_at AS at, COALESCE(p.display_name, 'Trader') AS player, d.merchant, d.good, d.qty, d.unit_price AS unitPrice, d.side, d.tx_hash AS txHash
     FROM deal d LEFT JOIN player_profile p ON p.player_id = d.player_id
     WHERE d.status = 'settled' ORDER BY d.created_at DESC LIMIT 50`,
  );
  const chat = d.db.prepare(
    `SELECT c.created_at AS at, s.merchant, c.text AS line, c.mood, c.source, c.reasoning
     FROM chat_turn c JOIN haggle_session s ON s.id = c.session_id
     WHERE c.role = 'merchant' ORDER BY c.id DESC LIMIT 50`,
  );

  return (app: FastifyInstance) => {
    app.get("/api/config", async () => ({
      contractId: d.config.CONTRACT_ID,
      network: d.config.NEAR_NETWORK,
      explorerBase: d.config.NEAR_NETWORK === "mainnet" ? "https://nearblocks.io" : "https://testnet.nearblocks.io",
    }));
    app.get("/api/market", async () => d.market.get());
    app.get("/api/leaderboard", async () => d.leaderboard());
    app.get("/api/feed", async () => ({ deals: deals.all(), chat: chat.all() }));
    app.get<{ Querystring: { minutes?: number } }>(
      "/api/history",
      { schema: { querystring: { type: "object", properties: { minutes: { type: "integer", minimum: 1, maximum: 1440 } } } } },
      async (req) => history(d.db, req.query.minutes ?? 60, (m) => d.market.byAccount(m)?.good),
    );
  };
}
