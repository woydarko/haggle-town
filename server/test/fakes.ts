import type { Chain } from "../src/chain/near.ts";
import { ChainError } from "../src/chain/near.ts";

export type Call = { method: string; args: any };

/** In-memory chain double: records calls, returns scripted views, can fail or panic on demand. */
export class FakeChain implements Chain {
  calls: Call[] = [];
  views: Record<string, (args: any) => unknown> = {};
  failNext: Error | null = null;
  panicOn: Record<string, string[]> = {}; // method -> queue of panic codes for successive calls
  private n = 0;

  async view<T>(method: string, args: object): Promise<T> {
    const f = this.views[method];
    if (!f) throw new Error(`no fake view ${method}`);
    return f(args) as T;
  }

  async call(method: string, args: object) {
    this.calls.push({ method, args });
    if (this.failNext) {
      const e = this.failNext;
      this.failNext = null;
      throw e;
    }
    const code = this.panicOn[method]?.shift();
    if (code) throw new ChainError(code, `tx-fail-${++this.n}`);
    return { txHash: `tx-${++this.n}`, result: this.views[`${method}:result`]?.(args) ?? null };
  }
}

export const PLAYER_VIEW = { coin: "1000", wood: "0", fish: "0", iron: "0" };

export function marketView(over: Partial<Record<string, any>>[] = []) {
  const base = [
    { account_id: "woodcutter.h.testnet", good: "wood", stock: 100, purse: "10000", target: 100, ask: "50", bid: "40", floor: "50", ceiling_one: "40", day: 0, last_tick_ns: "0" },
    { account_id: "fishmonger.h.testnet", good: "fish", stock: 100, purse: "10000", target: 100, ask: "80", bid: "64", floor: "80", ceiling_one: "64", day: 0, last_tick_ns: "0" },
    { account_id: "smith.h.testnet", good: "iron", stock: 100, purse: "10000", target: 100, ask: "150", bid: "120", floor: "150", ceiling_one: "120", day: 0, last_tick_ns: "0" },
  ];
  return base.map((m, i) => ({ ...m, ...(over[i] ?? {}) }));
}
