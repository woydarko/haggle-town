import type { Chain } from "../src/chain/near.ts";
import { ChainError } from "../src/chain/near.ts";
import { ITEMS } from "../src/items.ts";
import { ask, bid, buyRoom } from "../src/haggle/pricing.ts";

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

export const PLAYER_VIEW = { class: null, balances: { coin: "1000" } };

const ACCOUNT = { fish: "fishmonger.h.testnet", wood: "woodcutter.h.testnet", ore: "smith.h.testnet" };

/** v2 get_market rows (strings like the contract). Every item at its target stock unless overridden by item id. */
export function marketView(over: Record<string, { stock?: number; purse?: string }> = {}) {
  return ITEMS.map((it) => {
    const stock = over[it.id]?.stock ?? it.target;
    return {
      merchant: ACCOUNT[it.category],
      category: it.category,
      item: it.id,
      tier: it.tier,
      stock,
      purse: over[it.id]?.purse ?? "10000",
      ask: String(ask(it.id, stock)),
      bid: String(bid(it.id, stock)),
      floor: String(buyRoom(it.id, stock)[0]),
      ceiling_one: String(bid(it.id, stock)),
      day: 0,
      last_tick_ns: "0",
    };
  });
}
