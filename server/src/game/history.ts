import type { Db } from "../db/db.ts";
import type { MarketView } from "../types.ts";

const MINUTE = 60_000;

/** One price point per merchant per minute (later writes in the same minute replace earlier ones). */
export function recordPrices(db: Db, rows: MarketView[], now = Date.now()) {
  const ts = Math.floor(now / MINUTE) * MINUTE;
  const put = db.prepare(
    "INSERT INTO price_point (merchant, ts, ask, bid, stock, purse) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT DO UPDATE SET ask = excluded.ask, bid = excluded.bid, stock = excluded.stock, purse = excluded.purse",
  );
  for (const m of rows) put.run(m.account_id, ts, m.ask, m.bid, m.stock, m.purse);
}

export function history(db: Db, minutes: number, goodOf: (merchant: string) => string | undefined, now = Date.now()) {
  const rows = db
    .prepare("SELECT merchant, ts, ask, bid, stock, purse FROM price_point WHERE ts >= ? ORDER BY merchant, ts")
    .all(now - minutes * MINUTE) as { merchant: string; ts: number; ask: number; bid: number; stock: number; purse: number }[];
  const out = new Map<string, { merchant: string; good: string | undefined; points: object[] }>();
  for (const r of rows) {
    const e = out.get(r.merchant) ?? { merchant: r.merchant, good: goodOf(r.merchant), points: [] };
    e.points.push({ ts: r.ts, ask: r.ask, bid: r.bid, stock: r.stock, purse: r.purse });
    out.set(r.merchant, e);
  }
  return [...out.values()];
}
