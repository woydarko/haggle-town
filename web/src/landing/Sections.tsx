import type { Chat, Config, Deal } from "../api.ts";
import { MERCHANT_NAME } from "../api.ts";
import { CATEGORY_MERCHANT, itemName, ITEMS, type Category } from "../items.ts";
import { reveal } from "./reveal.ts";
import { Sprite, type SpriteName } from "./Sprites.tsx";
import { ago, latestLines, merchantStats, priceMoves, type MerchantKey } from "./stats.ts";
import type { Live } from "./useLive.ts";

/** Per-merchant facts. tool: the pixel tool players gather that merchant's goods with (shown as the portrait badge). */
const STALLS: Record<MerchantKey, { trade: string; persona: string; tool: SpriteName; coin: string; fallback: string }> = {
  woodcutter: {
    trade: "Buys and sells wood",
    persona: "Gruff and short with words. Jokes about his axe, never about the price.",
    tool: "axe",
    coin: "$WOOD",
    fallback: "Wood's thin this week. Thirty-five, not a coin less.",
  },
  fishmonger: {
    trade: "Buys and sells fish",
    persona: "Talks more than she sells. Knows which boats came in heavy today.",
    tool: "rod",
    coin: "$FISH",
    fallback: "Boats came in heavy today, I'm drowning in mackerel! Seventy each, quick before they start smelling.",
  },
  smith: {
    trade: "Buys and sells ore",
    persona: "Respects good iron and players who don't waste his time.",
    tool: "pickaxe",
    coin: "$SMITH",
    fallback: "Forge is cold, ore is scarce. Four hundred. Final.",
  },
};

const KEYS: MerchantKey[] = ["woodcutter", "fishmonger", "smith"];
const CATEGORY_OF: Record<MerchantKey, Category> = { woodcutter: "wood", fishmonger: "fish", smith: "ore" };

function Said({ c, fallback, now }: { c: Chat | null; fallback: string; now: number }) {
  if (!c) {
    return (
      <figure className="said">
        <blockquote>{fallback}</blockquote>
        <figcaption>No haggling at this stall yet today. A line from earlier days.</figcaption>
      </figure>
    );
  }
  return (
    <figure className="said">
      <blockquote>{c.line}</blockquote>
      <figcaption>
        Said to a player {ago(c.at, now)}, {c.mood}
      </figcaption>
    </figure>
  );
}

export function Stalls({ live }: { live: Live }) {
  const now = live.at ?? Date.now();
  const lines = live.feed ? latestLines(live.feed.chat) : null;
  const stats = live.market ? merchantStats(live.market) : null;
  return (
    <section id="merchants" className="stalls">
      <div className="stalls-head" ref={reveal}>
        <h2>The three stalls</h2>
        <p className="muted">The quote under each merchant is the last thing they said to a real player in the game.</p>
      </div>
      {KEYS.map((k, n) => {
        const s = STALLS[k];
        const stat = stats?.find((x) => x.key === k);
        return (
          <article key={k} className={`stall${n % 2 ? " flip" : ""}`}>
            <div className="portrait">
              <img src={`/brand/${k}.webp`} alt={`${MERCHANT_NAME[k]}, as seen in the game`} width={200} height={200} loading="lazy" />
              <span className="badge-tool" title={`Gathered with the ${s.tool}`}>
                <Sprite name={s.tool} size={30} />
              </span>
            </div>
            <div className="stall-body">
              <h3>{MERCHANT_NAME[k]}</h3>
              <p className="trade">{s.trade}</p>
              <p className="muted">{s.persona}</p>
              {lines ? <Said c={lines[k]} fallback={s.fallback} now={now} /> : <p className="state">{live.failed ? "Can't load what the merchants said right now." : "Listening at the stall..."}</p>}
              <p className="stall-meta">
                <span>
                  Purse{" "}
                  <strong className="num">{stat ? `${stat.purse.toLocaleString("en-US")} C` : live.failed ? "unavailable" : "checking..."}</strong>
                </span>
                <a href="/app/#/coins">Back the {MERCHANT_NAME[k]} with {s.coin}</a>
              </p>
            </div>
          </article>
        );
      })}
    </section>
  );
}

function DealTape({ deals, config, now }: { deals: Deal[]; config: Config | null; now: number }) {
  const recent = [...deals].sort((a, b) => b.at - a.at).slice(0, 6);
  if (!recent.length) return <p className="state">No deals settled yet. The first one shows up here within ten seconds.</p>;
  return (
    <ol className="tape">
      {recent.map((d) => (
        <li key={d.txHash}>
          <span className="tape-what">
            {MERCHANT_NAME[d.merchant.split(".")[0]] ?? d.merchant} {d.side === "buy" ? "sold" : "bought"} {d.qty} {itemName(d.good)}
          </span>
          <span className="num">{d.unitPrice} C</span>
          <span className="tape-when">{ago(d.at, now)}</span>
          {config && (
            <a href={`${config.explorerBase}/txns/${d.txHash}`} target="_blank" rel="noreferrer" aria-label={`Transaction for ${itemName(d.good)}, opens the explorer`}>
              tx
            </a>
          )}
        </li>
      ))}
    </ol>
  );
}

