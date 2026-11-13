# Haggle Town v4: compact village, guided flow, living dialogue, in-world ledger

Status: proposal for approval (2026-11-13). Builds on v3 (`docs/superpowers/plans/2026-11-11-haggle-town-v3-world.md`, Tasks 1-9 and 12 done).

## Intent (user request, 2026-11-13, translated)

> Remodel the map: it is too big, make it 1/4 of the current size. Lay it out like a real village. Fix the flow, the text and the tutorial. Fonts must fit the theme. Haggling must read like people actually talking, with many sentence options, not the same lines again and again. Add an info dashboard inside the map that fetches straight from our web, simplified but still detailed and clear. Take UI/UX seriously: use ForgeGUI properly and the antislop skill.

Decisions from the conversation: "1/4" means a quarter of the area (half the width); antislop applies during the work (mode 1).

Why: the game is demoed to hackathon judges in a short video and a short play session. A judge must understand the loop in under a minute, see the economy move, and feel that the merchants are characters.

## Goals
1. Playable area about 1000 studs across (from about 2000), all regions kept: village, lake, woods, pine forest, ancient grove, mine with 3 caverns, coast. Sprint edge to edge in about 40 s.
2. A village that reads as a real place: a square in the middle (market stalls, well, the Market Ledger), streets with houses on both sides, a guild hall by the spawn, four gates with signposts pointing to the forest, lake, mine and coast.
3. A guided first session: a 4-step quest tracker with a world marker to the next target; every board, hint and toast rewritten.
4. Fonts that match the "parchment, ink, stamped prices" direction in `docs/DESIGN_SYSTEM.md`.
5. Haggling that varies: many lines per situation per merchant, no immediate repeats, LLM told not to repeat itself, and context-aware sentence suggestions for the player.
6. A Market Ledger board in the square, fed from the same backend as the web dashboard: prices with trend, merchant stock and purse, recent deals, top traders, market day clock.
7. UI assets from ForgeGUI in one style: 12 item icons + coin, used in HUD, bag, catch card, haggle chips and the ledger.

## Non-goals
- No new economy rules, prices or odds (`economy/src/pricing.rs` untouched).
- No new gather mechanics; v3 chop/mine/fish stay as they are.
- No dark mode (single light theme is the logged decision in DESIGN_SYSTEM).
- Web dashboard itself is not redesigned.

## Anti-goals (would make this a failure even if it works)
- Merchant lines that still loop on one sentence.
- A ledger that shows invented or stale numbers without saying so.
- A tutorial that blocks play (it guides, it never locks the player).
- Any chain word in Roblox text (crypto, blockchain, NFT, token, wallet, NEAR, gas, transaction).

## Constraints
- Deadline 2026-11-14 23:59 UTC; deploy + publish + video + submission need at least 8 h, so this work must land by about 2026-11-14 12:00 +0700.
- Server authority unchanged; the client never names items, tiers or quantities.
- Text contrast >= 4.5:1, touch targets >= 44 px, works at 1280x720 and on phone.
- ForgeGUI images publish to the user's own Roblox account (@lyrzabil) as private Image assets; the user asked for ForgeGUI, approving this doc approves those uploads.

## Approaches considered

**Map size**
- A (picked): halve every layout constant around the same centre and keep the generator. Same tests, re-tuned; regions, caverns and coast all stay.
- B: crop the current map to its central 1000 studs. Rejected: loses the mine and coast or needs them moved anyway.
- C: hand-built map. Rejected: no time, loses git as source of truth.

**Village**
- A (picked): rebuild `World.luau` town layout as data (streets, plots, gates) placed around the square; houses from the curated assets on plots facing the street; lobby merged into the village (spawn by the guild hall at the south gate).
- B: keep the lobby as a separate area. Rejected: it is what makes the flow feel disjointed.

**Dialogue**
- A (picked): bigger persona line banks + no-repeat picker in `fallback.ts`, LLM prompt gets the merchant's last lines and a "never reuse a sentence" rule, player suggestion chips built from the live counter.
- B: LLM only. Rejected: fallback still fires on timeouts and rule paths (round limit, refuse, broke), which is exactly where the repetition comes from today (8 of the last 12 lines).

**Ledger data**
- A (picked): Roblox server polls the existing public `/api/market`, `/api/feed`, `/api/leaderboard` every 10 s through `Backend.luau` and renders one SurfaceGui board.
- B: new aggregated `/rbx/ledger` route. Rejected for now: more backend surface; A uses what the web already serves.

