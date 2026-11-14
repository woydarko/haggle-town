import type { FastifyInstance } from "fastify";
import type { Db } from "../db/db.ts";
import type { Config } from "../config.ts";
import type { MarketCache } from "../chain/market.ts";
import { history } from "../game/history.ts";
import type { Chain } from "../chain/near.ts";
import { HttpError } from "../errors.ts";
import { TOKEN_IDS } from "../items.ts";
import type { PlayerView } from "../types.ts";

const PLAYER_ID = /^(roblox:[0-9]{1,20}|web:[0-9a-f-]{36})$/;

export interface ApiDeps {
  db: Db;
  chain: Chain;
  market: MarketCache;
  leaderboard: () => unknown[];
  config: Config;
  /** Backer coin contract ids (defaults to config.COIN_IDS). */
  coins?: string[];
  /** JSON GET for the NearBlocks indexer (tests pass a stub). */
  fetchJson?: (url: string) => Promise<any>;
}

/** Every NEP-141 mint and transfer of a coin, from the NearBlocks v3 indexer (the locked contracts keep no holder list). */
async function coinEvents(fetchJson: (url: string) => Promise<any>, network: string, id: string) {
  const host = network === "mainnet" ? "api.nearblocks.io" : "api-testnet.nearblocks.io";
  const r = await fetchJson(`https://${host}/v3/fts/${id}/txns?per_page=25`);
  return ((r?.data ?? []) as any[]).map((e) => ({
    account: e.affected_account_id as string,
    cause: e.cause as string,
    amount: e.delta_amount as string,
    at: Math.floor(Number(e.block_timestamp) / 1e6),
    txHash: e.transaction_hash as string,
  }));
}

const getJson = async (url: string) => {
  const r = await fetch(url, { signal: AbortSignal.timeout(4_000) });
  if (!r.ok) throw new Error(`${url} ${r.status}`);
  return r.json();
};

/** Public read-only routes for the web dashboard. Never secrets. Player ids appear only on the players
 *  routes; they are already public on chain as settle_deal / gather_batch arguments. */
export function apiRoutes(d: ApiDeps) {
  const players = d.db.prepare(
    `SELECT p.player_id AS id, p.display_name AS name, p.last_seen AS lastSeen,
            (SELECT COUNT(*) FROM deal d WHERE d.player_id = p.player_id AND d.status = 'settled') AS deals
     FROM player_profile p ORDER BY p.last_seen DESC LIMIT 100`,
  );
  const profile = d.db.prepare("SELECT display_name AS name, first_seen AS firstSeen, last_seen AS lastSeen FROM player_profile WHERE player_id = ?");
  const playerDeals = d.db.prepare(
    `SELECT created_at AS at, merchant, good, qty, unit_price AS unitPrice, side, status, tx_hash AS txHash
     FROM deal WHERE player_id = ? AND status IN ('settled', 'quoted', 'failed') ORDER BY created_at DESC, rowid DESC LIMIT 100`,
  );
  const playerGathers = d.db.prepare(
    "SELECT created_at AS at, good, qty, batch_tx AS batchTx FROM pending_gather WHERE player_id = ? ORDER BY id DESC LIMIT 100",
  );
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
  const guard = d.db.prepare(
    "SELECT created_at AS at, merchant, item, side, wanted, lo, hi, sent FROM guard_event ORDER BY id DESC LIMIT 20",
  );
  const guardCount = d.db.prepare("SELECT COUNT(*) AS n FROM guard_event");
  const forges = d.db.prepare(
    `SELECT f.created_at AS at, COALESCE(p.display_name, 'Trader') AS player, f.tool, f.level, f.cost, f.tx_hash AS txHash
     FROM forge_event f LEFT JOIN player_profile p ON p.player_id = f.player_id ORDER BY f.id DESC LIMIT 20`,
  );

  return (app: FastifyInstance) => {
    app.get("/api/config", async () => ({
      contractId: d.config.CONTRACT_ID,
      network: d.config.NEAR_NETWORK,
      explorerBase: d.config.NEAR_NETWORK === "mainnet" ? "https://nearblocks.io" : "https://testnet.nearblocks.io",
      dayLengthMs: d.config.DAY_LENGTH_MS,
    }));
    app.get("/api/market", async () => d.market.get());
    // Backer coins: each contract's info, its last 30 rebases and its mint/transfer events, cached 30 s.
    // events is null when the indexer is down: the coins work without it, only the list is missing.
    let coinCache: { at: number; body: unknown } | null = null;
    app.get("/api/coins", async () => {
      if (coinCache && Date.now() - coinCache.at < 30_000) return coinCache.body;
      const body = await Promise.all(
        (d.coins ?? d.config.COIN_IDS).map(async (id) => {
          const info = await d.chain.view<{ rebases: number } & Record<string, unknown>>("info", {}, id);
          const recent = await d.chain.view("rebases", { from: Math.max(0, info.rebases - 30), limit: 30 }, id);
          const events = await coinEvents(d.fetchJson ?? getJson, d.config.NEAR_NETWORK, id).catch(() => null);
          return { id, ...info, recent, events };
        }),
      );
      coinCache = { at: Date.now(), body };
      return body;
    });
    app.get("/api/leaderboard", async () => d.leaderboard());
    app.get("/api/feed", async () => ({
      deals: deals.all(),
      chat: chat.all(),
      guard: { count: (guardCount.get() as { n: number }).n, recent: guard.all() },
      forges: (forges.all() as { cost: string }[]).map((f) => ({ ...f, cost: JSON.parse(f.cost) as Record<string, number> })),
    }));
    app.get("/api/players", async () => players.all());
    app.get<{ Params: { id: string } }>("/api/players/:id", async (req) => {
      const id = req.params.id;
      if (!PLAYER_ID.test(id)) throw new HttpError(400, "bad_player_id", "Unknown player id format.");
      const p = profile.get(id) as { name: string; firstSeen: number; lastSeen: number } | undefined;
      if (!p) throw new HttpError(404, "no_player", "No such player.");
      const v = await d.chain.view<PlayerView | null>("get_player", { player_id: id });
      return {
        id,
        ...p,
        class: v?.class ?? null,
        balances: Object.fromEntries(TOKEN_IDS.map((k) => [k, Number(v?.balances?.[k] ?? 0)])),
        deals: playerDeals.all(id),
        gathers: playerGathers.all(id),
      };
    });
    app.get<{ Querystring: { minutes?: number } }>(
      "/api/history",
      { schema: { querystring: { type: "object", properties: { minutes: { type: "integer", minimum: 1, maximum: 1440 } } } } },
      async (req) => history(d.db, req.query.minutes ?? 60),
    );
  };
}
