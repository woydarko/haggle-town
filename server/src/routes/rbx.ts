import type { FastifyInstance } from "fastify";
import type { Players } from "../game/players.ts";
import type { Gather } from "../game/gather.ts";
import { NODES } from "../game/gather.ts";
import type { MarketCache } from "../chain/market.ts";
import { CLASSES, type Classes } from "../game/classes.ts";
import { netWorth, type Row } from "../game/leaderboard.ts";
import { TOOLS, type Forge } from "../game/forge.ts";

export interface RbxDeps {
  players: Players;
  gather: Gather;
  market: MarketCache;
  classes: Classes;
  /** Extra routes registered under the same HMAC-protected prefix (haggle, leaderboard). */
  extra?: (app: FastifyInstance) => void;
  leaderboard?: { get(): Row[]; rank(playerId: string): number | null };
  forge?: Forge;
}

const userId = { type: "string", pattern: "^[0-9]{1,20}$" } as const;
export const pid = (u: string) => `roblox:${u}`;

const body = (required: string[], properties: object) => ({ schema: { body: { type: "object", required, properties } } });

export function rbxRoutes(d: RbxDeps) {
  return (app: FastifyInstance) => {
    app.post<{ Body: { userId: string; name: string } }>(
      "/rbx/join",
      body(["userId", "name"], { userId, name: { type: "string", minLength: 1, maxLength: 40 } }),
      async (req) => {
        const id = pid(req.body.userId);
        const balances = await d.players.join(id, req.body.name);
        return { balances, class: d.classes.get(id), forge: d.forge?.view(id) };
      },
    );

    app.post<{ Body: { userId: string; node: string } }>(
      "/rbx/gather/start",
      body(["userId", "node"], { userId, node: { type: "string", enum: Object.keys(NODES) } }),
      async (req) => d.gather.start(pid(req.body.userId), req.body.node),
    );

    app.post<{ Body: { userId: string; sessionId: string; quality: number } }>(
      "/rbx/gather/finish",
      body(["userId", "sessionId", "quality"], { userId, sessionId: { type: "string", minLength: 1, maxLength: 64 }, quality: { type: "number" } }),
      async (req) => {
        const id = pid(req.body.userId);
        const c = d.gather.finish(id, req.body.sessionId, req.body.quality);
        return { catch: c, balances: await d.players.balances(id) };
      },
    );

    app.post<{ Body: { userId: string; class: string } }>(
      "/rbx/class",
      body(["userId", "class"], { userId, class: { type: "string", enum: CLASSES } }),
      async (req) => {
        const id = pid(req.body.userId);
        const r = await d.classes.choose(id, req.body.class);
        return { ...r, balances: await d.players.balances(id) };
      },
    );

    app.get<{ Querystring: { userId: string } }>(
      "/rbx/stats",
      { schema: { querystring: { type: "object", required: ["userId"], properties: { userId } } } },
      async (req) => {
        const id = pid(req.query.userId);
        const v = await d.players.view(id);
        const balances = await d.players.balances(id, v);
        return {
          class: v?.class ?? d.classes.get(id),
          balances,
          netWorth: netWorth(balances, d.market),
          bestCatch: d.gather.bestCatch(id),
          deals: d.players.deals(id),
          rank: d.leaderboard?.rank(id) ?? null,
        };
      },
    );

    app.get<{ Querystring: { userId: string } }>(
      "/rbx/state",
      { schema: { querystring: { type: "object", required: ["userId"], properties: { userId } } } },
      async (req) => {
        const id = pid(req.query.userId);
        d.players.touch(id);
        return { balances: await d.players.balances(id), board: d.market.get(), leaderboard: d.leaderboard?.get() ?? [], forge: d.forge?.view(id) };
      },
    );

    app.post<{ Body: { userId: string; tool: string } }>(
      "/rbx/forge",
      body(["userId", "tool"], { userId, tool: { type: "string", enum: Object.keys(TOOLS) } }),
      async (req, reply) => {
        if (!d.forge) return reply.code(404).send({ error: "no_forge", message: "The forge is closed." });
        const id = pid(req.body.userId);
        const r = await d.forge.upgrade(id, req.body.tool);
        return { ...r, balances: await d.players.balances(id), forge: d.forge.view(id) };
      },
    );

    d.extra?.(app);
  };
}
