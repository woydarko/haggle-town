import { useEffect, useState } from "react";
import { api, MERCHANT_NAME, merchantKey, type CoinView, type Config } from "./api.ts";

const units = (s: string) => Number(s) / 1e6; // 6 decimals
const pct = (bp: number) => `${bp > 0 ? "+" : ""}${(bp / 100).toFixed(2)}%`;

/** Growth of one backed coin over the shown rebases: the product of each day's step. */
function Spark({ steps }: { steps: number[] }) {
  if (steps.length < 2) return null;
  let v = 1;
  const pts = [1, ...steps.map((s) => (v *= 1 + s / 10_000))];
  const lo = Math.min(...pts), hi = Math.max(...pts), w = 240, h = 48;
  const y = (p: number) => (hi === lo ? h / 2 : h - ((p - lo) / (hi - lo)) * (h - 4) - 2);
  const d = pts.map((p, i) => `${(i / (pts.length - 1)) * w},${y(p).toFixed(1)}`).join(" ");
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" height={h} role="img" aria-label={`Last ${steps.length} market days: ${pct(Math.round((v - 1) * 10_000))} overall`}>
      <polyline points={d} fill="none" stroke="var(--primary)" strokeWidth="2" />
    </svg>
  );
}

/** $WOOD, $FISH, $SMITH: NEP-141 memecoins whose supply follows each AI merchant's net worth, on chain. */
export function Coins({ config }: { config: Config | null }) {
  const [coins, setCoins] = useState<CoinView[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    const load = () =>
      api
        .coins()
        .then((c) => alive && (setCoins(c), setError(null)))
        .catch(() => alive && setError("Can't read the coin contracts. Retrying."));
    load();
    const id = setInterval(load, 10_000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);

  const account = (id: string) => (config ? <a href={`${config.explorerBase}/address/${id}`} target="_blank" rel="noreferrer">{id}</a> : id);

  return (
    <>
      <section className="card">
        <h2>Back a merchant</h2>
        <p>
          Each AI merchant has a memecoin. Once per market day anyone can call <code>tick()</code>: the coin contract reads the market
          contract on chain, values its merchant (purse + stock at its own bid) and rebases <strong>every holder</strong> by the change, at
          most 5% a day. A merchant that holds its prices against haggling players makes its backers richer; one that gets talked into
          bad deals shrinks every wallet. Back the house, or bet on the hagglers.
        </p>
        <p className="muted">
          Rules fixed at launch, no admin key, no method to change them: 5% daily cap, 1000 coins per backer, 1000 backers per coin,
          0.01 NEAR deposit per backer (storage and a cost per extra identity). Splitting coins across accounts gains nothing: every
          balance moves by the same percent. Testnet only, never used inside the Roblox game.
        </p>
      </section>

      {error && <p style={{ color: "var(--error)" }}>{error}</p>}
      {!coins ? (
        <div className="skeleton" />
      ) : (
        <section className="merchants" aria-label="Backer coins">
          {coins.map((c) => {
            const last = c.recent[c.recent.length - 1];
            const step = last?.step_bp ?? 0;
            return (
              <article key={c.id} className="card merchant">
                <div className="name">
                  ${c.symbol} <span className="muted">backs the {MERCHANT_NAME[merchantKey(c.merchant)] ?? c.merchant}</span>
                </div>
                <dl>
                  <dt>Supply</dt>
                  <dd className="num">{units(c.total_supply).toLocaleString(undefined, { maximumFractionDigits: 2 })}</dd>
                  <dt>1 backed coin now</dt>
                  <dd className="num">{(Number(c.index) / 1e12).toFixed(4)}</dd>
                  <dt>Last rebase</dt>
                  <dd className="num" style={{ color: step > 0 ? "var(--success)" : step < 0 ? "var(--error)" : undefined }}>
                    {step > 0 ? "▲ " : step < 0 ? "▼ " : ""}
                    {pct(step)} {last ? `(day ${last.day})` : ""}
                  </dd>
                  <dt>Merchant worth</dt>
                  <dd className="num">{Number(c.last_worth).toLocaleString()} C</dd>
                  <dt>Backers</dt>
                  <dd className="num">
                    {c.holders} / {c.holders + c.claims_left}
                  </dd>
                </dl>
                <Spark steps={c.recent.slice(1).map((r) => r.step_bp)} />
                <details>
                  <summary>Rebase log</summary>
                  <table className="items">
                    <thead>
                      <tr>
                        <th>Day</th>
                        <th className="num">Worth</th>
                        <th className="num">Step</th>
                        <th className="num">Supply</th>
                      </tr>
                    </thead>
                    <tbody>
                      {[...c.recent].reverse().map((r) => (
                        <tr key={r.day}>
                          <td>{r.day}</td>
                          <td className="num">{Number(r.worth).toLocaleString()}</td>
                          <td className="num">{pct(r.step_bp)}</td>
                          <td className="num">{units(r.supply).toFixed(2)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </details>
                <details>
                  <summary>Back it (near CLI)</summary>
                  <p className="muted">Contract: {account(c.id)}</p>
                  <code style={{ display: "block", whiteSpace: "pre-wrap", fontSize: "var(--fs-small)" }}>
                    near contract call-function as-transaction {c.id} back json-args '{"{}"}' prepaid-gas '30 Tgas' attached-deposit '0.01 NEAR'
                    sign-as YOUR_ACCOUNT.testnet network-config testnet sign-with-keychain send
                  </code>
                </details>
              </article>
            );
          })}
        </section>
      )}
    </>
  );
}
