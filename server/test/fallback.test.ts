import { test } from "node:test";
import assert from "node:assert/strict";
import { PERSONAS, pickLine, fallbackReply } from "../src/haggle/fallback.ts";

const KINDS = ["hello", "accept", "annoyed", "refuse", "broke", "wrapUp"] as const;
const BANNED = /crypto|blockchain|\bnft\b|token|wallet|\bnear\b|\bgas\b|transaction|—/i;

test("every merchant has at least 6 lines for every situation", () => {
  for (const [name, p] of Object.entries(PERSONAS)) {
    for (const k of KINDS) assert.ok(p[k].length >= 6, `${name}.${k} has ${p[k].length}`);
    assert.ok(p.counter.length >= 6, `${name}.counter has ${p.counter.length}`);
  }
});

test("no line uses a banned word or an em dash; counter lines always name the price", () => {
  for (const [name, p] of Object.entries(PERSONAS)) {
    for (const k of KINDS) for (const line of p[k]) assert.doesNotMatch(line, BANNED, `${name}.${k}: ${line}`);
    for (const f of p.counter) {
      const line = f(137);
      assert.match(line, /137/, `${name} counter: ${line}`);
      assert.doesNotMatch(line, BANNED, `${name} counter: ${line}`);
    }
  }
});

test("pickLine never returns one of the last 3 lines", () => {
  const bank = ["a", "b", "c", "d", "e", "f"];
  for (let i = 0; i < 200; i++) {
    const recent = ["a", "b", "c"];
    assert.ok(!recent.includes(pickLine(bank, recent)));
  }
  // only the last 3 count: an older line may come back
  const seen = new Set<string>();
  for (let i = 0; i < 200; i++) seen.add(pickLine(bank, ["a", "b", "c", "d"]));
  assert.ok(seen.has("a"), "older lines are allowed again");
});

test("pickLine still answers when recent lines cover the whole bank", () => {
  assert.ok(["x", "y"].includes(pickLine(["x", "y"], ["x", "y", "z"])));
});

test("fallback replies avoid the merchant's recent lines", () => {
  const ctx = { merchant: "woodcutter", room: [6, 10] as [number, number], current: 9, lowball: false };
  const recent: string[] = [];
  for (let i = 0; i < 12; i++) {
    const r = fallbackReply(ctx, recent);
    assert.ok(!recent.slice(-3).includes(r.line), `repeat: ${r.line}`);
    recent.push(r.line);
  }
  assert.ok(new Set(recent).size >= 6, "a dozen greetings use at least 6 different lines");
});
