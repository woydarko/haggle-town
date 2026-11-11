import type { Db } from "../db/db.ts";
import type { MarketView } from "../types.ts";
import { itemById } from "../items.ts";

const MINUTE = 60_000;

/** One price point per item per minute (later writes in the same minute replace earlier ones). */
export function recordPrices(db: Db, rows: MarketView[], now = Date.now()) {
  const ts = Math.floor(now / MINUTE) * MINUTE;
  const put = db.prepare(
    "INSERT INTO item_price (item, ts, ask, bid, stock, purse) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT DO UPDATE SET ask = excluded.ask, bid = excluded.bid, stock = excluded.stock, purse = excluded.purse",
  );
  for (const m of rows) put.run(m.item, ts, m.ask, m.bid, m.stock, m.purse);
}

export function history(db: Db, minutes: number, now = Date.now()) {
  const rows = db
    .prepare("SELECT item, ts, ask, bid, stock, purse FROM item_price WHERE ts >= ? ORDER BY item, ts")
    .all(now - minutes * MINUTE) as { item: string; ts: number; ask: number; bid: number; stock: number; purse: number }[];
  const out = new Map<string, { item: string; name?: string; category?: string; tier?: string; points: object[] }>();
  for (const r of rows) {
    const it = itemById(r.item);
    const e = out.get(r.item) ?? { item: r.item, name: it?.name, category: it?.category, tier: it?.tier, points: [] };
    e.points.push({ ts: r.ts, ask: r.ask, bid: r.bid, stock: r.stock, purse: r.purse });
    out.set(r.item, e);
  }
  return [...out.values()];
}
