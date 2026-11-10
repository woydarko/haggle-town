import type { FastifyInstance } from "fastify";
import { HaggleEngine, MERCHANTS } from "../haggle/engine.ts";
import { pid } from "./rbx.ts";

const userId = { type: "string", pattern: "^[0-9]{1,20}$" } as const;

export function haggleRoutes(engine: HaggleEngine) {
  return (app: FastifyInstance) => {
    app.post<{ Body: { userId: string; merchant: string; message: string } }>(
      "/rbx/haggle",
      {
        schema: {
          body: {
            type: "object",
            required: ["userId", "merchant", "message"],
            properties: {
              userId,
              merchant: { type: "string", enum: Object.keys(MERCHANTS) },
              message: { type: "string", maxLength: 400 },
            },
          },
        },
      },
      async (req) => engine.haggle(pid(req.body.userId), req.body.merchant, req.body.message),
    );

    app.post<{ Body: { userId: string; dealId: string } }>(
      "/rbx/accept",
      {
        schema: {
          body: {
            type: "object",
            required: ["userId", "dealId"],
            properties: { userId, dealId: { type: "string", minLength: 1, maxLength: 64 } },
          },
        },
      },
      async (req) => engine.accept(pid(req.body.userId), req.body.dealId),
    );
  };
}
