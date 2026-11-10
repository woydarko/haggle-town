import { createHash } from "node:crypto";
import type { Config } from "../config.ts";
import type { Db } from "../db/db.ts";
import type { HaggleContext, LlmLike, LlmReply } from "../haggle/engine.ts";
import { buildMessages } from "./prompt.ts";

const BANNED = /\b(crypto|blockchain|nft|token|wallet|near|gas|transaction)s?\b/i;
const MOODS = new Set(["pleased", "neutral", "annoyed", "amused"]);

/** Parses the model's JSON reply; throws on anything the engine should not trust (engine then falls back). */
export function parseReply(content: string): LlmReply {
  const m = content.match(/\{[\s\S]*\}/);
  if (!m) throw new Error("no JSON in reply");
  const j = JSON.parse(m[0]);
  if (typeof j.line !== "string" || !j.line.trim()) throw new Error("bad line");
  if (!Number.isInteger(j.unit_price)) throw new Error("bad unit_price");
  if (BANNED.test(j.line)) throw new Error("banned word in line");
  return {
    line: j.line.trim().slice(0, 160),
    mood: MOODS.has(j.mood) ? j.mood : "neutral",
    unitPrice: j.unit_price,
    accept: j.accept === true,
  };
}

export interface LlmOpts {
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

/** NEAR AI Cloud (OpenAI-compatible) merchant brain with record/replay cache for demos. */
export function createLlm(config: Config, db: Db, opts: LlmOpts = {}): LlmLike {
  const doFetch = opts.fetchImpl ?? fetch;
  const timeoutMs = opts.timeoutMs ?? 4_000;
  const getCache = db.prepare("SELECT reply_json FROM llm_cache WHERE prompt_hash = ?");
  const putCache = db.prepare(
    "INSERT INTO llm_cache (prompt_hash, model, reply_json, created_at) VALUES (?, ?, ?, ?) ON CONFLICT DO UPDATE SET reply_json = excluded.reply_json",
  );

  return {
    async reply(ctx: HaggleContext): Promise<LlmReply> {
      const messages = buildMessages(ctx);
      const hash = createHash("sha256").update(config.LLM_MODEL + JSON.stringify(messages)).digest("hex");
      if (config.REPLAY_MODE === "on") {
        const hit = getCache.get(hash) as { reply_json: string } | undefined;
        if (!hit) throw new Error("replay miss");
        return { ...parseReply(hit.reply_json), source: "replay" };
      }
      if (!config.LLM_API_KEY || !config.LLM_MODEL) throw new Error("llm not configured");
      const res = await doFetch(`${config.LLM_BASE_URL}/chat/completions`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${config.LLM_API_KEY}` },
        body: JSON.stringify({
          model: config.LLM_MODEL,
          messages,
          temperature: 0.3,
          max_tokens: 400, // some models reason silently first; 150 cut the JSON off
          response_format: { type: "json_object" },
        }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (!res.ok) throw new Error(`llm http ${res.status}`);
      const body: any = await res.json();
      const content: string = body?.choices?.[0]?.message?.content ?? "";
      const parsed = parseReply(content);
      if (config.REPLAY_MODE === "record") putCache.run(hash, config.LLM_MODEL, content, Date.now());
      return { ...parsed, source: "llm" };
    },
  };
}
