# Haggle Town v2 - design

Date: 2026-11-11. Status: draft, awaiting user approval. Builds on v1 (docs/superpowers/specs/2026-11-10-haggle-town-design.md), which is live: NEP-245 contract on testnet, signed merchant deals, relayer, AI merchants, dashboard.
User asked for: a lakeside village in the mountains with a miner cave (free Creator Store assets allowed), a Roblox-style lobby with stats and info, three classes with fair gather and sell benefits, resource rarity with price = rarity x live economy, and gather minigames instead of hold-E (fishing like Fisch, plus chopping and mining). User opted out of design questions; every choice below not quoted from the user is my call.

Time: ~88 h to deadline (2026-11-14 23:59 UTC). Everything below is scoped to fit with a cut list (section 9).

## 1. Intent

v1 proves the chain integration. v2 makes it a game people want to keep playing for three minutes: skillful gathering, a reason to specialise, and loot worth haggling over. The chain stays invisible inside Roblox.

## 2. Goals / non-goals / anti-goals

Goals
- A judge spawns in a lobby, picks a class, walks into a pretty village, catches a rare fish in a real minigame, and haggles it to a merchant for a price that depends on rarity and on today's stock - all settled on NEAR testnet.
- Classes matter but no class is mandatory or dominant.
- Every resource has a tier; price follows tier x supply/demand.

Non-goals
- PvP, crafting, inventory beyond stacks per item, quests, progression levels, trading between players (still stretch from v1), mobile-tuned minigame controls (desktop first, touch works but not tuned).

Anti-goals
- A minigame the client can fully fake for legendary loot with no server checks.
- Chain words inside Roblox (unchanged rule).
- A map that only looks good in screenshots but blocks the golden path (no long walks: lobby to any gather spot under ~30 s).

## 3. Items and rarity

Four tiers per category. The tier decides the item; each item has its own stock at its merchant.

| Category (merchant) | Common | Rare | Epic | Legendary |
| --- | --- | --- | --- | --- |
| Fish (Fishmonger) | Sardine | Trout | Salmon | Golden Koi |
| Wood (Woodcutter) | Pine | Oak | Maple | Ancient Redwood |
| Ore (Smith) | Copper | Iron | Gold | Crystal |

- Token ids (NEP-245): `coin` plus `<category>_<item>`, e.g. `fish_trout`, `ore_gold` (12 items).
- Base price = category base x tier multiplier. Category base: fish 20, wood 15, ore 30 (my call). Tier multiplier: common 1, rare 3, epic 8, legendary 30.
- Each item has its own target stock at its merchant: common 120, rare 40, epic 12, legendary 3. Supply/demand per item uses the existing `pricing.rs` rules (ask, bid, haggle room, restock, burn) with that item's base and target - so rarity x live economy falls out of the same formula.
- Base drop odds (no class, average skill): common 70%, rare 22%, epic 7%, legendary 1%.

## 4. Classes

Pick one in the lobby. Switching costs 100 C and has a cooldown of one game day (5 min), so nobody switches just to sell.

| | In your field (Fisher: fish, Logger: wood, Miner: ore) | Outside your field |
| --- | --- | --- |
| Minigame | Easier: catch zone / sweet spot / weak points +30% larger | Normal |
| Luck | Tier odds shifted up: common 55, rare 30, epic 12, legendary 3 | Base odds |
| Yield | 15% chance of a double drop | none |
| Selling | Merchant ceiling +10% for your field's items (respect for specialists) | Normal room |
| Buying | Normal | Normal |

Fairness check (expected coin per minute at base prices, my estimate): a specialist earns ~1.8-2.2x a non-specialist in their own field and the same elsewhere; all three fields have similar EV per minute after tuning in the simulator. Class sell bonus is enforced on chain: the contract stores each player's class (set by the relayer) and widens the sell room by 10% only for matching items.

## 5. Gather minigames

All minigames run in the client UI; the server owns the outcome (section 6).

