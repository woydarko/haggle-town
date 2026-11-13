# Haggle Town v4 Village Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, the user's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the map to a quarter of its area, rebuild the town as a walkable village with a guided first session, fit fonts to the market theme, make haggling varied, and add an in-world Market Ledger fed by the web API.

**Architecture:** Pure Luau modules (spec-tested with Lute) hold every decision that can be checked without Roblox: map layout (`Regions`, `Terrain`), village plots (`Village`), quest steps (`Quest`), haggle suggestions (`Suggest`), ledger rows (`LedgerView`). Server/client modules only place parts and draw UI from them. Backend changes stay in `server/src/haggle/fallback.ts`, `engine.ts`, `llm/prompt.ts`, `routes/api.ts` with node tests.

**Tech Stack:** Luau + Rojo 7.7.1, Lute specs, Roblox Studio MCP for playtests, Node 24 + node:test backend, ForgeGUI MCP for icons.

**Spec:** `docs/superpowers/specs/2026-11-13-haggle-town-v4-village-design.md`

## Global Constraints
- Work must land by 2026-11-14 12:00 +0700 (deadline 2026-11-14 23:59 UTC, >= 8 h kept for deploy + publish + video + submission).
- No chain words in Roblox user-facing text: crypto, blockchain, NFT, token, wallet, NEAR, gas, transaction. Policy grep after every task.
- `economy/src/pricing.rs` untouched; no price or odds changes.
- Server authority unchanged: the client never names items, tiers or quantities.
- Text contrast >= 4.5:1, touch targets >= 44 px, works at 1280x720 and on phone.
- antislop mode 1: no em dash in any text, no buzzwords, every visual choice has a written reason, Delivery Gate report at the end.
- ForgeGUI images publish only to the user's account (@lyrzabil) as private Image assets.
- Dials: ENERGY 2 / RHYTHM 2 / MOTION 1; stamp red `#B4471F` only on the main action per screen.

## Review Focus
1. Backend offline while the ledger polls: board keeps last data with a "stale" note, never blank or crashing (LedgerView spec: `state="stale"`).
2. Player skips the tutorial order (sells before picking a class, already has a class on join): tracker shows the first unmet step and never blocks (Quest spec).
3. A merchant with only one line left after filtering recent ones: picker still returns a line (fallback test with history longer than the bank).
4. Shrunk map: every gather spot still reachable on foot and caverns still walkable (Terrain spec walk + tunnel checks rerun with new values).
5. Phone width 375 px: quest tracker, chips and HUD do not overlap (Studio check at mobile preset in Task 9).

---

### Task 1: Theme fonts

**Files:**
- Modify: `roblox/src/shared/Theme.luau` (display, body, numeric tokens)
- Modify: `docs/DESIGN_SYSTEM.md` (font rows + one-line reasons)

- [ ] Studio MCP: in Edit run `Font.fromName("Fondamento")` and `Font.fromName("Merriweather")` on a TextLabel `FontFace` and confirm `TextBounds` > 0 after `ContentProvider:PreloadAsync`. Expected: both resolve.
- [ ] Theme gains `displayFace = Font.fromName("Fondamento")`, `bodyFace = Font.fromName("Merriweather")`, `numericFace = Font.fromName("Merriweather", Enum.FontWeight.Bold)`; `Ui.text`, `Ui.button`, `Ui.tierBadge`, Boards and Loading switch from `Font = Theme.x` to `FontFace = Theme.xFace` (grep `Theme.display`, `Theme.body`, `Theme.numeric` across `roblox/src`; every hit migrates).
- [ ] `check-syntax.sh`, all Luau specs pass; policy grep clean.
- [ ] Commit `feat(roblox): market-sign fonts (Fondamento, Merriweather)`.

### Task 2: Quarter-area map

**Files:**
- Modify: `roblox/src/shared/Regions.luau` (all layout constants x0.5 except `VILLAGE`)
- Modify: `roblox/src/server/Terrain.luau` (TUNNEL, cavern radii, mountain/ring heights, ramp widths, SPOTS)
- Modify: `roblox/src/server/Nodes.luau` (scatter centres/radii, counts: trees 80, rocks 32, spots 10)
- Test: `roblox/tests/Regions.spec.luau`, `roblox/tests/Terrain.spec.luau`

**Interfaces:** Produces the same `Regions`/`Terrain.SPOTS` names; values change. `Regions.VILLAGE = { x = 0, z = -20, r = 120 }` (flat), village blend 100.

