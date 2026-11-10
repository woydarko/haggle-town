# Haggle Town v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tiered items, classes, skill minigames, a lobby and a mountain-lake map on top of the live v1 game, still settled on NEAR testnet.

**Architecture:** Same layers as v1. `economy/src/pricing.rs` gains items, tiers and drop odds (TS port tested against vectors); contract v2 stores per-item stock and player class and is deployed to a fresh testnet account; the backend owns gather sessions and rolls loot; Roblox runs minigames client-side and reports a quality score.

**Tech Stack:** unchanged (Rust near-sdk 5.30.1, Node 24 + Fastify + near-api-js 7.4, React/Vite, Luau + Rojo 7.7.1, Lute for Luau tests).

**Spec:** docs/superpowers/specs/2026-11-11-haggle-town-v2-design.md (v1: docs/superpowers/specs/2026-11-10-haggle-town-design.md)

## Global Constraints

- Items (token ids): `fish_sardine fish_trout fish_salmon fish_koi`, `wood_pine wood_oak wood_maple wood_redwood`, `ore_copper ore_iron ore_gold ore_crystal`, plus `coin`. Display names: Sardine, Trout, Salmon, Golden Koi, Pine, Oak, Maple, Ancient Redwood, Copper, Iron, Gold, Crystal.
- Category base: fish 20, wood 15, ore 30. Tier multiplier: common 1, rare 3, epic 8, legendary 30. Item target stock: common 120, rare 40, epic 12, legendary 3.
- Drop odds in basis points [common, rare, epic, legendary]: base [7000, 2200, 700, 100]; specialist [5500, 3000, 1200, 300]. Quality q (0..100) moves `q*20` bp from common: 60% to rare, 30% to epic, 10% to legendary.
- Classes: `fisher` (fish), `logger` (wood), `miner` (ore). Specialist: minigame zones +30%, odds above, 15% double drop, sell ceiling +10% on own category (enforced on chain). Switching class after the first pick costs 100 C (burned on chain) with a 5 min cooldown (backend).
- Gather nodes: `fish`, `wood`, `ore_mouth`, `ore_deep`. Min duration: fish 6000 ms, wood 3000 ms, ore 3500 ms. Session TTL 60 s, one open session per player. `ore_deep` adds 20 to q (cap 100); `ore_mouth` caps the tier at epic.
- Pricing rules unchanged in shape (ask clamp, bid 80%, haggle room, restock 40% of gap, burn 10%) but applied per item with that item's base and target.
- No chain words in Roblox user-facing strings. Testnet only; testnet deploys pre-approved. Roblox publish postponed by the user.
- Every task: TDD where code has logic; commit with the `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` trailer; push to `origin feat/haggle-town`.

## Review Focus

1. **Finish called for a session that is not the player's, already finished, or expired** -> 404/409, nothing minted. Test in Task 4.
2. **Quality outside 0..1 or NaN from a modified client** -> clamped, never more than one tier step of luck. Test in Task 1 (odds) and Task 4 (route).
3. **Selling an item the merchant does not trade (e.g. ore to the Fishmonger) or an unknown item id** -> 400 in backend, `BadGood` on chain. Tests in Tasks 2 and 5.
4. **Class switch inside cooldown or without 100 C** -> refused with a clear message, class unchanged. Tests in Tasks 2 and 4.
5. **Player with v1 data after the v2 deploy** -> treated as a new player on the v2 contract (fresh 1000 C), no crash. Test in Task 4 (join against empty contract view).

---

### Task 1: economy v2 - items, tiers, odds (core, ~2 h)

**Files:** Modify `economy/src/pricing.rs`, `economy/tests/vectors.rs`; regenerate `economy/test-vectors.json`.

**Interfaces (produces):**
- `pub enum Category { Fish, Wood, Ore }`, `pub enum Tier { Common, Rare, Epic, Legendary }`, `pub struct Item { pub category: Category, pub tier: Tier }`
- `Item::from_id(&str) -> Option<Item>`, `Item::id(&self) -> &'static str`, `Item::base(&self) -> u128`, `Item::target(&self) -> u32`, `Item::all() -> [Item; 12]`, `Category::from_str/as_str`, `Category::of_class(&str) -> Option<Category>` (fisher/logger/miner)
- `ask(item, stock)`, `bid(item, stock)`, `buy_room(item, stock)`, `sell_room(item, stock, purse, qty, specialist: bool)` (ceiling x110/100 when specialist, still capped by purse/qty), `restock(stock, target)`, `burn(stock)` (unchanged)
- `pub fn roll_tier(roll_bp: u32, specialist: bool, quality: u32) -> Tier` (roll 0..9999, quality clamped to 100)

