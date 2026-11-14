import { useEffect, useState, type CSSProperties } from "react";
import { MERCHANT_NAME, type Market } from "../api.ts";
import { itemName } from "../items.ts";
import { reveal } from "./reveal.ts";
import { Sprite, type SpriteName } from "./Sprites.tsx";
import { merchantStats, type MerchantKey } from "./stats.ts";

const i = (n: number) => ({ "--i": n }) as CSSProperties;
const reduced = () => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;

const STEPS: { title: string; text: string; icons: SpriteName[] }[] = [
  { title: "Gather", text: "Chop wood, fish the lake and mine ore around the valley.", icons: ["axe", "rod", "pickaxe"] },
  { title: "Haggle in chat", text: "Type an offer the way you would at a stall. The merchant answers in character and counters.", icons: ["wood", "fish", "ore"] },
  { title: "The merchant signs the deal", text: "Each merchant holds its own testnet account and signs the deal. The contract checks it before it settles.", icons: [] },
  { title: "Prices move", text: "Stock and purses change, so tomorrow's price follows what everyone traded today.", icons: [] },
];

export function HowItWorks() {
  return (
    <section id="how" className="section">
      <h2 ref={reveal} className="reveal">How a deal happens</h2>
      <ol className="steps stagger">
        {STEPS.map((s, n) => (
          <li key={s.title} ref={reveal} className="reveal lcard step" style={i(n)}>
            <span className="step-n">{n + 1}</span>
            <div className="step-icons">
              {s.icons.length ? s.icons.map((ic) => <Sprite key={ic} name={ic} size={36} />) : <img src="/brand/coin.webp" alt="" width={36} height={36} />}
            </div>
            <h3>{s.title}</h3>
            <p className="muted">{s.text}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}

const MERCHANTS: Record<MerchantKey, { trade: string; persona: string; icon: SpriteName; lines: string[] }> = {
  woodcutter: {
    trade: "Trades wood",
    persona: "Gruff, few words, proud of honest work.",
    icon: "wood",
    lines: [
      "Twenty for oak? My axe would laugh at you. Thirty, and I'll throw in a splinter for free.",
      "Pile's taller than me today. Take five at twenty-four and help an old man out.",
      "Wood's thin this week. Thirty-five, not a coin less.",
    ],
  },
  fishmonger: {
    trade: "Trades fish",
    persona: "Cheerful, chatty, knows every harbour rumour.",
    icon: "fish",
    lines: [
      "Ooh, cheeky! The gulls tried that price this morning too. Eighty-five and it's yours, love.",
      "Boats came in heavy today, I'm drowning in mackerel! Seventy each, quick before they start smelling.",
      "Nets came back empty, darling. Ninety-six, and that's me being generous.",
    ],
  },
  smith: {
    trade: "Trades ore",
    persona: "Proud and terse. Respects good iron.",
    icon: "ore",
    lines: ["Ten? This is iron, not pebbles. One fifty.", "Forge is cold, ore is scarce. Four hundred. Final.", "You sell good ore. One thirty each. Fair."],
  },
};

function MerchantCard({ k, n, purse, from }: { k: MerchantKey; n: number; purse: number | null; from: string | null }) {
  const m = MERCHANTS[k];
  const [active, setActive] = useState(false);
  const [line, setLine] = useState(0);
  useEffect(() => {
    if (!active || reduced()) return;
    const id = setInterval(() => setLine((l) => (l + 1) % m.lines.length), 2500);
    return () => clearInterval(id);
  }, [active, m.lines.length]);
  const on = () => setActive(true);
  const off = () => setActive(false);
  return (
    <article
      ref={reveal}
      className={`reveal lcard merchant-card${active ? " talking" : ""}`}
      style={i(n)}
      tabIndex={0}
      onMouseEnter={on}
      onMouseLeave={off}
      onFocus={on}
      onBlur={off}
      aria-label={`${MERCHANT_NAME[k]}, ${m.trade.toLowerCase()}`}
    >
      <p className="bubble" aria-live="polite">
        {m.lines[line]}
      </p>
      <div className="portrait">
        <img src={`/brand/${k}.webp`} alt={`${MERCHANT_NAME[k]}, merchant`} width={160} height={160} loading="lazy" />
        <span className="portrait-badge">
          <Sprite name={m.icon} size={28} />
        </span>
      </div>
      <h3>{MERCHANT_NAME[k]}</h3>
      <p className="trade">{m.trade}</p>
      <p className="muted">{m.persona}</p>
      {purse !== null && (
        <dl className="live">
          <div>
            <dt>Purse</dt>
            <dd className="num">{purse.toLocaleString("en-US")} C</dd>
          </div>
          {from && (
            <div>
              <dt>Cheapest</dt>
              <dd className="num">{from}</dd>
            </div>
          )}
        </dl>
      )}
      <p className="hint muted">Hover or focus to hear a line</p>
    </article>
  );
}

export function Merchants({ market }: { market: Market[] | null }) {
  const stats = market ? merchantStats(market) : null;
  return (
    <section id="merchants" className="section">
      <h2 ref={reveal} className="reveal">Meet the merchants</h2>
      <p ref={reveal} className="reveal lead muted">
        Three AI merchants, each with a purse, a stall and a temper. Numbers below are live from the market.
      </p>
      <div className="merchant-grid">
        {(["woodcutter", "fishmonger", "smith"] as const).map((k, n) => {
          const s = stats?.find((x) => x.key === k);
          return (
            <MerchantCard
              key={k}
              k={k}
              n={n}
              purse={s ? s.purse : null}
              from={s?.cheapest ? `${itemName(s.cheapest.item)} ${s.cheapest.ask} C` : null}
            />
          );
        })}
      </div>
    </section>
  );
}

export function WhyItMatters() {
  const cols = [
    { title: "For players", items: ["No wallet, no seed phrase, no fee popups.", "Prices react to what you gather and sell.", "Every merchant haggles in its own voice."] },
    { title: "For game devs", items: ["No hand-tuned price tables to patch.", "The AI proposes a price; the contract enforces the room.", "Every deal is signed by the merchant and visible on chain."] },
  ];
  return (
    <section className="section">
      <h2 ref={reveal} className="reveal">Why a living market</h2>
      <div className="why stagger">
        {cols.map((c, n) => (
          <div key={c.title} ref={reveal} className="reveal lcard" style={i(n)}>
            <h3>{c.title}</h3>
            <ul className="ticks">
              {c.items.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

export function BackerCoins() {
  const coins = [
    { sym: "$WOOD", who: "Woodcutter" },
    { sym: "$FISH", who: "Fishmonger" },
    { sym: "$SMITH", who: "Smith" },
  ];
  return (
    <section className="section">
      <h2 ref={reveal} className="reveal">Back a merchant</h2>
      <p ref={reveal} className="reveal lead muted">
        Supply follows the merchant's net worth, rebased once per market day, at most 5%. Web only, never inside the game.
      </p>
      <div className="coin-row">
        {coins.map((c, n) => (
          <a key={c.sym} ref={reveal} className="reveal lcard coin-card" style={i(n)} href="/app/#/coins">
            <img src="/brand/coin.webp" alt="" width={56} height={56} />
            <span>
              <strong className="num">{c.sym}</strong>
              <span className="muted"> backs the {c.who}</span>
            </span>
          </a>
        ))}
      </div>
    </section>
  );
}

const FAQ: [string, string][] = [
  ["Is this real money?", "No. Everything runs on NEAR testnet. Coin is the in-game currency and can never be exchanged for money or Robux."],
  ["Do players need a wallet?", "No. You play with your Roblox account. A game relayer submits each deal and pays the fees, so you never see a wallet, seed phrase or fee."],
  ["What does the AI actually decide?", "Only what the merchant says and the price it proposes. The price room comes from fixed pricing rules, offers outside it are pulled back, and the contract rejects any deal that slips through."],
  ["How do prices move?", "Each of the 12 goods has its own supply and demand. Sell a pile of oak and the Woodcutter pays less for it; buy the shelf empty and the price climbs. Nobody patches the table."],
  ["What are backer coins?", "Each merchant has a memecoin ($WOOD, $FISH, $SMITH) whose supply follows that merchant's net worth, rebased for every holder once per market day, capped at 5%."],
  ["Can I play now?", "Open the market to watch prices, merchant purses and every deal as it settles. The Roblox link goes up here once the experience is public."],
];

export function Faq() {
  return (
    <section id="faq" className="section narrow">
      <h2 ref={reveal} className="reveal">Questions at the stall</h2>
      <div className="faq">
        {FAQ.map(([q, a], n) => (
          <details key={q} ref={reveal} className="reveal" style={i(n)}>
            <summary>{q}</summary>
            <div className="answer">
              <p>{a}</p>
            </div>
          </details>
        ))}
      </div>
    </section>
  );
}