- [ ] Specs first: change their fixed points to the new layout (CENTER `(0,150)`, LAKE `(0,300) r 130`, MINE `(325,150) r 150`, GROVE `(-440,150) r 80`, RING_IN 480, RING_OUT 560, SEA_D 340; ring check at r 540 height > 100; walk targets from the new SPOTS). Run: `lute run roblox/tests/Terrain.spec.luau`. Expected: FAIL on the old constants.
- [ ] Update constants; mountain peak 100, ring 180, lake ramp 70, sea ramp 80, mine flatten 220..300; TUNNEL scaled x0.5 around the mine with chambers r 12/13/13 and legs < 35 deg.
- [ ] Both specs pass; `rojo build` ok.
- [ ] Studio MCP: build time, raycast spots vs pure heights (|dy| <= 0.5), node counts.
- [ ] Commit `feat(roblox): quarter-area map`.

### Task 3: Village layout

**Files:**
- Create: `roblox/src/shared/Village.luau` (pure layout data)
- Modify: `roblox/src/server/World.luau` (town built from `Village`), `roblox/src/server/Lobby.luau` (guild hall yard replaces the lobby: mentors + how-to + spawn), `roblox/src/server/Main.server.luau` (merchant/mentor references unchanged by name)
- Test: `roblox/tests/Village.spec.luau`

**Interfaces:** Produces `Village.SQUARE: {x,z,w,d}`, `Village.STALLS: {[merchant]: {x,z,yaw}}`, `Village.WELL`, `Village.LEDGER: {x,z,yaw}`, `Village.GUILD: {x,z}`, `Village.SPAWN`, `Village.ROADS: { {name, from: {x,z}, to: {x,z}} }`, `Village.PLOTS: { {x,z,yaw,w,d} }`, `Village.GATES: { {name, x, z, yaw, dest, distance} }`.

- [ ] Failing spec: plots never overlap each other, a road strip (6 wide) or the square; every plot, stall, well, ledger, guild and spawn lies inside `Regions.VILLAGE.r`; every gate sits on its road end; each plot faces its nearest road (yaw within 15 deg of facing it); 4 gates named "Woods", "Lake", "Mine", "Coast" with distance to `Terrain.SPOTS` targets.
- [ ] Implement `Village.luau`; houses from `Assets/Village` on plots (`World.kit` place), cobble road parts, lamps every 24 studs, signposts (post + 2 boards with text) at gates.
- [ ] Spec passes; Studio MCP: no part intersects another building (GetPartsInPart on houses), spawn to square walk < 12 s.
- [ ] Commit `feat(roblox): village layout with square, guild hall, streets, gates`.

### Task 4: Varied merchant lines (backend)

**Files:**
- Modify: `server/src/haggle/fallback.ts` (line banks + `pickLine`), `server/src/haggle/engine.ts` (recent lines, `wrapUp`), `server/src/llm/prompt.ts` (recent lines + no-repeat rule)
- Test: `server/test/fallback.test.ts` (create), `server/test/engine.test.ts`, `server/test/llm.test.ts`

**Interfaces:** `pickLine(bank: string[], recent: string[], rand?: () => number): string`; Persona fields `hello/accept/annoyed/refuse/broke/wrapUp: string[]`, `counter: ((p: number) => string)[]`; `HaggleContext.recentLines: string[]`.

- [ ] Failing tests: each persona bank has >= 6 entries per kind; `pickLine` never returns one of the last 3; with recent covering the whole bank it still returns a line; every counter line contains the price digits; no bank line contains a policy word; engine round-limit reply is one of `wrapUp` and differs across 3 consecutive calls; prompt contains the last 3 merchant lines and the words "never reuse".
- [ ] Implement banks in each persona's voice (fallback.ts personas), `pickLine`, engine `recentLines(playerId, merchant, 3)` across sessions (chat_turn join haggle_session), prompt lines.
- [ ] `NODE_ENV=test npm test` and `npm run typecheck` pass.
- [ ] Commit `feat(haggle): varied merchant lines without repeats`.

### Task 5: Player suggestion chips

**Files:**
- Create: `roblox/src/shared/Suggest.luau` (pure)
- Modify: `roblox/src/client/ui/HagglePanel.luau`
- Test: `roblox/tests/Suggest.spec.luau`

**Interfaces:** `Suggest.lines(ctx: { side: "buy"|"sell", unitPrice: number, itemName: string, qty: number, round: number }, recent: { string }): { string }` returns exactly 3: meet-in-middle (contains a price strictly between the counter and 85% / 115% of it), accept (contains the counter price), push back.

- [ ] Failing spec: 3 lines, kinds in order, prices as stated, no line repeats one in `recent`, 6 rounds produce >= 10 distinct lines, no policy words, no em dash.
- [ ] Implement; panel shows the 3 chips under the input after each counter (before the first counter: the quick-sell chips stay), click fills the input.
- [ ] Spec passes; Studio MCP: chips render and fill the input.
- [ ] Commit `feat(roblox): haggle sentence suggestions`.

### Task 6: Market Ledger

