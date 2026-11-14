/** One row per item (12): its merchant (account id), category and tier, live price and stock. */
export type Market = {
  merchant: string;
  category: "fish" | "wood" | "ore";
  item: string;
  tier: string;
  stock: number;
  purse: number;
  target: number;
  ask: number;
  bid: number;
  floor: number;
  ceiling_one: number | null;
  day: number;
};
export type Deal = { at: number; player: string; merchant: string; good: string; qty: number; unitPrice: number; side: string; txHash: string };
export type Chat = { at: number; merchant: string; line: string; mood: string; source: string; reasoning: string | null };
export type Guard = { at: number; merchant: string; item: string; side: string; wanted: number; lo: number; hi: number; sent: number };
export type Forged = { at: number; player: string; tool: string; level: number; cost: Record<string, number>; txHash: string };
export type Feed = { deals: Deal[]; chat: Chat[]; guard: { count: number; recent: Guard[] }; forges?: Forged[] };
export type Leader = { name: string; netWorth: number };
export type Rebase = { day: number; worth: string; step_bp: number; supply: string };
export type CoinView = {
  id: string;
  symbol: string;
  merchant: string;
  cap_bp: number;
  claims_left: number;
  holders: number;
  index: string;
  total_supply: string;
  last_worth: string;
  last_day: number;
  recent: Rebase[];
};
export type History = { item: string; points: { ts: number; ask: number; bid: number; stock: number; purse: number }[] }[];
export type Config = { contractId: string; network: string; explorerBase: string };
export type PlayerRow = { id: string; name: string; lastSeen: number; deals: number };
export type PlayerDeal = { at: number; merchant: string; good: string; qty: number; unitPrice: number; side: string; status: string; txHash: string | null };
export type PlayerDetail = {
  id: string;
  name: string;
  firstSeen: number;
  lastSeen: number;
  class: string | null;
  balances: Record<string, number>; // coin + the 12 item ids
  deals: PlayerDeal[];
  gathers: { at: number; good: string; qty: number; batchTx: string | null }[];
};

async function get<T>(path: string): Promise<T> {
  const r = await fetch(path);
  if (!r.ok) throw new Error(`${path} ${r.status}`);
  return r.json() as Promise<T>;
}

export const api = {
  config: () => get<Config>("/api/config"),
  market: () => get<Market[]>("/api/market"),
  feed: () => get<Feed>("/api/feed"),
  leaderboard: () => get<Leader[]>("/api/leaderboard"),
  coins: () => get<CoinView[]>("/api/coins"),
  history: (minutes = 60) => get<History>(`/api/history?minutes=${minutes}`),
  players: () => get<PlayerRow[]>("/api/players"),
  player: (id: string) => get<PlayerDetail>(`/api/players/${encodeURIComponent(id)}`),
};

export const MERCHANT_NAME: Record<string, string> = { woodcutter: "Woodcutter", fishmonger: "Fishmonger", smith: "Smith" };
export const merchantKey = (accountOrName: string) => accountOrName.split(".")[0];
