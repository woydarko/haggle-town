import { test } from "node:test";
import assert from "node:assert/strict";
import { createQueue } from "../src/chain/queue.ts";

test("queue runs jobs in order, one at a time", async () => {
  const q = createQueue();
  const log: string[] = [];
  let running = 0;
  const job = (name: string, ms: number) => () =>
    new Promise<string>((res) => {
      running++;
      assert.equal(running, 1, "only one job at a time");
      log.push(`start ${name}`);
      setTimeout(() => {
        log.push(`end ${name}`);
        running--;
        res(name);
      }, ms);
    });
  const results = await Promise.all([q(job("a", 20)), q(job("b", 1)), q(job("c", 5))]);
  assert.deepEqual(results, ["a", "b", "c"]);
  assert.deepEqual(log, ["start a", "end a", "start b", "end b", "start c", "end c"]);
});

test("a failing job does not block the next", async () => {
  const q = createQueue();
  await assert.rejects(q(async () => { throw new Error("boom"); }), /boom/);
  assert.equal(await q(async () => 1), 1);
});