- [ ] **Step 1: failing tests** (replace the Good-based tests):

```rust
#[test] fn item_ids_roundtrip() { for it in Item::all() { assert_eq!(Item::from_id(it.id()), Some(it)); } assert_eq!(Item::from_id("wood"), None); }
#[test] fn base_is_category_times_tier() { assert_eq!(Item::from_id("fish_koi").unwrap().base(), 600); assert_eq!(Item::from_id("ore_iron").unwrap().base(), 90); }
#[test] fn targets_by_tier() { assert_eq!(Item::from_id("wood_pine").unwrap().target(), 120); assert_eq!(Item::from_id("wood_redwood").unwrap().target(), 3); }
#[test] fn ask_at_target_is_base() { let k = Item::from_id("fish_koi").unwrap(); assert_eq!(ask(k, 3), 600); }
#[test] fn specialist_sell_bonus() { let t = Item::from_id("fish_trout").unwrap(); let (_, c) = sell_room(t, 40, 100_000, 1, false).unwrap(); let (_, cs) = sell_room(t, 40, 100_000, 1, true).unwrap(); assert_eq!(cs, c * 110 / 100); }
#[test] fn roll_base_edges() { assert_eq!(roll_tier(0, false, 0), Tier::Common); assert_eq!(roll_tier(6999, false, 0), Tier::Common); assert_eq!(roll_tier(7000, false, 0), Tier::Rare); assert_eq!(roll_tier(9900, false, 0), Tier::Legendary); }
#[test] fn roll_specialist_and_quality() { assert_eq!(roll_tier(5500, true, 0), Tier::Rare); assert_eq!(roll_tier(5000, false, 100), Tier::Rare); assert_eq!(roll_tier(9700, true, 100), Tier::Legendary); }
#[test] fn quality_is_clamped() { assert_eq!(roll_tier(5000, false, 999), roll_tier(5000, false, 100)); }
```
(Odds at q=100: base [5000, 3400, 1300, 300]; specialist [3500, 4200, 1800, 500].)

- [ ] **Step 2:** `cargo test -p economy` -> FAIL. **Step 3:** implement. **Step 4:** PASS (restock/burn tests kept).
- [ ] **Step 5:** vectors: `{item, stock, purse, qty, specialist, ask, bid, buy_room, sell_room, burn}` for every item x stock {0,1,3,12,40,100,120,200} x purse {50,10000} x qty {1,5} x specialist {false,true}, plus `rolls: [{roll, specialist, quality, tier}]` for roll in {0,4999,5000,6999,7000,9099,9100,9699,9700,9899,9900,9999} x specialist x quality {0,50,100}. Commit.

### Task 2: contract v2 - per-item stock, class, bonus (core, ~3 h)

**Files:** Modify `contract/src/lib.rs`, `contract/src/deals.rs`, `contract/src/nep245.rs`, `contract/src/tests.rs`.

**Interfaces (produces):**
- `TOKENS` = coin + 12 item ids. `Merchant { category: String, public_key: PublicKey }`.
- `register_merchant(account_id, category: String, public_key, coin: U128)` owner-only; mints each category item at its target stock.
- `register_player(player_id)` unchanged (1000 coin). New `classes: LookupMap<String, String>`.
- `set_class(player_id, class: String)` game-only; `"fisher"|"logger"|"miner"` else `"BadClass"`; first pick free, later picks burn 100 coin (`"InsufficientFunds"`), same class -> no-op.
- `gather_batch` entries' `good` = item id (`"BadGood"` otherwise).
- `settle_deal`: `deal.good` must be an item of the merchant's category (`"BadGood"`); sell room uses `specialist = class matches category`.
- `day_tick`: restock + burn per item for every merchant.
- Views: `get_market() -> Vec<ItemView { merchant, category, item, tier, stock, purse, ask, bid, floor, ceiling_one }>` (12 rows), `get_player(player_id) -> Option<PlayerView { class: Option<String>, balances: HashMap<String, U128> }>`.

- [ ] **Step 1: failing tests:** `register_merchant_mints_targets` (fishmonger: fish_sardine 120, fish_koi 3); `set_class_first_free_then_costs_100`; `set_class_bad_class_rejected`; `gather_mints_item`; `settle_buy_trout_happy_path`; `ore_to_fishmonger_rejected` (`BadGood`); `specialist_sells_above_normal_ceiling` (fisher sells trout at normal ceiling+1 ok, non-fisher same price -> `PriceOutOfRoom`); `day_tick_per_item`; keep signature/nonce/expiry/purse tests ported to item ids.
- [ ] **Step 2:** `cargo test -p haggle-contract --lib` -> FAIL. **Step 3:** implement. **Step 4:** PASS + wasm build. Commit.

