import { useEffect, useState } from "react";
import { api, MERCHANT_NAME, type Config, type Feed, type History, type Leader, type Market } from "./api.ts";
import { CategoryChips, PriceChart, categorySeries } from "./PriceChart.tsx";
import { CATEGORIES, CATEGORY_MERCHANT, CATEGORY_NAME, itemName, tierColor, type Category } from "./items.ts";
import { FastForward } from "./FastForward.tsx";
import { Players } from "./Players.tsx";
import { Coins } from "./Coins.tsx";

type Data = { market: Market[]; feed: Feed; leaders: Leader[] };
const RANGES: [number, string][] = [[60, "1 h"], [360, "6 h"], [1440, "24 h"]];
const tabFromHash = () => (location.hash.startsWith("#/players") ? "players" : location.hash.startsWith("#/coins") ? "coins" : "market");

const ago = (t: number) => {
  const s = Math.max(0, Math.round((Date.now() - t) / 1000));
  return s < 60 ? `${s}s ago` : s < 3600 ? `${Math.round(s / 60)}m ago` : `${Math.round(s / 3600)}h ago`;
};

export function App() {
  const [config, setConfig] = useState<Config | null>(null);
  const [data, setData] = useState<Data | null>(null);
  const [offline, setOffline] = useState(false);
  const [tab, setTab] = useState(tabFromHash);
  const [range, setRange] = useState(60);
  const [metric, setMetric] = useState<"ask" | "stock">("ask");
  const [hist, setHist] = useState<History>([]);
  const [chartCat, setChartCat] = useState<Category>("fish");

  useEffect(() => {
    const on = () => setTab(tabFromHash());
    window.addEventListener("hashchange", on);
    return () => window.removeEventListener("hashchange", on);
  }, []);

  useEffect(() => {
    let alive = true;
    const load = () => api.history(range).then((h) => alive && setHist(h)).catch(() => undefined);
    load();
    const id = setInterval(load, 15_000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, [range]);

  useEffect(() => {
    let alive = true;
    api.config().then(setConfig).catch(() => undefined);
    const load = async () => {
      try {
        const [market, feed, leaders] = await Promise.all([api.market(), api.feed(), api.leaderboard()]);
        if (alive) {
          setData({ market, feed, leaders });
          setOffline(false);
        }
      } catch {
        if (alive) setOffline(true);
      }
    };
    load();
    const id = setInterval(load, 5_000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);

  const tx = (hash: string) => (config ? `${config.explorerBase}/txns/${hash}` : "#");

  return (
    <main className="wrap">
      <header className="top">
        <div>
          <h1>Haggle Town market</h1>
          <p className="muted">
            Three AI merchants run their own NEAR {config?.network ?? "testnet"} purses and trade 12 items from common to legendary. Each price follows that item's supply and demand; every deal below is
            signed by the merchant and settled on chain{config ? <> by <code>{config.contractId}</code></> : null}.
          </p>
        </div>
      </header>

      <nav className="tabs" aria-label="Views">
        <a href="#/" aria-current={tab === "market" ? "page" : undefined}>Market</a>
        <a href="#/players" aria-current={tab === "players" ? "page" : undefined}>Players & transactions</a>
        <a href="#/coins" aria-current={tab === "coins" ? "page" : undefined}>Backer coins</a>
      </nav>

      {offline && <div className="banner" role="status">Can't reach the market. Retrying in 5 s.</div>}

      {tab === "players" ? (
        <Players config={config} />
      ) : tab === "coins" ? (
        <Coins config={config} />
      ) : !data ? (
        <div className="grid">
          <div className="skeleton" />
          <div className="skeleton" />
        </div>
      ) : (
        <>
          <section className="merchants" aria-label="Merchants">
            {CATEGORIES.map((cat) => {
              const rows = data.market.filter((m) => m.category === cat);
              if (!rows.length) return null;
              const purse = rows[0].purse; // one purse per merchant, shared by its four items
              return (
                <article key={cat} className="card merchant">
                  <div className="name" style={{ color: `var(--${cat})` }}>
                    {CATEGORY_MERCHANT[cat]}
                  </div>
                  <div className="muted">
                    buys and sells {CATEGORY_NAME[cat].toLowerCase()} - purse <span className="num">{purse.toLocaleString()} C</span>
                  </div>
                  <table className="items">
                    <thead>
                      <tr>
                        <th>Item</th>
                        <th className="num">Ask</th>
                        <th className="num">Bid</th>
                        <th className="num">Stock</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rows.map((m) => (
                        <tr key={m.item}>
                          <td className="name" style={{ color: tierColor(m.tier) }}>
                            {itemName(m.item)}
                          </td>
                          <td className="num">{m.ask}</td>
                          <td className="num">{m.bid}</td>
                          <td className="num">
                            {m.stock}/{m.target}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {rows.every((m) => m.ceiling_one === null) && <p style={{ color: "var(--error)" }}>Closed for buying - empty purse</p>}
                </article>
              );
            })}
          </section>

          <section className="card" style={{ marginTop: "var(--s4)" }}>
            <h2>A week in Haggle Town</h2>
            <p className="muted" style={{ marginTop: 0 }}>
              Same pricing rules as the contract, ten bot traders, seven game days in one minute. Simulated, not on chain.
            </p>
            <FastForward />
          </section>

          <div className="grid" style={{ marginTop: "var(--s4)" }}>
            <section className="card">
              <h2>{metric === "ask" ? "Prices" : "Merchant stock"}</h2>
              <div className="controls" role="group" aria-label="Chart range and metric">
                {RANGES.map(([m, label]) => (
                  <button key={m} className="chip" aria-pressed={range === m} onClick={() => setRange(m)}>
                    {label}
                  </button>
                ))}
                <span className="muted"> | </span>
                <button className="chip" aria-pressed={metric === "ask"} onClick={() => setMetric("ask")}>ask price</button>
                <button className="chip" aria-pressed={metric === "stock"} onClick={() => setMetric("stock")}>stock</button>
                <span className="muted"> | </span>
                <CategoryChips value={chartCat} onChange={setChartCat} />
              </div>
              {hist.length ? (
                <PriceChart
                  yLabel={metric === "ask" ? "ask (C)" : "stock"}
                  series={categorySeries(chartCat, (item) => (hist.find((h) => h.item === item)?.points ?? []).map((p) => ({ ts: p.ts / 1000, ask: p[metric] })))}
                />
              ) : (
                <p className="muted">Collecting prices... the first points appear within a minute.</p>
              )}
            </section>

            <section className="card">
              <h2>Richest traders</h2>
              {data.leaders.length ? (
                <table>
                  <tbody>
                    {data.leaders.map((l, i) => (
                      <tr key={l.name + i}>
                        <td>{i + 1}.</td>
                        <td>{l.name}</td>
                        <td className="num">{l.netWorth.toLocaleString()} C</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p className="muted">No traders yet. Join the game and make the first deal.</p>
              )}
            </section>

            <section className="card">
              <h2>Deals on chain</h2>
              {data.feed.deals.length ? (
                <ul className="feed">
                  {data.feed.deals.map((d) => (
                    <li key={d.txHash}>
                      <strong>{d.player}</strong> {d.side === "buy" ? "bought" : "sold"} {d.qty} {itemName(d.good)} @ <span className="num">{d.unitPrice} C</span>{" "}
                      {d.side === "buy" ? "from" : "to"} {MERCHANT_NAME[d.merchant] ?? d.merchant}{" "}
                      <span className="muted">{ago(d.at)}</span>{" "}
                      <a href={tx(d.txHash)} target="_blank" rel="noreferrer">
                        tx
                      </a>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">No deals yet - be the first in Haggle Town.</p>
              )}
            </section>

            <section className="card">
              <h2>Forge</h2>
              <p className="muted">
                Players upgrade their tools with goods from the other trades, so every class buys from every merchant. Forged goods are burned on
                chain.
              </p>
              {data.feed.forges?.length ? (
                <ul className="feed">
                  {data.feed.forges.map((f) => (
                    <li key={f.txHash}>
                      <strong>{f.player}</strong> forged a {f.level === 3 ? "Master" : "Sturdy"} {f.tool[0].toUpperCase() + f.tool.slice(1)}, burning{" "}
                      {Object.entries(f.cost)
                        .map(([id, n]) => `${n} ${itemName(id)}`)
                        .join(" + ")}{" "}
                      <span className="muted">{ago(f.at)}</span>{" "}
                      <a href={tx(f.txHash)} target="_blank" rel="noreferrer">
                        tx
                      </a>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">No tools forged yet.</p>
              )}
            </section>

            <section className="card">
              <h2>Guardrail</h2>
              <p className="muted">
                The AI picks the words and proposes a price. Prices outside the rules in pricing.rs are pulled back before a deal is offered, and the
                contract rejects any that slip through. Pulled back so far: <span className="num">{data.feed.guard?.count ?? 0}</span>
              </p>
              {data.feed.guard?.recent.length ? (
                <ul className="feed">
                  {data.feed.guard.recent.map((g, i) => (
                    <li key={i}>
                      <strong>{MERCHANT_NAME[g.merchant] ?? g.merchant}</strong> wanted <span className="num">{g.wanted} C</span> for {itemName(g.item)}, rules
                      allow <span className="num">{g.lo}-{g.hi} C</span>, offered <span className="num">{g.sent} C</span> <span className="muted">{ago(g.at)}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">No AI price has crossed the rules yet. Try talking a merchant into a free deal.</p>
              )}
            </section>

            <section className="card">
              <h2>What the merchants are saying</h2>
              {data.feed.chat.length ? (
                <ul className="feed">
                  {data.feed.chat.map((c, i) => (
                    <li key={i}>
                      <strong>{MERCHANT_NAME[c.merchant] ?? c.merchant}</strong> <span className="tag">{c.mood}</span>{" "}
                      <span className="tag">{c.source}</span>
                      <div>"{c.line}"</div>
                      {c.reasoning && <div className="muted">{c.reasoning}</div>}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">Quiet market. Haggle with a merchant to see their reasoning here.</p>
              )}
            </section>
          </div>
        </>
      )}
    </main>
  );
}
