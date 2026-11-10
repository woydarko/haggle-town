import { useEffect, useState } from "react";
import { api, MERCHANT_NAME, merchantKey, type Config, type Feed, type History, type Leader, type Market } from "./api.ts";
import { PriceChart } from "./PriceChart.tsx";
import { FastForward } from "./FastForward.tsx";
import { Players } from "./Players.tsx";

type Data = { market: Market[]; feed: Feed; leaders: Leader[] };
const RANGES: [number, string][] = [[60, "1 h"], [360, "6 h"], [1440, "24 h"]];
const tabFromHash = () => (location.hash.startsWith("#/players") ? "players" : "market");

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
            Three AI merchants run their own NEAR {config?.network ?? "testnet"} purses. Prices follow supply and demand; every deal below is
            signed by the merchant and settled on chain{config ? <> by <code>{config.contractId}</code></> : null}.
          </p>
        </div>
      </header>

      <nav className="tabs" aria-label="Views">
        <a href="#/" aria-current={tab === "market" ? "page" : undefined}>Market</a>
        <a href="#/players" aria-current={tab === "players" ? "page" : undefined}>Players & transactions</a>
      </nav>

      {offline && <div className="banner" role="status">Can't reach the market. Retrying in 5 s.</div>}

      {tab === "players" ? (
        <Players config={config} />
      ) : !data ? (
        <div className="grid">
          <div className="skeleton" />
          <div className="skeleton" />
        </div>
      ) : (
        <>
          <section className="merchants" aria-label="Merchants">
            {data.market.map((m) => {
              const key = merchantKey(m.account_id);
              const pct = Math.min(100, Math.round((m.stock / (m.target * 2)) * 100));
              return (
                <article key={m.account_id} className="card merchant">
                  <div className="name" style={{ color: `var(--${m.good})` }}>
                    {MERCHANT_NAME[key] ?? key}
                  </div>
                  <div className="muted">sells and buys {m.good}</div>
                  <dl>
                    <dt>Ask</dt>
                    <dd className="num">{m.ask} C</dd>
                    <dt>Bid</dt>
                    <dd className="num">{m.bid} C</dd>
                    <dt>Haggle floor</dt>
                    <dd className="num">{m.floor} C</dd>
                    <dt>Purse</dt>
                    <dd className="num">{m.purse.toLocaleString()} C</dd>
                    <dt>Stock</dt>
                    <dd className="num">
                      {m.stock} / {m.target}
                    </dd>
                  </dl>
                  <div className="bar" aria-hidden>
                    <span style={{ width: `${pct}%`, background: `var(--${m.good})` }} />
                  </div>
                  {m.ceiling_one === null && <p style={{ color: "var(--error)" }}>Closed for buying - empty purse</p>}
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
              </div>
              {hist.length ? (
                <PriceChart
                  yLabel={metric === "ask" ? "ask (C)" : "stock"}
                  series={hist.map((h) => ({ good: h.good, points: h.points.map((p) => ({ ts: p.ts / 1000, ask: p[metric] })) }))}
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
                      <strong>{d.player}</strong> {d.side === "buy" ? "bought" : "sold"} {d.qty} {d.good} @ <span className="num">{d.unitPrice} C</span>{" "}
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