**Fishing (3 phases, Fisch-like)**
1. Cast: hold to charge a power bar, release. Releasing in the top band = long cast (+luck), too early = short cast.
2. Wait: bobber floats 2-6 s (random), then "!" - click within 0.8 s or the fish escapes.
3. Reel: vertical bar with a fish icon that darts up and down; hold mouse/space to raise a green catch zone, release to let it fall. Keep the fish inside the zone to fill progress to 100% before it drains to 0. Rarer fish dart faster; Fisher gets a bigger zone.

**Chopping**: a needle swings across a bar with a small sweet spot; click when the needle is in it. A tree needs 4 good hits; perfect hits build a combo (+luck), misses add a hit. Tree types in the forest hint at the odds (big old trees roll better but respawn slower).

**Mining**: inside the cave, a rock shows glowing weak points at random spots on screen; click each before it fades (0.9 s, faster deeper in). 5 points per rock; accuracy = quality. Two zones: cave mouth (copper/iron odds up) and deep cave (gold/crystal odds up, darker, needs a lantern light).

Quality score 0..1 from each minigame feeds luck (up to +1 tier step of odds); failing a minigame gives nothing.

## 6. Server authority (anti-cheat)

- `POST /rbx/gather/start {userId, node}` -> backend checks cooldown and node type, returns `{sessionId, params}` (zone sizes, fish speed seed, min duration) and records start time.
- `POST /rbx/gather/finish {userId, sessionId, quality}` -> backend rejects if faster than the minimum human duration or session expired; clamps quality to [0,1]; rolls the tier server-side with class + quality luck; credits a pending item minted in the next `gather_batch`.
- The Roblox server also checks distance to the node and one session at a time per player.
- Known residual risk: a modified client can always report quality 1. Capped effect: at most one tier-step of luck, and the server still enforces timing and cooldown. Acceptable on testnet; noted in SECURITY.md.

## 7. Lobby

Players spawn in a lobby plaza at the village edge (same place, no teleport).
- **Class hall**: three mentor NPCs (Old Fisher, Lumberjack, Miner) on pedestals; prompt "Become a Fisher" opens a confirm card with the class table.
- **Stats**: a stats panel (key `Tab` or the Stats board) with class, Coin, net worth, items by tier, best catch, deals made, rank. Data from a new `GET /rbx/stats`.
- **Info boards**: How to play (3 steps), Rarity table, Class benefits, "Prices move with supply and demand".
- **Leaderboards**: richest traders, rarest catch today.
- **Gate** with a path into the village square.

## 8. Map

Lakeside village in a mountain valley:
- Terrain generated by a script (in git, reproducible): mountain ring of rock/snow, grass valley, sand beach, a lake with real terrain water, a cave tunnel carved into a mountain with two chambers.
- Village built from free Creator Store models: houses, market stalls, docks/boats, trees by type, rocks, lanterns, fences. Inserted in Studio (by Roblox Studio MCP if the user installs it, otherwise by the user), saved as `roblox/assets/Map.rbxm` and mounted by the Rojo project, so the map is versioned and live sync keeps working for code.
- Gameplay anchors (prompt parts) stay placed by script so server distance checks keep working.
- Asset credits listed in README.

## 9. Build order and cut list

1. Economy v2: items/tiers in `pricing.rs`, contract v2 (12 items, per-item stock, player class, class sell bonus) deployed to a fresh testnet account; backend + haggle understand items; dashboard shows items. (~12 h)
2. Minigames: fishing (full), chopping, mining + gather sessions + server rolls. (~14 h)
3. Classes + lobby (class hall, stats panel, info boards). (~8 h)
4. Map: scripted terrain + cave, then free assets. (~10 h)
5. Sim + fast-forward for items, docs, demo. (~6 h)

Cut first if behind: legendary-tier visuals and double drop; mining zones (one cave chamber); chopping combo; free assets (keep scripted terrain + current props); fast-forward per item (keep per category).

## 10. Left to the builder
Exact tier odds, minigame timings and sizes (tuned by playtest and the simulator), item art, NPC looks, asset choice within the theme.
