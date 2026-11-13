const REQUIRED = [
  "CONTRACT_ID",
  "GAME_ACCOUNT_ID",
  "GAME_PRIVATE_KEY",
  "WOODCUTTER_PRIVATE_KEY",
  "FISHMONGER_PRIVATE_KEY",
  "SMITH_PRIVATE_KEY",
  "RBX_HMAC_SECRET",
] as const;

export type ReplayMode = "off" | "record" | "on";

export interface Config {
  CONTRACT_ID: string;
  GAME_ACCOUNT_ID: string;
  GAME_PRIVATE_KEY: string;
  WOODCUTTER_PRIVATE_KEY: string;
  FISHMONGER_PRIVATE_KEY: string;
  SMITH_PRIVATE_KEY: string;
  RBX_HMAC_SECRET: string;
  NEAR_NETWORK: string;
  NEAR_RPC_URL: string;
  NEAR_RPC_FALLBACK_URL: string;
  LLM_BASE_URL: string;
  LLM_MODEL: string;
  LLM_API_KEY: string;
  /** Request timeout; reasoning models (e.g. GLM) need ~6-10 s. */
  LLM_TIMEOUT_MS: number;
  /** "off" sends thinking: {type: "disabled"} (GLM-style) so the model answers without a long hidden reasoning pass. */
  LLM_THINKING: "on" | "off";
  REPLAY_MODE: ReplayMode;
  DB_PATH: string;
  PORT: number;
  DAY_LENGTH_MS: number;
}

/** Reads config from env. Throws one error naming every missing required variable. */
export function loadConfig(env: Record<string, string | undefined> = process.env): Config {
  const missing = REQUIRED.filter((k) => !env[k]);
  if (missing.length) throw new Error(`Missing env vars: ${missing.join(", ")}`);
  const replay = env.REPLAY_MODE ?? "off";
  if (!["off", "record", "on"].includes(replay)) throw new Error(`REPLAY_MODE must be off|record|on, got ${replay}`);
  const llmTimeout = Number(env.LLM_TIMEOUT_MS ?? 4_000);
  if (!Number.isInteger(llmTimeout) || llmTimeout <= 0) throw new Error(`LLM_TIMEOUT_MS must be a positive integer, got ${env.LLM_TIMEOUT_MS}`);
  return {
    CONTRACT_ID: env.CONTRACT_ID!,
    GAME_ACCOUNT_ID: env.GAME_ACCOUNT_ID!,
    GAME_PRIVATE_KEY: env.GAME_PRIVATE_KEY!,
    WOODCUTTER_PRIVATE_KEY: env.WOODCUTTER_PRIVATE_KEY!,
    FISHMONGER_PRIVATE_KEY: env.FISHMONGER_PRIVATE_KEY!,
    SMITH_PRIVATE_KEY: env.SMITH_PRIVATE_KEY!,
    RBX_HMAC_SECRET: env.RBX_HMAC_SECRET!,
    NEAR_NETWORK: env.NEAR_NETWORK ?? "testnet",
    NEAR_RPC_URL: env.NEAR_RPC_URL ?? "https://test.rpc.fastnear.com",
    NEAR_RPC_FALLBACK_URL: env.NEAR_RPC_FALLBACK_URL ?? "https://rpc.testnet.near.org",
    LLM_BASE_URL: env.LLM_BASE_URL ?? "https://cloud-api.near.ai/v1",
    LLM_MODEL: env.LLM_MODEL ?? "",
    LLM_API_KEY: env.LLM_API_KEY ?? "",
    LLM_TIMEOUT_MS: llmTimeout,
    LLM_THINKING: env.LLM_THINKING === "off" ? "off" : "on",
    REPLAY_MODE: replay as ReplayMode,
    DB_PATH: env.DB_PATH ?? "./data/haggle.sqlite",
    PORT: Number(env.PORT ?? 8080),
    DAY_LENGTH_MS: Number(env.DAY_LENGTH_MS ?? 300_000),
  };
}
