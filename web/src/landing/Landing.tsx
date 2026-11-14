import { useEffect, useState } from "react";
import { reveal } from "./reveal.ts";
import { BackerCoins, Faq, HowItWorks, Merchants, WhyItMatters } from "./Sections.tsx";
import { lastDealLine } from "./stats.ts";
import { useLive } from "./useLive.ts";

/** Public Roblox experience link; the "Play on Roblox" button stays hidden while this is empty. */
const ROBLOX_URL = "";

function Nav() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 8);
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);
  return (
    <header className={`lnav${scrolled ? " scrolled" : ""}`}>
      <div className="lnav-in">
        <a className="brand" href="/">
          <img src="/brand/coin.webp" alt="" width={32} height={32} />
          <span>Haggle Town</span>
        </a>
        <nav aria-label="Sections">
          <a href="#how">How it works</a>
          <a href="#merchants">Merchants</a>
          <a href="#faq">FAQ</a>
        </nav>
        <a className="btn-primary small" href="/app/">
          Open the market
        </a>
      </div>
    </header>
  );
}

function Hero({ dealLine }: { dealLine: string | null }) {
  return (
    <section className="hero">
      <div className="hero-bg" aria-hidden="true" />
      <div className="hero-in">
        <img className="sign" src="/brand/logo.webp" alt="Haggle Town" width={1200} height={636} fetchPriority="high" />
        <div className="hero-card">
          <h1>Haggle with AI merchants who keep their own purses.</h1>
          <p className="muted">
            A Roblox market town where prices follow supply and demand on their own. Every deal is signed by the merchant and settled on NEAR testnet.
          </p>
          <div className="ctas">
            <a className="btn-primary" href="/app/">
              Open the market
            </a>
            {ROBLOX_URL && (
              <a className="btn-ghost" href={ROBLOX_URL} target="_blank" rel="noreferrer">
                Play on Roblox
              </a>
            )}
            <a className="btn-ghost" href="#merchants">
              Meet the merchants
            </a>
          </div>
          {dealLine && (
            <p className="ticker" role="status">
              <span className="dot" aria-hidden="true" />
              <span className="ticker-line">{dealLine}</span>
              <span className="muted"> · 3 merchants · 12 goods</span>
            </p>
          )}
        </div>
      </div>
    </section>
  );
}

function CtaCard() {
  return (
    <section className="section">
      <div ref={reveal} className="reveal cta-card">
        <img className="spin-coin" src="/brand/coin.webp" alt="" width={120} height={120} />
        <div>
          <h2>The market is open</h2>
          <p className="muted">Watch prices move, check every merchant's purse and follow each deal to the chain.</p>
        </div>
        <a className="btn-primary" href="/app/">
          Open the market
        </a>
      </div>
    </section>
  );
}

function Footer({ contractUrl }: { contractUrl: string | null }) {
  return (
    <footer className="lfoot">
      <div className="lfoot-in">
        <img src="/brand/logo.webp" alt="Haggle Town" width={160} height={85} loading="lazy" />
        <nav aria-label="Footer">
          <a href="/app/">Dashboard</a>
          <a href="https://github.com/woydarko/haggle-town" target="_blank" rel="noreferrer">
            GitHub
          </a>
          {contractUrl && (
            <a href={contractUrl} target="_blank" rel="noreferrer">
              Contract
            </a>
          )}
          <a href="https://nearhackathon.com/" target="_blank" rel="noreferrer">
            NEAR Hackathon
          </a>
        </nav>
        <p className="muted small">Testnet only. Coin is never exchangeable.</p>
      </div>
    </footer>
  );
}

export function Landing() {
  const { market, feed, config } = useLive();
  return (
    <>
      <Nav />
      <main>
        <Hero dealLine={feed ? lastDealLine(feed.deals, Date.now()) : null} />
        <HowItWorks />
        <Merchants market={market} />
        <WhyItMatters />
        <BackerCoins />
        <Faq />
        <CtaCard />
      </main>
      <Footer contractUrl={config ? `${config.explorerBase}/address/${config.contractId}` : null} />
    </>
  );
}
