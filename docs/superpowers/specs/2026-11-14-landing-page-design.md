# Landing page design

Date: 2026-11-14. Status: draft, awaiting approval.

## Intent
The web today opens straight into the dashboard. Judges and players landing on the root URL get numbers before they know what the game is. A landing page in the game's own look (parchment market, wooden sign, low-poly merchants) tells the story in one scroll, then sends people to the dashboard, which proves it is live and on chain.

## Goals
- Branded hero: the user's wooden-sign logo over a screenshot of the village, smooth entrance motion.
- Each merchant has a portrait that matches its in-game model.
- Small pixel icons from the game's goods as accents.
- Sections: hero, how it works, merchants, why it matters, backer coins teaser, FAQ, CTA card, footer.
- Every CTA leads to the dashboard. "Play on Roblox" only when the public link exists.
- Feels interactive and smooth: scroll reveals, hover states, live numbers from the API.

## Non-goals
- No change to dashboard features or data.
- No CMS, no i18n, no dark mode (DESIGN_SYSTEM decision: single light theme).
- No new backend endpoints.

## Anti-goals (failure even if it works)
- Slow first paint (heavy PNGs, animation library bloat).
- Motion that ignores `prefers-reduced-motion` or janks on a phone.
- Breaking the dashboard or the existing shared link for judges.

## Constraints
- Submit target 2026-11-15 06:29 +0700; feature freeze in STATE.md, this is a user-approved exception.
- Stack: Vite 8 + React 19 + TS, no router. Served by Fastify `@fastify/static` from `web/dist` in the same Railway service (Dockerfile builds web).
- Tokens from `web/src/theme.css` only. Fonts: Fraunces, IBM Plex Sans/Mono (already loaded).
- Accessibility per DESIGN_SYSTEM: keyboard, focus ring, semantic headings, contrast >= 4.5:1.

## Approaches
1. Landing in the same SPA via hash (`#/` landing, `#/market` dashboard). Smallest diff; dashboard URLs keep `#`.
2. **Separate page (picked by user).** Vite multi-page: `index.html` = landing at `/`, `app/index.html` = dashboard at `/app/`. Clean URLs, landing never loads uPlot or polls the chart APIs. Costs a Vite config change and a moved entry.
3. Option 1 plus a motion library. Rejected: +30 KB for effects CSS can do.

## Decided
- **Routing:** `/` landing, `/app/` dashboard (hash tabs `#/players`, `#/coins` stay inside it). `/app` without slash redirects to `/app/` (`@fastify/static` `redirect: true`).
- **Animation:** CSS keyframes + transitions, one `IntersectionObserver` hook for reveal-on-scroll. No new dependency.
- **Logo and coin:** user files `Haggle Town Logo.png` (1536x1024) and `Haggle Coin.png` (2048x2048), both RGBA, converted to WebP (logo 1200 w, coin 256 w) plus a 64 px PNG favicon. Shared by both pages.
- **Hero background:** screenshot of the village taken by the user in a Studio playtest (UI hidden). WebP, ~1920 w, < 300 KB.
- **Merchant portraits:** head-and-shoulders captures of the real `woodcutter`, `fishmonger`, `smith` models from ServerStorage, shot in Studio Edit mode on a parchment backdrop, cropped square, WebP.
- **Pixel accents:** hand-made SVG sprites (wood, fish, ore, axe, pickaxe, rod) in the game's palette, colors taken from the tool models (axe red head, pickaxe slate head, rod maroon shaft).

## Page outline
1. **Nav** (sticky, gains parchment fill + border after 8 px scroll): coin mark + "Haggle Town", anchors (How it works, Merchants, FAQ), button "Open the market" -> `/app/`.
2. **Hero:** village screenshot full-bleed with a parchment fade at the bottom; logo sign drops in and swings once on its chains, then idles with a slow sway. Tagline: "Haggle with AI merchants who keep their own purses." Sub: one line on prices moving by supply and demand, deals settled on NEAR testnet. CTAs: primary "Open the market" (`/app/`), secondary "Play on Roblox" (hidden when no link). Live strip below: deals settled, last deal ("Fishmonger sold 3 Trout @ 14 C, 12s ago"), from `/api/feed` and `/api/market`, refreshed every 10 s; hidden quietly on API error.
3. **How it works:** 4 steps with pixel icons: Gather (axe/rod/pickaxe) -> Haggle in chat -> Merchant signs the deal -> Prices move. Steps reveal in sequence.
4. **Merchants:** 3 cards, portrait + name + persona line + live purse and cheapest ask from `/api/market`. Hover: card lifts, a speech bubble cycles that merchant's sample lines (copied from `server/src/haggle/fallback.ts` examples into a small web constant).
5. **Why it matters:** two columns. Players: no wallets, no gas, prices react to you. Devs: no economy patches, AI only proposes, the contract enforces the price room.
6. **Backer coins teaser:** one card per merchant coin with the coin art, one line on rebase by net worth, link to `/app/#/coins`.
7. **FAQ** (`<details>` accordion, smooth height): Is this real money? Do players need a wallet? What does the AI actually decide? How do prices move? What are backer coins? Can I play now?
8. **CTA card:** big parchment card with the coin, "The market is open", button to `/app/`.
9. **Footer:** small logo, links (Dashboard, GitHub repo, contract on NEAR explorer via `/api/config`, NEAR Hackathon), "Testnet only. Coin is never exchangeable."

## Motion spec
- Reveal: opacity 0 -> 1, translateY 16 px -> 0, 500 ms `cubic-bezier(.2,.7,.2,1)`, stagger 80 ms within a group.
- Sign: drop-in 700 ms with overshoot, then sway +-1.5 deg, 6 s loop.
- Hover: cards translateY -4 px, 200 ms; buttons darken 8% (existing rule).
- `prefers-reduced-motion: reduce`: everything shows at final state, no loops (global rule already in theme.css).

## Files touched
- `web/vite.config.ts` (multi-page input), `web/index.html` (becomes landing), new `web/app/index.html` (dashboard entry, same head as today), new `web/src/landing/*` (Landing.tsx, sprites, styles); `web/src/main.tsx` stays the dashboard entry.
- `web/public/brand/*` (logo, coin, favicon, hero, portraits).
- `server/src/main.ts`: static `redirect: true` for `/app`.
- `README.md` and `docs/hackathon/SUBMISSION.md`: dashboard link -> `/app/`, root link described as landing.
- `docs/hackathon/STATE.md`: note the freeze exception.

## Left to the builder
- Exact copy wording within the outline (plain, no hype words, prices with "C").
- Breakpoint details beyond 390 / 768 / 1280.
- Sprite pixel layouts.

## Open (user)
- Village screenshot file (blocks the hero image; fallback: parchment hero with the sign only).
- Public Roblox link (blocks the "Play on Roblox" button; hidden until then).
