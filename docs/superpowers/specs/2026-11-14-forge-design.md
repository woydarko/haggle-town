# Forge: a reason to buy from merchants (design)

Date: 2026-11-14. Status: approach A picked by the user ("gas yang A"); details below are the builder's calls.

## Why
Items and Coin had no use besides the score, so buying from a merchant only made sense as speculation.
The Forge gives goods a use (upgrade your gathering tools), gives Coin a use (buy the goods you lack),
creates trade between classes (each tool needs goods from the other two trades) and adds a real sink
(forged goods are burned on chain).

## Approaches considered
- **A. Forge: tool upgrades (picked).** Invest goods/Coin now, catch more later. Cross-class demand + on-chain sink.
- B. Town orders (daily commissions): needs a new Coin faucet (inflation risk), more balancing.
- C. Collection set (12 slots, title): no contract change, but no sink and the reason ends once complete.

## Rules (server: `server/src/game/forge.ts`)
| Tool (gathers) | Lv 2 "Sturdy" | Lv 3 "Master" |
| --- | --- | --- |
| Axe (wood) | 3 Copper + 3 Sardine | 2 Iron + 2 Trout |
| Pickaxe (ore) | 3 Pine + 3 Sardine | 2 Oak + 2 Trout |
| Rod (fish) | 3 Pine + 3 Copper | 2 Oak + 2 Iron |

Theme: metal heads (ore), wooden handles/poles (wood), blades quenched in fish oil (fish).
Effect: chance of a second item per catch: Lv1 0%, Lv2 25%, Lv3 50%, added to the trade (class) bonus of 15%.
Levels start at 1 and only go up. No Coin fee (skipped; a fee paid into the Smith's purse is a later idea).

## Flow
1. Guide step 5 "Forge a better tool" (after the Ledger step): names the class tool, the first missing good and
   the merchant who sells it; the world marker points at that stall.
2. Haggle panel has Sell / Buy tabs. Buy shows the merchant's 4 goods with icon + ask price; goods the next
   upgrade needs carry an anvil badge and the missing count. One tap asks for that quantity; the merchant
   counters; Accept (or haggle with the usual chips). The panel opens on Buy when the Forge needs this merchant's goods.
3. Forge panel (HUD button "Forge (F)"): one row per tool with its level icon, current and next effect,
   materials as icon + have/need, and Forge (enabled when all are there) or "Find seller" (points the marker).
4. Forging: backend flushes pending catches, checks on-chain balances, calls `use_items` (burn), stores the
   level, logs a forge event (dashboard feed). Toast + sound; the tool in hand gets a level outline.
5. Gathering: the catch card says "x2 - Sturdy Axe bonus" when the tool roll hit.

## On chain
`use_items(player_id, items: [(item_id, amount)])`: relayer only, 1-4 entries, amount 1-20, items only (no
Coin), burns via NEP-245 `mt_burn`. No new contract state (state layout unchanged; levels live in the
backend DB, table `player_tool`).

## Non-goals
Tool levels on chain, Coin fee, recipe UI for Lv 4+, simulator changes, tool trading.
