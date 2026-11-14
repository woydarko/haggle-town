# Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A branded landing page at `/` (village hero, wooden-sign logo, merchant portraits, FAQ, CTA, footer) that sends people to the dashboard, which moves to `/app/`.

**Architecture:** Vite multi-page build: `web/index.html` -> `src/landing/main.tsx` (new, no uPlot), `web/app/index.html` -> existing `src/main.tsx`. Fastify keeps serving `web/dist`; `/app` redirects to `/app/`. Motion is CSS plus one `IntersectionObserver` hook; live numbers come from the existing `/api/market`, `/api/feed`, `/api/config`.

**Tech Stack:** Vite 8, React 19, TypeScript 7, Node 24 test runner (native TS), Python Pillow (one-off asset conversion), Roblox Studio MCP (portrait captures).

**Spec:** `docs/superpowers/specs/2026-11-14-landing-page-design.md`

## Global Constraints
- Colors, fonts, spacing only from `web/src/theme.css` tokens; new tokens go in `theme.css` `:root`.
- No new npm dependency.
- `prefers-reduced-motion: reduce` -> final state, no loops (existing global rule in `theme.css` must keep winning).
- Contrast >= 4.5:1 for text; text over the hero photo sits on a solid or scrimmed surface.
- Prices written with " C" suffix (e.g. `14 C`). Web may say NEAR/testnet. No hype words ("revolutionary", "seamless", "unlock").
- Images in `web/public/brand/` as WebP; hero < 300 KB, logo < 150 KB, each portrait < 60 KB.
- Layout works at 390, 768, 1280 px with no horizontal scroll.
- Submit target 2026-11-15 06:29 +0700. Total budget for this plan: 2.5 h.

## Review Focus
- API down or slow: landing renders fully; live strip and live merchant numbers are hidden, no error banner, no layout jump. (Task 3 test + Task 4 check)
- Feed with zero deals: strip shows "Market just opened" instead of a deal line. (Task 3 test)
- Old shared links like `/#/coins` or `/#/players`: landing forwards to `/app/#/coins` before render. (Task 2 check)
- Reveal never firing (observer unsupported, reduced motion): content still visible; hidden state applies only under `html.js` and outside reduced motion. (Task 4 check)
- Phone 390 px: logo, CTAs and merchant cards fit, no horizontal scroll. (Task 6 check)

---

### Task 1: Brand assets

**Files:**
- Create: `web/public/brand/logo.webp`, `coin.webp`, `favicon.png`, `hero.webp`, `woodcutter.webp`, `fishmonger.webp`, `smith.webp`
- Scratch (not committed): `<scratchpad>/brand.py`

**Interfaces:**
- Produces: public URLs `/brand/logo.webp` (1200 w), `/brand/coin.webp` (256 w), `/brand/favicon.png` (64), `/brand/hero.webp` (1920 w), `/brand/{woodcutter,fishmonger,smith}.webp` (320x320).

- [ ] **Step 1: Convert user art.** `brand.py` with Pillow: logo `C:\Users\nabil\Downloads\Haggle Town Logo.png` -> crop to alpha bbox, resize 1200 w, WebP q=85 with alpha; coin `Haggle Coin.png` -> alpha bbox, 256 w WebP + 64 px PNG favicon; hero `hero banner.jpg` (2892x1440) -> 1920 w WebP q=78.
- [ ] **Step 2: Capture portraits.** In Studio Edit mode clone `ServerStorage.Assets.NPCs.{woodcutter,fishmonger,smith}` into a temp `workspace._RefShot` folder on a `#F4ECDD` backdrop (as done in brainstorming), rotate 180 deg to face camera, `screen_capture` each head at ~3.5 studs distance, head y = 805.37. Destroy `_RefShot` after. Crop each capture square around the head-and-shoulders, 320x320 WebP q=80.
- [ ] **Step 3: Verify.** Run: `ls -la web/public/brand` -> 7 files, sizes within Global Constraints. Open each in Read to eyeball the crop.
- [ ] **Step 4: Commit.** `rtk git add web/public/brand && rtk git commit -m "feat(web): brand assets for the landing page"`

