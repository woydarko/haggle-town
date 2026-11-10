export type Market = {
  account_id: string;
  good: "wood" | "fish" | "iron";
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
export type Feed = { deals: Deal[]; chat: Chat[] };
export type Leader = { name: string; netWorth: number };
export type History = { merchant: string; good: string; points: { ts: number; ask: number; bid: number; stock: number; purse: number }[] }[];
export type Config = { contractId: string; network: string; explorerBase: string };
export type PlayerRow = { id: string; name: string; lastSeen: number; deals: number };
export type PlayerDeal = { at: number; merchant: string; good: string; qty: number; unitPrice: number; side: string; status: string; txHash: string | null };
export type PlayerDetail = {
  id: string;
  name: string;
  firstSeen: number;
  lastSeen: number;
  balances: { coin: number; wood: number; fish: number; iron: number };
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
  history: (minutes = 60) => get<History>(`/api/history?minutes=${minutes}`),
  players: () => get<PlayerRow[]>("/api/players"),
  player: (id: string) => get<PlayerDetail>(`/api/players/${encodeURIComponent(id)}`),
};

export const MERCHANT_NAME: Record<string, string> = { woodcutter: "Woodcutter", fishmonger: "Fishmonger", smith: "Smith" };
export const merchantKey = (accountOrName: string) => accountOrName.split(".")[0];
