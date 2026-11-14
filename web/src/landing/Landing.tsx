import { reveal } from "./reveal.ts";
import { Faq, PriceBoard, Stalls, WhoSetsThePrice } from "./Sections.tsx";
import { lastDealLine } from "./stats.ts";
import { useLive, type Live } from "./useLive.ts";

/** Public Roblox experience link; the "Play on Roblox" button stays hidden while this is empty. */
const ROBLOX_URL = "";

function Nav() {
  return (
    <header className="lnav">
      <div className="lnav-in">
        <a className="brand" href="/">
          <img src="/brand/coin.webp" alt="" width={28} height={28} />
          <span>Haggle Town</span>
        </a>
        <nav aria-label="Sections">
          <a href="#merchants">Stalls</a>
          <a href="#board">Board</a>
          <a href="#faq">FAQ</a>
        </nav>
        <a className="nav-cta" href="/app/">
          Dashboard
        </a>
      </div>
    </header>
  );
}

function status(live: Live): string {
  if (!live.feed) return live.failed ? "Can't reach the market right now. Live numbers are paused." : "Checking the stalls...";
  const line = `Last deal: ${lastDealLine(live.feed.deals, live.at ?? Date.now())}`;
  return live.failed ? `${line}. Connection lost, retrying.` : line;
}

function Hero({ live }: { live: Live }) {
  return (
    <section className="hero">
      <div className="hero-photo">
        <div className="hero-bg" aria-hidden="true" />
        <img className="sign" src="/brand/logo.webp" alt="Haggle Town" width={1200} height={636} fetchPriority="high" />
      </div>
      <div className="hero-band">
        <div className="hero-copy">
          <h1>Every price in this town is up for argument.</h1>
          <p>
            Gather wood, fish and ore in a Roblox valley, then talk a merchant down in plain chat. The merchants are AI with their own testnet accounts,
            and their prices follow what players sell and buy.
          </p>
        </div>
        <div className="hero-act">
          <a className="btn-primary" href="/app/">
            Watch the market live
          </a>
          {ROBLOX_URL && (
            <a className="btn-quiet" href={ROBLOX_URL} target="_blank" rel="noreferrer">
              Play on Roblox
            </a>
          )}
          <p className="status" role="status">
            {status(live)}
          </p>
        </div>
      </div>
    </section>
  );
}

function CtaCard() {
  return (
    <section className="cta-wrap">
      <div className="cta-card" ref={reveal}>
        <img className="spin-coin" src="/brand/coin.webp" alt="" width={112} height={112} />
        <div>
          <h2>Every deal is on the record</h2>
          <p>Open the dashboard to follow any deal to its transaction, or watch a merchant's purse grow and shrink over the day.</p>
        </div>
        <a className="btn-primary" href="/app/#/players">
          See every deal
        </a>
      </div>
    </section>
  );
}

function Footer({ contractUrl }: { contractUrl: string | null }) {
  return (
    <footer className="lfoot">
      <div className="lfoot-in">
        <img src="/brand/logo.webp" alt="Haggle Town" width={150} height={80} loading="lazy" />
        <nav aria-label="Footer">
          <a href="/app/">Dashboard</a>
          <a href="https://github.com/woydarko/haggle-town" target="_blank" rel="noreferrer">
            Source on GitHub
          </a>
          {contractUrl && (
            <a href={contractUrl} target="_blank" rel="noreferrer">
              Market contract
            </a>
          )}
          <a href="https://nearhackathon.com/" target="_blank" rel="noreferrer">
            NEAR Hackathon
          </a>
        </nav>
        <p>Testnet only. Coin is never exchangeable.</p>
      </div>
    </footer>
  );
}

export function Landing() {
  const live = useLive();
  const guarded = live.feed?.guard ? live.feed.guard.count : null;
  return (
    <>
      <Nav />
      <main>
        <Hero live={live} />
        <Stalls live={live} />
        <PriceBoard live={live} />
        <WhoSetsThePrice guarded={guarded} />
        <Faq />
        <CtaCard />
      </main>
      <Footer contractUrl={live.config ? `${live.config.explorerBase}/address/${live.config.contractId}` : null} />
    </>
  );
}
