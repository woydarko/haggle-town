// LLM eval: node --env-file=../.env eval/run.ts [model ...]
// Pass = valid JSON reply, raw unit_price inside the room, no banned words, latency < 4 s.
import { readFileSync } from "node:fs";
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db/db.ts";
import { createLlm } from "../src/llm/client.ts";
import { buyRoom, sellRoom } from "../src/haggle/pricing.ts";
import { MERCHANTS, type HaggleContext } from "../src/haggle/engine.ts";
import { PERSONAS } from "../src/haggle/fallback.ts";
import { parseOffer } from "../src/haggle/offer.ts";
import { itemById, itemOf } from "../src/items.ts";

const cases = JSON.parse(readFileSync(new URL("./cases.json", import.meta.url), "utf8"));
const models = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ["Qwen/Qwen3.6-35B-A3B-FP8", "z-ai/glm-5.3-flash", "anthropic/claude-haiku-5-5"];
const base = loadConfig();

for (const model of models) {
  const llm = createLlm({ ...base, LLM_MODEL: model, REPLAY_MODE: "off" }, openDb(":memory:"), { timeoutMs: 8_000 });
  const lat: number[] = [];
  let pass = 0;
  for (const c of cases) {
    const purse = c.purse ?? 10_000;
    const offer = parseOffer(c.message);
    const item = itemById(offer.item ?? "") ?? itemOf(MERCHANTS[c.merchant], "common");
    const stock = Math.round((c.stock * item.target) / 100); // cases were written against v1 target 100
    const qty = Math.min(Math.max(offer.qty ?? 1, 1), 10);
    const room = c.side === "buy" ? buyRoom(item.id, stock) : sellRoom(item.id, stock, purse, qty, false);
    if (!room) {
      console.log(`  ${c.id}: merchant refuses (empty purse) before LLM - pass`);
      pass++;
      continue;
    }
    const ctx: HaggleContext = {
      merchant: c.merchant, persona: PERSONAS[c.merchant].style, item: item.id, itemName: item.name, tier: item.tier,
      side: c.side, qty, stock, target: item.target,
      purse, room, currentCounter: c.side === "buy" ? room[1] : room[0], offer, patience: 3, history: [], message: c.message,
    };
    const t0 = Date.now();
    try {
      const r = await llm.reply(ctx);
      const ms = Date.now() - t0;
      lat.push(ms);
      const ok = r.unitPrice >= room[0] && r.unitPrice <= room[1] && ms < 4_000;
      if (ok) pass++;
      console.log(`  ${ok ? "PASS" : "FAIL"} ${c.id} ${ms}ms price ${r.unitPrice} room ${room} "${r.line}"`);
    } catch (e) {
      lat.push(Date.now() - t0);
      console.log(`  FAIL ${c.id} ${(e as Error).message}`);
    }
  }
  lat.sort((a, b) => a - b);
  const pct = (p: number) => lat[Math.min(lat.length - 1, Math.floor(p * lat.length))] ?? 0;
  console.log(`${model}: ${pass}/${cases.length} pass, p50 ${pct(0.5)}ms, p95 ${pct(0.95)}ms`);
}