### Task 3: deploy contract v2 (core, ~1 h)

**Files:** Modify `scripts/seed.sh` (register with category, no stock args), `.env`, `docs/hackathon/DEPLOYMENTS.md`.
- [ ] `CONTRACT_ID=haggletown-v2.testnet bash scripts/deploy.sh && CONTRACT_ID=haggletown-v2.testnet bash scripts/seed.sh` (new merchant sub-accounts `woodcutter.haggletown-v2.testnet` etc.).
- [ ] Verify `get_market` -> 12 rows, koi ask 600, iron ask 90. Record in DEPLOYMENTS.md + TESTING.md. Commit (scripts/docs only).

### Task 4: backend v2 - items, gather sessions, class, stats (core, ~4 h)

**Files:** Modify `server/src/types.ts`, `server/src/chain/market.ts`, `server/src/game/{gather,players,leaderboard,history}.ts`, `server/src/routes/{rbx,api}.ts`, `server/src/haggle/pricing.ts` (port of Task 1), `server/src/db/schema.sql` (+`player_class`, `gather_session`, `catch_log` tables); tests updated/added.

**Interfaces (produces):**
- `Balances = Record<string, number>` (coin + 12 ids). `MarketView` per item `{merchant, category, item, tier, stock, purse, ask, bid, floor, ceiling_one, day, last_tick_ns}`; `MarketCache.forMerchant(name)`, `.byItem(id)`.
- `ITEMS` table in TS: `{id, name, category, tier}`; `pricing.ts`: `ask/bid/buyRoom/sellRoom(item, stock, purse, qty, specialist)/rollTier(rollBp, specialist, quality)` matching vectors.
- `GatherSessions.start(playerId, node) -> {sessionId, node, params: {zoneScale, fishSpeed, minMs}} | {error: "cooldown"|"busy"}`; `.finish(playerId, sessionId, quality) -> {item, qty, tier}` with 404 unknown/foreign, 409 finished/expired, 422 too fast. Pending row uses the item id.
- `Classes.choose(playerId, cls) -> {class, balances} | error "cooldown"|"InsufficientFunds"`; calls `set_class` via queue; table `player_class(player_id PK, class, changed_at)`.
- Routes: `POST /rbx/gather/start {userId, node}`, `POST /rbx/gather/finish {userId, sessionId, quality}`, `POST /rbx/class {userId, class}`, `GET /rbx/stats?userId=` -> `{class, balances, netWorth, bestCatch: {item, tier} | null, deals, rank}`. Remove `POST /rbx/gather`.
- `/api/market` returns per-item rows; `/api/history` keyed by item; `/api/players/:id` balances map + class.

- [ ] **Step 1: failing tests:** pricing port vs new vectors (incl. rolls); sessions: too fast 422, foreign session 404, double finish 409, expired 409, quality NaN/-1/5 clamped, ore_mouth never legendary (roll 9999), fisher double drop path (inject rng); class: first free, switch within 5 min refused, insufficient coin refused (fake chain panics `InsufficientFunds`); stats shape; join against v2 contract returns 1000 coin balances map (Review Focus 5).
- [ ] **Step 2:** FAIL. **Step 3:** implement (rng injectable: `rand: () => number`). **Step 4:** `npm test` + `npm run typecheck` PASS. Testnet smoke updated (start/finish wood with real waits). Commit.

### Task 5: haggle v2 - items in offers, LLM, quick-sell (core, ~2 h)

**Files:** Modify `server/src/haggle/{offer,engine,reasoning,fallback}.ts`, `server/src/llm/prompt.ts`, tests.

**Interfaces:** `parseOffer(text, category) -> Offer & {item?: string}` recognising item names (sardine, trout, salmon, koi/golden koi, pine, oak, maple, redwood, copper, iron, gold, crystal). Engine picks `offer.item`, else for `sell` the rarest item of that category the player holds, else common. Rejects items outside the merchant's category (400 `wrong_merchant`). Counter carries `item`. Reasoning + LLM context name the item and its tier. Fallback lines name the item.
- [ ] Tests: "sell 2 trout for 200" -> item fish_trout qty 2 total 200; "sell copper" at fishmonger -> 400; counter item matches; specialist room used when player class matches. FAIL -> implement -> PASS. Eval re-run (expect >=12/15). Commit.