### Task 2: Multi-page split and routing

**Files:**
- Create: `web/app/index.html` (current `web/index.html` head + `<script type="module" src="/src/main.tsx">`, title "Haggle Town market", favicon `/brand/favicon.png`)
- Modify: `web/index.html` (landing: title "Haggle Town", same fonts, favicon, og tags, script `/src/landing/main.tsx`)
- Modify: `web/vite.config.ts` (`build.rollupOptions.input: { main: "index.html", app: "app/index.html" }`)
- Modify: `server/src/main.ts:58` (`fastifyStatic` options add `redirect: true`)
- Modify: `web/src/App.tsx` header: small "Home" link to `/` above the h1
- Create: `web/src/landing/main.tsx` (renders `<Landing />`; placeholder `Landing` returning the logo until Task 4)

**Interfaces:**
- Produces: `web/src/landing/main.tsx` entry; it forwards old dashboard links before `createRoot`.

- [ ] **Step 1: Old-link forward.** In `landing/main.tsx`: if `location.hash.startsWith("#/")` then `location.replace("/app/" + location.hash)` and stop.
- [ ] **Step 2: Build.** Run: `cd web && rtk npm run build` -> PASS; `ls dist/index.html dist/app/index.html` both exist; `grep -c uplot dist/index.html` -> 0.
- [ ] **Step 3: Server check.** Run server locally and: `curl -sI localhost:8080/app` -> 301/302 to `/app/`; `curl -s localhost:8080/app/` contains the dashboard script; `/api/market` still 200; `/#/coins` in the browser lands on `/app/#/coins`.
- [ ] **Step 4: Typecheck server.** Run: `cd server && rtk npm run typecheck` -> PASS.
- [ ] **Step 5: Commit.** `feat(web): landing at /, dashboard moves to /app/`

### Task 3: Live stats helpers (tested)

**Files:**
- Create: `web/src/landing/stats.ts`
- Create: `web/test/stats.test.ts`
- Modify: `web/package.json` scripts: `"test": "node --test \"test/**/*.test.ts\""`

**Interfaces:**
- Consumes: `Market`, `Deal`, `MERCHANT_NAME`, `merchantKey` from `web/src/api.ts`; `itemName` from `web/src/items.ts`.
- Produces:
  - `type MerchantStat = { key: "woodcutter" | "fishmonger" | "smith"; purse: number; cheapest: { item: string; ask: number } | null }`
  - `merchantStats(market: Market[]): MerchantStat[]` (always 3 rows, fixed order woodcutter, fishmonger, smith; purse from any row of that merchant; cheapest = lowest `ask` among rows with `stock > 0`)
  - `lastDealLine(deals: Deal[], now: number): string` (newest by `at`)
  - `ago(t: number, now: number): string` (logic of `App.tsx` `ago`, `now` injected)

- [ ] **Step 1: Write failing tests** in `web/test/stats.test.ts` (`node:test`, `node:assert/strict`):
  - `merchantStats` with rows for `woodcutter.haggletown-v2.testnet` (purse 500, asks 30 stock 0 and 40 stock 5) -> woodcutter `{ purse: 500, cheapest: { item: <id of the 40 row>, ask: 40 } }`; merchants with no rows -> `{ purse: 0, cheapest: null }`; keys in order `["woodcutter","fishmonger","smith"]`.
  - `lastDealLine([], now)` -> `"Market just opened"`.
  - `lastDealLine` with a deal at `now - 12_000` (merchant `fishmonger.<x>`, qty 3, unitPrice 14) and an older one -> starts with `"Fishmonger "`, contains `"3 <itemName(good)> @ 14 C"`, ends with `"12s ago"`; the verb comes from `side` and must mirror the wording the dashboard feed uses in `App.tsx` (read it first).
  - `ago(now - 90_000, now)` -> `"2m ago"`; `ago(now + 5_000, now)` -> `"0s ago"`.