**Files:**
- Modify: `server/src/routes/api.ts` (`/api/config` adds `dayLengthMs`), test `server/test/api-routes.test.ts`
- Create: `roblox/src/shared/LedgerView.luau` (pure), `roblox/src/server/Ledger.luau` (poll + render)
- Modify: `roblox/src/server/Main.server.luau` (replace PriceBoard/LeaderBoard polling), `roblox/src/server/World.luau` (ledger board at `Village.LEDGER`), remove `Boards.renderPrices/renderLeaders` callers
- Test: `roblox/tests/LedgerView.spec.luau`

**Interfaces:** `LedgerView.build(input: { market: {any}?, feed: {any}?, leaders: {any}?, config: {any}?, now: number, lastOk: number?, prev: { [string]: number }? }) -> { state: "loading"|"ok"|"stale", header: string, merchants: { {name, purse, items: { {name, tier, buy, sell, trend: "up"|"down"|"flat", stockPct} } } }, deals: { string }, leaders: { {name, worth} }, note: string? }`.

- [ ] Failing tests: config returns `dayLengthMs`; LedgerView: nil market and no lastOk -> loading; nil market with lastOk -> stale + note naming the age; 12 market rows -> 3 merchants x 4 items in item order; trend from `prev`; deal line "Darko sold 1 Pine to the Woodcutter for 12 C, 2 min ago"; empty feed -> "No deals yet today. Be the first."; leaders top 5; header "Market day 251, restock in 3:12".
- [ ] Implement; `Ledger.luau` polls `/api/market`, `/api/feed`, `/api/leaderboard`, `/api/config` every 10 s via `Backend.get`, keeps `prev` asks, renders a 3-column SurfaceGui with the stamped-price motif.
- [ ] Specs + server tests pass; Studio MCP: board shows live data, then stop backend -> stale note.
- [ ] Commit `feat: in-world Market Ledger`.

### Task 7: Guided flow and copy

**Files:**
- Create: `roblox/src/shared/Quest.luau` (pure), `roblox/src/client/ui/QuestTracker.luau`
- Modify: `roblox/src/client/Main.client.luau`, `roblox/src/server/Lobby.luau` (how-to board copy), `roblox/src/shared/Tools.luau`, `roblox/src/server/Main.server.luau` (toasts), `roblox/src/client/minigames/*.luau` (hints)
- Test: `roblox/tests/Quest.spec.luau`

**Interfaces:** `Quest.step(s: { class: string?, bagCount: number, deals: number, ledgerSeen: boolean }): { index: number, title: string, target: "guild"|"gather"|"market"|"ledger"|nil }`.

- [ ] Failing spec: no class -> 1 guild; class + empty bag + 0 deals -> 2 gather; bag > 0 + 0 deals -> 3 market; deals > 0 and not seen -> 4 ledger; all done -> index 5, target nil; already traded but no class -> 1 (first unmet step, never blocks).
- [ ] Implement tracker (top-left under HUD, step title in display face, "?" to reopen), world marker BillboardGui (arrow + distance) on the target (gather target by class: logger -> woods gate, miner -> mine gate, fisher -> lake gate; no class -> guild).
- [ ] Rewrite every player-facing string with antislop-copywriting (boards, toasts, hints, tool tips, prompts): specific verbs, no buzzwords, no em dash.
- [ ] Spec passes; policy + em dash grep clean; Studio MCP: tracker advances through all 4 steps.
- [ ] Commit `feat(roblox): guided first session and rewritten copy`.

### Task 8: ForgeGUI icons

**Files:**
- Create: `roblox/src/shared/Icons.luau`
- Modify: `roblox/src/client/ui/Ui.luau` (`Ui.icon` uses an ImageLabel when an id exists), HUD bag, CatchCard, HagglePanel chips, Ledger rows
- Credits: `roblox/ASSETS.md`

- [ ] ForgeGUI `style_create` "Haggle Town market" (parchment, ink outline, warm flat colours, readable at 32 px).
- [ ] `generation_gui` type `gui_icon` for 12 items + coin with the style; review each, regenerate a bad one once.
- [ ] Publish each as Image to connection @lyrzabil; ids into `Icons.luau` (`[itemId] = "rbxassetid://..."`, `coin`).
- [ ] Studio MCP: every id preloads `Success`; tier tile fallback still used when an id is missing.
- [ ] Commit `feat(roblox): item and coin icons`.

### Task 9: Verify and deliver

- [ ] Studio MCP Play: golden path on the new map (spawn -> guild -> gather -> sell -> ledger), node counts, part count, build time, console clean; mobile preset 375x812 screenshot check for overlap.
- [ ] antislop Delivery Gate report (Blocks 1-4) written to `docs/TESTING.md` with evidence per item.
- [ ] `docs/TESTING.md`, `docs/hackathon/STATE.md` checkpoint; ledger lines.
- [ ] Commit.

## Cut order (spec)
1. ForgeGUI panel frame. 2. Quest marker beam. 3. Ledger trend arrows. 4. Fewer houses.