### Task 6: Roblox gather framework + fishing minigame (core, ~4 h)

**Files:** Create `roblox/src/client/minigames/Fishing.luau`, `roblox/src/client/minigames/Run.luau` (dispatch + result), `roblox/src/shared/Minigame.luau` (pure scoring math: `fishingQuality(timeInZoneRatio, castPower) -> number`, `catchProgress(inZone, dt, speed) -> delta`); modify `roblox/src/server/Main.server.luau` (Remotes `GatherStart`, `GatherFinish`; node prompts start a session and fire client `PlayMinigame(node, params)`), `roblox/src/client/Main.client.luau`; test `roblox/tests/Minigame.spec.luau`.
- Fishing per spec section 5 (cast bar, bite window 0.8 s, reel bar; fish speed from `params.fishSpeed`, zone height x `params.zoneScale`).
- [ ] Tests (Lute): scoring math deterministic cases (zone ratio 1.0 + perfect cast -> 1.0; ratio 0 -> 0; clamping). FAIL -> implement -> PASS; syntax check; Studio playtest by user (record in TESTING.md). Commit.

### Task 7: chopping + mining minigames (core, ~3 h)

**Files:** Create `roblox/src/client/minigames/Chopping.luau`, `roblox/src/client/minigames/Mining.luau`; extend `roblox/src/shared/Minigame.luau` (`chopQuality(hits, perfects)`, `mineQuality(hitPoints, totalPoints)`); tests extended.
- Chopping: swinging needle, sweet spot width x zoneScale, 4 good hits, perfect = center 30% of spot. Mining: 5 weak points, fade 0.9 s (0.7 s in `ore_deep`), size x zoneScale.
- [ ] Tests for quality functions; FAIL -> implement -> PASS. Commit. (Stretch inside task: chopping combo multiplier.)

### Task 8: lobby, classes, stats, bag, quick-sell (core, ~4 h)

**Files:** Create `roblox/src/server/Lobby.luau` (class hall with 3 mentors + prompts, info boards, leaderboards, gate), `roblox/src/client/ui/StatsPanel.luau` (Tab key), `roblox/src/client/ui/ClassCard.luau`; modify `Hud.luau` (Coin + class badge + Bag count), `HagglePanel.luau` (quick-sell chips for items of that merchant's category in the bag: click fills "sell 1 <item> for "), `Main.server.luau` (Remotes `ChooseClass`, `GetStats`).
- Copy: class card shows the spec section 4 table in plain words; boards: How to play (Pick a class -> Gather with skill -> Haggle with merchants), rarity table with tier colors (common grey, rare blue, epic purple, legendary gold), "Prices move with supply and demand".
- [ ] Policy grep; syntax check; Studio playtest. Commit.

### Task 9: mountain-lake map + cave (core, ~4 h)

**Files:** Create `roblox/src/server/Terrain.luau` (deterministic: mountain ring via `FillBall`/`FillWedge` rock+snow, grass valley, sand beach, lake water, cave tunnel carved with `FillBlock(Air)` and two chambers lit by lanterns); modify `World.luau` (lobby at village edge, village around the lake shore, nodes: fishing on the dock, trees by type, `ore_mouth` and `ore_deep` rocks in the cave chambers). Keep each node's prompt part and the lobby within ~30 s walk of every node.
- [ ] Studio playtest walk times; syntax check. Commit.

### Task 10: free Creator Store assets (stretch - cut first, ~3 h)

- With Roblox Studio MCP (user installs) or manually by the user: insert houses, docks/boats, trees, rocks, lanterns, fences; group under `Workspace.MapAssets`; save as `roblox/assets/Map.rbxm`; mount in `default.project.json` + `local.project.json` (`Workspace.MapAssets: {"$path": "assets/Map.rbxm"}`); credits in README.

### Task 11: dashboard + sim v2 (core, ~3 h)

**Files:** `web/src/App.tsx`, `web/src/api.ts`, `web/src/Players.tsx` (items grouped by category with tier colors, class badge), `sim/src/main.rs` (items + bot classes; tests: every category's ask changes on >=3 days; legendary prices move).
- [ ] sim tests FAIL -> PASS; web build; deploy Railway; visual check. Commit.

### Task 12: deploy + golden path (core, ~1 h)

- [ ] `railway up`; Railway vars `CONTRACT_ID=haggletown-v2.testnet` and merchant/game keys from `.env` via `scripts/railway-env.sh`; prod smoke: join -> class -> gather start/finish -> haggle -> accept; Studio golden path by the user; TESTING.md + STATE.md checkpoint. Commit.