## Design Read (antislop)
Reading this as: an in-game market town UI for Roblox players and hackathon judges, in a warm hand-made market style (parchment, ink, stamped prices), dial ENERGY 2 / RHYTHM 2 / MOTION 1.
- Focal point per screen: the haggle counter price in the haggle panel; the next quest step in the HUD; the price table on the ledger.
- Accent: stamp red (`#B4471F`) only on the one main action per screen (Accept, quest marker).
- Identity motif: the "stamped price" (bold number in a rounded rectangle with a thin ink border), reused on ledger rows, haggle counter and catch card.
- Motion: only state changes (catch card slide, price change flash on the ledger); no idle animation.

## Fonts (one-line reasons, R-06 / R-31)
- Display: `Fondamento` (Roblox built-in). Hand-lettered market-sign voice for titles, merchant names, quest steps; readable at 20 px and up.
- Body: `Merriweather` (Roblox built-in). Screen-reading serif that matches the web's Fraunces + parchment look and stays legible at 18 px for chat lines.
- Numbers: `Merriweather` bold. Replaces RobotoMono: a mono face reads as "terminal", not market board.
- Verified in Studio before switching: both families resolve with `Font.fromName`; fallback to BuilderSans if not.

## Layout (village, about 240 x 240 studs, centre = origin)
```
                N (lake road, pier 150 north)
                 |
   [house][house]|[house][house]
 W gate ----- [ SQUARE ] ----- E gate (mine road)
 (woods)   stalls . well . LEDGER
   [house][house]|[house][house]
                 |
         [GUILD HALL] [spawn]
                 S gate  ---- SE road (coast)
```
- Square 50 x 40 with the 3 merchant stalls on its west, north and east edges, the well in the middle, the Ledger on the south edge facing the spawn road.
- Guild hall south of the square: the 3 mentors and the How-to board inside its yard; spawn pad in front of it.
- Streets: cobble paths along the 4 roads to 120 studs out, lamps every 24 studs, houses (5 assets, rotated to face the street) on plots along N-S and E-W streets.
- Signposts at each gate with destination name and distance in studs.

## Flow and tutorial
Quest tracker, top-left under the HUD, 4 steps, derived on the client from state the client already has (class, bag, deals):
1. "Pick a trade at the guild hall" (marker on the mentor yard)
2. "Gather something" (marker on the nearest forest edge / mine mouth / lake pier for the chosen trade)
3. "Sell it at the market" (marker on the matching stall)
4. "Watch the ledger: your deal moved the price" (marker on the ledger), then the tracker folds into a small "?" button.
A marker = a BillboardGui arrow + distance over the target, plus a Beam from the player only while the step is active. Copy rewritten with antislop-copywriting rules (specific verbs, no buzzwords, no em dash).

## Dialogue
- `fallback.ts`: every persona gets 6+ lines each for hello, counter, accept, annoyed, refuse, broke, and a new `wrapUp` (replaces "Let's settle or part ways."). Picker avoids the merchant's last 3 lines for that player.
- LLM prompt: include the last 3 merchant lines, instruction to vary sentence shape and never reuse a sentence, keep persona voice.
- Haggle panel: 3 suggestion chips under the input built from the live counter (meet in the middle, accept, push back), each picked from a small bank so they change every round. Clicking fills the input; the player can edit before sending.
- Tests: fallback picker never repeats within 3 picks, every line bank passes the policy word check, counter lines always contain the price.

## Market Ledger (in-world dashboard)
One large board on the square's south edge, three columns:
- Prices: per merchant (Woodcutter, Fishmonger, Smith), 4 items each with buy / sell price in coin, up/down arrow vs the previous day, stock bar, merchant purse.
- Recent deals: last 6 settled deals: "Nabil sold 3 Pine to Woodcutter for 42 C, 1 min ago".
- Top traders: top 5 by net worth.
- Header: market day number and time to the next restock.
States: loading "Opening the ledger...", error "Ledger can't reach the market. Showing prices from <time>." (stale tag), empty feed "No deals yet today. Be the first."
Replaces the separate PriceBoard and LeaderBoard in the town and lobby.

## ForgeGUI
- One style identity ("Haggle Town market": parchment, ink outline, warm stamped colours, flat shading).
- 13 icons (`gui_icon`): 12 items + coin. Published as Image to the user's account; ids in `roblox/src/shared/Icons.luau`. `Ui.icon` uses them, falls back to the tier tile.
- Optional if credits and time allow: one parchment panel frame for the ledger and haggle panel.

## Cut order (if behind at 2026-11-14 06:00 +0700)
1. ForgeGUI panel frame (keep icons).
2. Player-side beam for quest markers (keep billboard markers).
3. Ledger trend arrows (keep prices, deals, traders).
4. Fewer houses (keep streets, square, gates, signposts).

Never cut: 1/4 map, square + gates + signposts, quest tracker, rewritten copy, fonts, dialogue variety, ledger with states.

## Left to the builder
Exact house plots, signpost wording, line banks (persona voice already defined in `fallback.ts`), ForgeGUI prompts within the style.
