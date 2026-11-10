import Fastify, { type FastifyInstance } from "fastify";
import rateLimit from "@fastify/rate-limit";
import type { Config } from "./config.ts";
import type { Db } from "./db/db.ts";
import { verifyHmac } from "./auth/hmac.ts";

declare module "fastify" {
  interface FastifyRequest {
    rawBody?: string;
  }
}

export interface AppDeps {
  config: Config;
  db: Db;
  /** Route plugins added by later modules (chain, haggle, api). */
  routes?: Array<(app: FastifyInstance) => void>;
}

export function buildApp(deps: AppDeps): FastifyInstance {
  const app = Fastify({
    logger: process.env.NODE_ENV === "test" ? false : { redact: ["req.headers"] },
  });

  // Keep the exact bytes for HMAC before JSON parsing.
  app.addContentTypeParser("application/json", { parseAs: "string" }, (req, body, done) => {
    req.rawBody = body as string;
    if (!body) return done(null, {});
    try {
      done(null, JSON.parse(body as string));
    } catch {
      done(Object.assign(new Error("Body is not valid JSON"), { statusCode: 400, code: "bad_json" }));
    }
  });

  app.addHook("preHandler", async (req, reply) => {
    if (!req.url.startsWith("/rbx/")) return;
    const ts = String(req.headers["x-timestamp"] ?? "");
    const sig = String(req.headers["x-signature"] ?? "");
    const body = req.method === "GET" ? "" : (req.rawBody ?? "");
    if (!verifyHmac(deps.config.RBX_HMAC_SECRET, ts, body, sig, Date.now())) {
      return reply.code(401).send({ error: "auth", message: "Missing or invalid request signature" });
    }
  });

  app.register(rateLimit, {
    max: 60,
    timeWindow: "1 minute",
    allowList: (req) => !req.url.startsWith("/api/"),
  });

  app.setErrorHandler((err: Error & { statusCode?: number; code?: string; validation?: unknown }, _req, reply) => {
    const status = err.statusCode ?? (err.validation ? 400 : 500);
    const code = err.validation ? "validation" : status === 500 ? "internal" : (err.code ?? "error");
    if (status >= 500) app.log.error(err);
    reply.code(status).send({ error: code, message: status === 500 ? "Something went wrong" : err.message });
  });

  app.get("/health", async () => ({ ok: true }));
  for (const r of deps.routes ?? []) r(app);
  return app;
}
