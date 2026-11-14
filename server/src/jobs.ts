import type { FastifyBaseLogger } from "fastify";
import type { Chain } from "./chain/near.ts";
import type { Queue } from "./chain/queue.ts";
import type { MarketCache } from "./chain/market.ts";
import type { Gather } from "./game/gather.ts";

export interface JobDeps {
  chain: Chain;
  queue: Queue;
  market: MarketCache;
  gather: Gather;
  dayLengthMs: number;
  log: FastifyBaseLogger;
  /** Backer coins to tick after the market day moves on (anyone may tick them; this is just a reliable caller). */
  coins?: string[];
}

/** Gather flush every 10 s, market refresh every 5 s, day tick every game day. Returns a stop function. */
export function startJobs(d: JobDeps): () => void {
  const safe = (name: string, f: () => Promise<unknown>) => () => f().catch((e) => d.log.warn({ err: String(e) }, `${name} failed`));
  const timers = [
    setInterval(safe("gather flush", () => d.gather.flush()), 10_000),
    setInterval(safe("market refresh", () => d.market.refresh()), 5_000),
    setInterval(
      safe("day tick", async () => {
        await d.queue(() => d.chain.call("day_tick", {}));
        await d.market.refresh();
        for (const c of d.coins ?? []) {
          await d.queue(() => d.chain.call("tick", {}, { gas: 45_000_000_000_000n, contractId: c })).catch((e) => d.log.warn({ err: String(e), coin: c }, "coin tick failed"));
        }
      }),
      d.dayLengthMs,
    ),
  ];
  return () => timers.forEach(clearInterval);
}
