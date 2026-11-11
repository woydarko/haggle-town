import { useEffect, useState } from "react";
import { api, MERCHANT_NAME, type Config, type PlayerDetail, type PlayerRow } from "./api.ts";
import { CATEGORIES, CATEGORY_NAME, CLASS_NAME, ITEMS, itemName, tierColor } from "./items.ts";

const CLASS_CATEGORY: Record<string, string> = { fisher: "fish", logger: "wood", miner: "ore" };

const time = (t: number) => new Date(t).toLocaleString();
const selectedFromHash = () => decodeURIComponent(location.hash.replace(/^#\/players\/?/, "")) || null;

/** Every player, and for one player: on-chain balances plus each deal and gather with its NEAR transaction. */
export function Players({ config }: { config: Config | null }) {
  const [list, setList] = useState<PlayerRow[] | null>(null);
  const [selected, setSelected] = useState<string | null>(selectedFromHash);
  const [detail, setDetail] = useState<PlayerDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const on = () => setSelected(selectedFromHash());
    window.addEventListener("hashchange", on);
    let alive = true;
    const load = () => api.players().then((l) => alive && setList(l)).catch(() => alive && setError("Can't reach the market. Retrying."));
    load();
    const id = setInterval(load, 10_000);
    return () => {
      alive = false;
      clearInterval(id);
      window.removeEventListener("hashchange", on);
    };
  }, []);

  useEffect(() => {
    if (!selected) return setDetail(null);
    let alive = true;
    const load = () =>
      api
        .player(selected)
        .then((d) => {
          if (alive) {
            setDetail(d);
            setError(null);
          }
        })
        .catch(() => alive && setError("Player not found or market offline."));
    load();
    const id = setInterval(load, 5_000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, [selected]);

  const tx = (hash: string | null) =>
    hash && config ? (
      <a href={`${config.explorerBase}/txns/${hash}`} target="_blank" rel="noreferrer">
        {hash.slice(0, 8)}...
      </a>
    ) : (
      <span className="muted">pending</span>
    );

  return (
    <div className="grid">
      <section className="card">
        <h2>{detail ? detail.name : "Pick a player"}</h2>
        {error && <p style={{ color: "var(--error)" }}>{error}</p>}
        {!detail ? (
          <p className="muted">Choose a player on the right to see their on-chain balances and every transaction.</p>
        ) : (
          <>
            <p className="muted" style={{ marginTop: 0 }}>
              On-chain id <code>{detail.id}</code> in{" "}
              {config ? (
                <a href={`${config.explorerBase}/address/${config.contractId}`} target="_blank" rel="noreferrer">
                  {config.contractId}
                </a>
              ) : null}
              . First seen {time(detail.firstSeen)}.
            </p>
            <p>
              <span className="num" style={{ fontSize: 22, color: "var(--primary)" }}>{detail.balances.coin ?? 0} C</span>{" "}
              {detail.class ? (
                <span className="badge" style={{ color: `var(--${CLASS_CATEGORY[detail.class]})` }}>
                  {CLASS_NAME[detail.class] ?? detail.class}
                </span>
              ) : (
                <span className="muted">no class yet</span>
              )}
            </p>
            <div className="merchants" aria-label="Items held on chain">
              {CATEGORIES.map((cat) => (
                <table key={cat} className="items">
                  <caption style={{ textAlign: "left", color: `var(--${cat})`, fontWeight: 600 }}>{CATEGORY_NAME[cat]}</caption>
                  <tbody>
                    {ITEMS.filter((i) => i.category === cat).map((i) => (
                      <tr key={i.id}>
                        <td className="name" style={{ color: tierColor(i.tier) }}>
                          {i.name}
                        </td>
                        <td className="num">{detail.balances[i.id] ?? 0}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ))}
            </div>

            <h3 style={{ marginTop: "var(--s4)" }}>Deals</h3>
            {detail.deals.length ? (
              <table>
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Deal</th>
                    <th className="num">Price</th>
                    <th>Status</th>
                    <th>Tx</th>
                  </tr>
                </thead>
                <tbody>
                  {detail.deals.map((d, i) => (
                    <tr key={i}>
                      <td className="muted">{time(d.at)}</td>
                      <td>
                        {d.side === "buy" ? "bought" : "sold"} {d.qty} {itemName(d.good)} {d.side === "buy" ? "from" : "to"} {MERCHANT_NAME[d.merchant] ?? d.merchant}
                      </td>
                      <td className="num">{d.unitPrice} C</td>
                      <td>
                        <span className="tag">{d.status === "quoted" ? "offer only" : d.status}</span>
                      </td>
                      <td>{d.status === "settled" ? tx(d.txHash) : <span className="muted">-</span>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="muted">No deals yet.</p>
            )}

            <h3 style={{ marginTop: "var(--s4)" }}>Gathered</h3>
            {detail.gathers.length ? (
              <table>
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Item</th>
                    <th>Minted in batch</th>
                  </tr>
                </thead>
                <tbody>
                  {detail.gathers.map((g, i) => (
                    <tr key={i}>
                      <td className="muted">{time(g.at)}</td>
                      <td>
                        +{g.qty} {itemName(g.good)}
                      </td>
                      <td>{tx(g.batchTx)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="muted">Nothing gathered yet.</p>
            )}
          </>
        )}
      </section>

      <section className="card">
        <h2>Players</h2>
        {!list ? (
          <div className="skeleton" />
        ) : list.length ? (
          <ul className="feed">
            {list.map((p) => (
              <li key={p.id}>
                <a href={`#/players/${encodeURIComponent(p.id)}`} aria-current={p.id === selected ? "true" : undefined}>
                  <strong>{p.name}</strong>
                </a>{" "}
                <span className="muted">
                  {p.deals} deal{p.deals === 1 ? "" : "s"} - seen {time(p.lastSeen)}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">No players yet. Join the game to appear here.</p>
        )}
      </section>
    </div>
  );
}
