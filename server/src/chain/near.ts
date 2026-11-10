import { Account, FailoverRpcProvider, JsonRpcProvider, actions, teraToGas, type KeyPairString } from "near-api-js";
import type { Config } from "../config.ts";

export interface Chain {
  view<T>(method: string, args: object): Promise<T>;
  call(method: string, args: object, opts?: { gas?: bigint }): Promise<{ txHash: string; result: unknown }>;
}

/** A contract panic, e.g. code "PriceOutOfRoom". Transport errors stay plain Errors. */
export class ChainError extends Error {
  code: string;
  txHash?: string;
  constructor(code: string, txHash?: string) {
    super(`contract panicked: ${code}`);
    this.code = code;
    this.txHash = txHash;
  }
}

export function panicCode(status: unknown): string | null {
  const m = JSON.stringify(status ?? "").match(/Smart contract panicked: ([A-Za-z]+)/);
  return m ? m[1] : null;
}

// near-api-js 7.4 API (spiked 2026-11-10): FailoverRpcProvider([...JsonRpcProvider]), provider.callFunction({contractId, method, args})
// for views; Account(id, provider, privateKey).signAndSendTransaction({receiverId, actions, throwOnFailure}) for calls.
export function createNearChain(config: Config): Chain {
  const provider = new FailoverRpcProvider([
    new JsonRpcProvider({ url: config.NEAR_RPC_URL }),
    new JsonRpcProvider({ url: config.NEAR_RPC_FALLBACK_URL }),
  ]);
  const game = new Account(config.GAME_ACCOUNT_ID, provider, config.GAME_PRIVATE_KEY as KeyPairString);
  return {
    async view<T>(method: string, args: object) {
      return (await provider.callFunction({ contractId: config.CONTRACT_ID, method, args: args as Record<string, unknown> })) as T;
    },
    async call(method, args, opts) {
      const res: any = await game.signAndSendTransaction({
        receiverId: config.CONTRACT_ID,
        actions: [actions.functionCall(method, args, opts?.gas ?? teraToGas("100"), 0n)],
        throwOnFailure: false,
      } as any);
      const txHash: string = res?.transaction?.hash ?? res?.transaction_outcome?.id ?? "";
      const code = panicCode(res?.status);
      if (code) throw new ChainError(code, txHash);
      if (res?.status?.Failure) throw new Error(`tx failed: ${JSON.stringify(res.status.Failure).slice(0, 300)}`);
      const b64 = res?.status?.SuccessValue;
      const result = b64 ? JSON.parse(Buffer.from(b64, "base64").toString() || "null") : null;
      return { txHash, result };
    },
  };
}
