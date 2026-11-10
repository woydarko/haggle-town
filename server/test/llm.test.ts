import { test } from "node:test";
import assert from "node:assert/strict";
import { KeyPair } from "near-api-js";
import { openDb } from "../src/db/db.ts";
import { loadConfig } from "../src/config.ts";
import { createLlm, parseReply } from "../src/llm/client.ts";
import { createQueue } from "../src/chain/queue.ts";
import { MarketCache } from "../src/chain/market.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { HaggleEngine, type HaggleContext } from "../src/haggle/engine.ts";
import { FakeChain, PLAYER_VIEW, marketView } from "./fakes.ts";
import { TEST_ENV } from "./app.test.ts";

const CTX: HaggleContext = {
  merchant: "woodcutter",
  persona: "gruff",
  good: "wood",
  side: "buy",
  qty: 1,
  stock: 140,
  target: 100,
  purse: 10_000,
  room: [21, 35],
  currentCounter: 35,
  offer: {},
  patience: 3,
  history: [],
  message: "how much?",
};

function completion(content: string) {
  return new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status: 200, headers: { "content-type": "application/json" } });
}

function cfg(over: Record<string, string> = {}) {
  return loadConfig({ ...TEST_ENV, LLM_API_KEY: "k", LLM_MODEL: "m", ...over });
}

test("parseReply: plain JSON", () => {
  assert.deepEqual(parseReply('{"line":"Hi","mood":"pleased","unit_price":30,"accept":false}'), {
    line: "Hi",
    mood: "pleased",
    unitPrice: 30,
    accept: false,
  });
});

test("parseReply: prose around JSON", () => {
  const r = parseReply('Sure! {"line":"Deal","mood":"neutral","unit_price":25,"accept":true} hope that helps');
  assert.equal(r.unitPrice, 25);
  assert.equal(r.accept, true);
});

test("parseReply: rejects junk", () => {
  assert.throws(() => parseReply("no json here"));
  assert.throws(() => parseReply('{"line":"x","mood":"neutral","unit_price":"40","accept":false}'));
  assert.throws(() => parseReply('{"line":"","mood":"neutral","unit_price":40,"accept":false}'));
  assert.throws(() => parseReply(""));
});

test("parseReply: rejects banned chain words in the line", () => {
  assert.throws(() => parseReply('{"line":"Pay with your NEAR wallet","mood":"neutral","unit_price":30,"accept":false}'));
});

test("parseReply: extreme numbers pass through (engine clamps)", () => {
  assert.equal(parseReply('{"line":"x","mood":"neutral","unit_price":-5,"accept":false}').unitPrice, -5);
  assert.equal(parseReply('{"line":"x","mood":"neutral","unit_price":99999,"accept":false}').unitPrice, 99999);
});

test("client sends model, low temperature, token cap, json mode and bearer", async () => {
  let seen: any;
  const llm = createLlm(cfg(), openDb(":memory:"), {
    fetchImpl: async (url: any, init: any) => {
      seen = { url: String(url), init, body: JSON.parse(init.body) };
      return completion('{"line":"Hi","mood":"neutral","unit_price":30,"accept":false}');
    },
  });
  const r = await llm.reply(CTX);
  assert.equal(r.unitPrice, 30);
  assert.equal(seen.url, "https://cloud-api.near.ai/v1/chat/completions");
  assert.equal(seen.init.headers.authorization, "Bearer k");
  assert.equal(seen.body.model, "m");
  assert.equal(seen.body.max_tokens, 400); // room for hidden reasoning before the JSON
  assert.ok(seen.body.temperature <= 0.3);
  assert.deepEqual(seen.body.response_format, { type: "json_object" });
  const system = seen.body.messages[0].content;
  assert.match(system, /between 21 and 35/);
  assert.match(system, /untrusted/);
});

test("prompt gives the merchant a voice and the stock situation", async () => {
  let system = "";
  const llm = createLlm(cfg(), openDb(":memory:"), {
    fetchImpl: async (_u: any, init: any) => {
      system = JSON.parse(init.body).messages[0].content;
      return completion('{"line":"Hi","mood":"neutral","unit_price":30,"accept":false}');
    },
  });
  await llm.reply(CTX); // woodcutter, stock 140 of 100
  assert.match(system, /Lines in your voice/);
  assert.match(system, /axe/i); // one of the woodcutter's example lines
  assert.match(system, /too much/i); // overstocked situation
  await llm.reply({ ...CTX, stock: 30 });
  assert.match(system, /scarce/i);
});

test("no key -> throws without calling fetch", async () => {
  let called = false;
  const llm = createLlm(cfg({ LLM_API_KEY: "" }), openDb(":memory:"), { fetchImpl: async () => ((called = true), completion("{}")) });
  await assert.rejects(llm.reply(CTX));
  assert.equal(called, false);
});

test("record then replay serves cache without fetch", async () => {
  const db = openDb(":memory:");
  const rec = createLlm(cfg({ REPLAY_MODE: "record" }), db, {
    fetchImpl: async () => completion('{"line":"Recorded","mood":"neutral","unit_price":30,"accept":false}'),
  });
  await rec.reply(CTX);
  let called = false;
  const rep = createLlm(cfg({ REPLAY_MODE: "on" }), db, { fetchImpl: async () => ((called = true), completion("{}")) });
  const r = await rep.reply(CTX);
  assert.equal(r.line, "Recorded");
  assert.equal(r.source, "replay");
  assert.equal(called, false);
  await assert.rejects(rep.reply({ ...CTX, message: "never recorded" }));
});

test("timeout -> engine falls back fast", async () => {
  const chain = new FakeChain();
  chain.views.get_player = () => PLAYER_VIEW;
  chain.views.get_market = () => marketView([{ stock: 140 }]);
  const db = openDb(":memory:");
  const queue = createQueue();
  const market = new MarketCache(chain);
  await market.refresh();
  const players = new Players(db, chain, queue, new Gather(db, chain, queue));
  const llm = createLlm(cfg(), db, { fetchImpl: (_u: any, init: any) => new Promise((_res, rej) => init.signal.addEventListener("abort", () => rej(new Error("aborted")))), timeoutMs: 50 });
  const key = KeyPair.fromRandom("ed25519").toString();
  const engine = new HaggleEngine({
    db, chain, queue, market, players, llm,
    contractId: "h.testnet",
    merchantKeys: { woodcutter: key, fishmonger: key, smith: key },
    dayLengthMs: 300_000,
  });
  const t0 = Date.now();
  const r = await engine.haggle("roblox:1", "woodcutter", "25 for 1 wood");
  assert.equal(r.source, "fallback");
  assert.equal(r.counter?.unitPrice, 25);
  assert.ok(Date.now() - t0 < 5_000);
});