export function PriceBoard({ live }: { live: Live }) {
  const now = live.at ?? Date.now();
  const moves = live.market ? priceMoves(live.prevMarket, live.market) : {};
  const ask = new Map(live.market?.map((r) => [r.item, r]));
  return (
    <section id="board" className="board-band">
      <div className="board-in">
        <div className="board-head" ref={reveal}>
          <h2>Today's board</h2>
          <p>
            Asking prices for all 12 goods, read from the market contract every ten seconds. A price that moves while you watch gets a ▲ or ▼.
            {live.failed && live.market && <strong> Numbers paused, retrying.</strong>}
          </p>
        </div>
        <div className="board">
          {!live.market ? (
            <p className="state">{live.failed ? "Can't reach the market right now. The board fills in as soon as it answers." : "Chalking up today's prices..."}</p>
          ) : (
            KEYS.map((k) => (
              <div key={k} className="board-col">
                <h3>
                  <Sprite name={CATEGORY_OF[k] as SpriteName} size={26} /> {CATEGORY_MERCHANT[CATEGORY_OF[k]]}
                </h3>
                <dl>
                  {ITEMS.filter((i) => i.category === CATEGORY_OF[k]).map((i) => {
                    const r = ask.get(i.id);
                    const m = moves[i.id];
                    return (
                      <div key={i.id} className="board-row">
                        <dt>{i.name}</dt>
                        <dd>
                          {m && <span className={`move ${m}`} aria-label={m === "up" ? "went up" : "went down"}>{m === "up" ? "▲" : "▼"}</span>}
                          <span key={r?.ask} className={`num price${m ? " flash" : ""}`}>{r ? `${r.ask} C` : "n/a"}</span>
                        </dd>
                      </div>
                    );
                  })}
                </dl>
              </div>
            ))
          )}
        </div>
        <div className="tape-wrap">
          <h3>Last deals settled</h3>
          {live.feed ? <DealTape deals={live.feed.deals} config={live.config} now={now} /> : <p className="state">{live.failed ? "Can't load the deal list right now." : "Fetching the last deals..."}</p>}
        </div>
      </div>
    </section>
  );
}

export function WhoSetsThePrice({ guarded }: { guarded: number | null }) {
  return (
    <section id="rules" className="rules">
      <div className="rules-figure" ref={reveal}>
        {guarded !== null ? (
          <>
            <span className="big num">{guarded.toLocaleString("en-US")}</span>
            <span>offers pulled back into the allowed price room so far</span>
          </>
        ) : (
          <span className="state">The pulled-back count shows here when the market answers.</span>
        )}
      </div>
      <div className="rules-text">
        <h2>Who sets the price</h2>
        <p>
          The merchant's AI writes what it says and proposes a number. It doesn't get the last word. Fixed pricing rules give each item a floor and a
          ceiling for the day, an offer outside that room is pulled back before the player sees it, and the contract refuses any deal that still slips
          through.
        </p>
        <p>
          Players never deal with any of this. There is no wallet to connect and no fee to pay; a game account submits every deal on their behalf.
        </p>
      </div>
    </section>
  );
}

const FAQ: [string, string][] = [
  ["Is this real money?", "No. Everything runs on NEAR testnet. Coin is the in-game currency and can never be exchanged for money or Robux."],
  ["Do players need a wallet?", "No. You play with your Roblox account. A game account submits each deal and pays the fee, so you never see a wallet, a seed phrase or a fee."],
  ["What does the AI actually decide?", "What the merchant says and the price it proposes. The price room comes from fixed rules, and the contract rejects any deal outside it."],
  ["Why do prices change?", "Each of the 12 goods has its own supply and demand. Sell a pile of oak and the Woodcutter pays less for it; buy the shelf empty and the price climbs."],
  ["What are backer coins?", "Each merchant has a coin ($WOOD, $FISH, $SMITH) whose supply follows that merchant's net worth. It is rebased for every holder once per market day, by at most 5%, and only exists on this website, never inside the game."],
  ["Where is the game?", "On Roblox. The public link goes here once the experience is published; until then the dashboard shows the same market live."],
];

export function Faq() {
  return (
    <section id="faq" className="faq-sec">
      <h2 ref={reveal}>Questions people ask at the stall</h2>
      <div className="faq">
        {FAQ.map(([q, a]) => (
          <details key={q}>
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