- [ ] **Step 2: Run** `cd web && npm test` -> FAIL (module not found).
- [ ] **Step 3: Implement** `stats.ts` with the signatures above; `App.tsx` imports `ago` from it (pass `Date.now()`).
- [ ] **Step 4: Run** `cd web && npm test` -> PASS; `rtk npm run build` -> PASS.
- [ ] **Step 5: Commit.** `feat(web): landing live-stat helpers with tests`

### Task 4: Landing shell, motion, nav, hero, CTA card, footer

**Files:**
- Create: `web/src/landing/Landing.tsx`, `web/src/landing/landing.css`, `web/src/landing/useReveal.ts`, `web/src/landing/useLive.ts`
- Modify: `web/src/landing/main.tsx` (import `../theme.css`, `./landing.css`; add `document.documentElement.classList.add("js")`)

**Interfaces:**
- Consumes: Task 3 helpers; `api.market`, `api.feed`, `api.config`.
- Produces:
  - `useReveal(): (el: HTMLElement | null) => void` ref callback; adds class `in` once visible (threshold 0.15), then unobserves; without `IntersectionObserver` adds `in` immediately.
  - `useLive(): { market: Market[] | null; feed: Feed | null; config: Config | null }` polling every 10 s; on error keeps last good value (null if never loaded); clears interval on unmount.
  - CSS classes for Task 5: `.reveal` (+ `.in`), `.stagger > *` with `--i` index, `.section`, `.lcard` (lift on hover), `.btn-primary`, `.btn-ghost`.

- [ ] **Step 1: Motion CSS** per spec: inside `@media (prefers-reduced-motion: no-preference)`: `html.js .reveal{opacity:0;transform:translateY(16px)}`, `.reveal.in{opacity:1;transform:none;transition:opacity 500ms, transform 500ms cubic-bezier(.2,.7,.2,1); transition-delay: calc(var(--i,0)*80ms)}`; sign keyframes `drop` (700 ms, overshoot) then `sway` (+-1.5deg, 6 s, infinite, `transform-origin: 50% 0`).
- [ ] **Step 2: Nav:** sticky; coin mark (`/brand/coin.webp`, 32 px) + "Haggle Town"; anchors `#how`, `#merchants`, `#faq` (hidden below 768 px); button "Open the market" -> `/app/`. Gains `surface` fill + bottom border when `scrollY > 8` (passive scroll listener toggling a class). `html { scroll-behavior: smooth }` under no-preference.
- [ ] **Step 3: Hero:** min-height `min(92vh, 860px)`, background `/brand/hero.webp` cover, bottom gradient to `--bg`. Logo `<img alt="Haggle Town">` width `min(560px, 86vw)` with drop+sway, placed in the sky area. Below it a solid `surface` card: h1 "Haggle with AI merchants who keep their own purses.", one-line sub (prices follow supply and demand; every deal is signed by the merchant and settled on NEAR testnet), buttons "Open the market" (`/app/`) and "Play on Roblox" rendered only when `ROBLOX_URL` (constant in `Landing.tsx`, `""` for now) is non-empty. Live strip: `lastDealLine` + "3 merchants · 12 goods"; hidden while `feed` is null.
- [ ] **Step 4: CTA card + footer:** CTA card with coin image (hover: `rotateY(360deg)`, 900 ms), heading "The market is open", button to `/app/`. Footer: small logo, links Dashboard (`/app/`), GitHub (`https://github.com/woydarko/haggle-town`), Contract (`${config.explorerBase}/address/${config.contractId}`, only when config loaded), NEAR Hackathon (`https://nearhackathon.com/`); line "Testnet only. Coin is never exchangeable."
- [ ] **Step 5: Check** in browser preview at `/`: no console errors; with `/api` failing the page still renders and the strip is absent; with reduced motion emulated every section is visible.
- [ ] **Step 6: Commit.** `feat(web): landing hero, nav, CTA and footer with motion`

### Task 5: Content sections

**Files:**
- Create: `web/src/landing/Sprites.tsx`, `web/src/landing/Sections.tsx`
- Modify: `web/src/landing/Landing.tsx` (render sections between hero and CTA)

