import type { FastifyInstance } from "fastify";
import type { Players } from "../game/players.ts";
import type { Gather } from "../game/gather.ts";
import type { MarketCache } from "../chain/market.ts";
import { GOODS, type Good } from "../types.ts";

export interface RbxDeps {
  players: Players;
  gather: Gather;
  market: MarketCache;
  /** Extra routes registered under the same HMAC-protected prefix (haggle, leaderboard). */
  extra?: (app: FastifyInstance) => void;
  leaderboard?: () => unknown[];
}

const userId = { type: "string", pattern: "^[0-9]{1,20}$" } as const;
export const pid = (u: string) => `roblox:${u}`;

export function rbxRoutes(d: RbxDeps) {
  return (app: FastifyInstance) => {
    app.post<{ Body: { userId: string; name: string } }>(
      "/rbx/join",
      {
        schema: {
          body: {
            type: "object",
            required: ["userId", "name"],
            properties: { userId, name: { type: "string", minLength: 1, maxLength: 40 } },
          },
        },
      },
      async (req) => ({ balances: await d.players.join(pid(req.body.userId), req.body.name) }),
    );

    app.post<{ Body: { userId: string; good: Good } }>(
      "/rbx/gather",
      {
        schema: {
          body: {
            type: "object",
            required: ["userId", "good"],
            properties: { userId, good: { type: "string", enum: GOODS } },
          },
        },
      },
      async (req, reply) => {
        const id = pid(req.body.userId);
        const r = d.gather.request(id, req.body.good);
        if ("error" in r) return reply.code(429).send({ error: "cooldown", message: "Still resting", cooldownMs: r.cooldownMs });
        return { balances: await d.players.balances(id), pending: r.pending, cooldownMs: r.cooldownMs };
      },
    );

    app.get<{ Querystring: { userId: string } }>(
      "/rbx/state",
      { schema: { querystring: { type: "object", required: ["userId"], properties: { userId } } } },
      async (req) => {
        const id = pid(req.query.userId);
        d.players.touch(id);
        return { balances: await d.players.balances(id), board: d.market.get(), leaderboard: d.leaderboard?.() ?? [] };
      },
    );

    d.extra?.(app);
  };
}