**Interfaces:**
- Consumes: `useReveal`, `useLive`, `merchantStats`, CSS classes from Task 4.
- Produces: `Sprite({ name, size }: { name: "wood" | "fish" | "ore" | "axe" | "pickaxe" | "rod"; size?: number })` (inline SVG, 16x16 grid, `shape-rendering="crispEdges"`, `aria-hidden`); components `HowItWorks`, `Merchants`, `WhyItMatters`, `BackerCoins`, `Faq`.

- [ ] **Step 1: Sprites.** Palette from the tool models: axe head `#D93A2B`, handle `#E8D29A`, grip `#3A3A3A`; pickaxe head `#5E7A8C`, handle `#7A4A1E`; rod shaft `#7A1F2B`, cork `#C9A46A`, reel `#222`; wood `--wood`; fish `--fish`; ore `--iron` with a light glint. Outline `--text`.
- [ ] **Step 2: HowItWorks (`id="how"`).** 4 steps in `.stagger`: "Gather" (axe, rod, pickaxe), "Haggle in chat", "The merchant signs the deal", "Prices move". One sentence each.
- [ ] **Step 3: Merchants (`id="merchants"`).** 3 `.lcard`s: portrait `/brand/<key>.webp` (alt "<Name>, merchant"), name in display font, persona line (woodcutter "Gruff, few words, proud of honest work.", fishmonger "Cheerful, chatty, knows every harbour rumour.", smith "Proud and terse. Respects good iron."), live `Purse <n> C` and `From <ask> C` (hidden when `market` null). Speech bubble above the portrait on hover/focus-within cycling that merchant's 3 example lines from `server/src/haggle/fallback.ts` every 2.5 s (copy into a `LINES` constant; no cycling under reduced motion). Card `tabIndex=0` so keyboard users get the bubble.
- [ ] **Step 4: WhyItMatters.** Two columns "For players" / "For game devs", 3 bullets each per spec outline.
- [ ] **Step 5: BackerCoins.** Three small cards `$WOOD`, `$FISH`, `$SMITH` with coin art, line "Supply follows the merchant's net worth, rebased once per market day, at most 5%.", link "See backer coins" -> `/app/#/coins`.
- [ ] **Step 6: Faq (`id="faq"`).** `<details>` x6 with the spec's questions; answers 1-3 sentences, facts from README (testnet only, Coin never exchangeable, no wallet or gas for players, LLM writes the line and proposes a number, contract enforces the price room, prices follow supply and demand per item, backer coins rebase by net worth). Smooth open via `grid-template-rows: 0fr -> 1fr` on `[open]`.
- [ ] **Step 7: Check** in preview: tab through the page (focus ring on every control, bubbles on focus), no console errors, `npm run build` PASS.
- [ ] **Step 8: Commit.** `feat(web): landing sections, merchant cards and pixel sprites`

### Task 6: Docs, full verification, deploy

**Files:**
- Modify: `README.md:8` (dashboard link -> `/app/`, add root as landing), `docs/hackathon/SUBMISSION.md` (same), `docs/hackathon/STATE.md` (freeze exception note), `docs/TESTING.md` (web test command in Verified commands + Results line)

- [ ] **Step 1: Run all checks.** `cd web && npm test && rtk npm run build`; `cd server && NODE_ENV=test rtk npm test && rtk npm run typecheck`. Expected: all PASS (server 130 as before).
- [ ] **Step 2: Responsive pass** in preview at 390, 768, 1280: `document.documentElement.scrollWidth <= innerWidth` at each; screenshot hero and merchants at 390 and 1280.
- [ ] **Step 3: Update docs** per Files list; grep `railway.app` in README/SUBMISSION so every dashboard link ends in `/app/`.
- [ ] **Step 4: Commit.** `docs: landing at root, dashboard at /app/`
- [ ] **Step 5: Deploy (needs user OK: Railway production).** Push and redeploy as in the previous session; then `curl -sI <prod>/` 200, `<prod>/app` -> `/app/`, `<prod>/app/` 200, `<prod>/api/market` 200.
