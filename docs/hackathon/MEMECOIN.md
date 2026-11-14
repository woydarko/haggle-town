# Backer coins: $WOOD, $FISH, $SMITH (Memecoins With Mechanics)

## The joke, and its rules
Every AI merchant in Haggle Town has a memecoin. Holding $SMITH is backing the Smith: once per market day the coin
rebases every holder by how much the Smith's net worth moved, so a merchant who holds his prices makes his backers
richer, and one who gets haggled into bad deals shrinks every wallet. Players haggle against the merchants inside the
game; backers on the web bet on the house. The meme is a fan token for an AI agent, and the mechanic is that agent's
real, on-chain balance sheet.

## Mechanic (all in the coin contract, `coin/src/lib.rs`; math in `economy/src/coin.rs`)
- `tick()`: anyone, any time. The coin calls the market contract's `get_market` (cross-contract, not a backend), sums
  its merchant's net worth = purse + every stocked item x the merchant's own bid, and if the market day moved on since
  the last tick, rebases: `step = clamp((worth_now - worth_last) / worth_last, -cap, +cap)`; `index *= 1 + step`.
  One step per tick of a new market day; skipped days are not back-filled (the cap holds per call).
- Balances are shares x index. A rebase is one storage write, every holder moves by the same percent.
- `back()` (attach 0.01 NEAR): one claim of 1000 coins per account, 1000 claims per coin. Backing late gets the same
  1000 coins at today's index, not an inflated share.
- NEP-141: `ft_transfer`, `ft_transfer_call` (+ `ft_resolve_transfer`), `ft_total_supply`, `ft_balance_of`,
  `ft_metadata` (6 decimals); NEP-145 `storage_deposit` to receive without backing. Events: NEP-297 `ft_mint`,
  `ft_transfer`, and `haggle_coin/rebase` with day, worth, step and supply.
- Parameters are set in `new()` and readable by anyone (`info()`): cap 500 bp, claim 1000, claims 1000. The contract
  has no owner field and no method that changes them. `rebases(from, limit)` is the full mint/burn log.

## Choosing the cap: 60-day simulation (`cargo run -p sim -- --coins`)
Same bots, pricing and Forge as the game; 3 seeds each; supply multiple at day 60 for fish/wood/ore.

| Town | Cap/day | Day-60 supply (fish/wood/ore) | Lowest..highest any day | Days at the cap |
| --- | --- | --- | --- | --- |
| quiet (4 bots) | 3% | 0.98 / 0.88 / 1.33 | 0.73..1.49 | 84% |
| quiet (4 bots) | **5%** | 0.95 / 0.80 / 1.52 | 0.61..1.86 | 71% |
| quiet (4 bots) | 10% | 0.77 / 0.63 / 1.97 | 0.43..2.96 | 49% |
| normal (10 bots) | 3% | 0.94 / 0.95 / 1.27 | 0.79..1.57 | 80% |
| normal (10 bots) | **5%** | 0.91 / 0.93 / 1.44 | 0.68..2.01 | 73% |
| normal (10 bots) | 10% | 0.82 / 0.85 / 1.71 | 0.47..2.79 | 52% |
| busy (30 bots) | 3% | 0.96 / 0.97 / 1.00 | 0.79..1.19 | 72% |
| busy (30 bots) | **5%** | 0.91 / 0.94 / 0.99 | 0.73..1.32 | 60% |
| busy (30 bots) | 10% | 0.76 / 0.83 / 0.95 | 0.61..1.24 | 38% |

Picked **5%**: wide enough that the coins visibly disagree (the Smith, who players mostly buy from, ends up; the
Fishmonger and Woodcutter, who buy most of what players gather, drift down), narrow enough that 60 days stay within
0.6x..2x. At 10% a quiet town loses more than half a coin's supply in two months.

## Sybil resistance (limits, plainly)
- The daily mint/burn is proportional to holdings, so splitting coins over many accounts earns nothing.
- The only per-account reward is the launch claim. Each claim costs 0.01 NEAR plus a new NEAR account, and claims are
  capped at 1000 per coin. A determined farmer can still collect many claims with many funded accounts; on testnet
  that is cheap. A mainnet launch would need an identity gate (or a paid mint) for the claim.
- `tick()` is permissionless; calling it more often does nothing until the market day changes.
- The merchant's worth moves with real trades in the market contract (settled deals, restock, burn, Forge sinks).
  Someone could trade against a merchant to push his coin, but the price rules of the market contract still apply to
  every deal and the step is capped at 5% a day.

## Contracts (NEAR testnet)
| Coin | Contract | Backs |
| --- | --- | --- |
| $WOOD | `wood-coin.haggletown-v2.testnet` | `woodcutter.haggletown-v2.testnet` |
| $FISH | `fish-coin.haggletown-v2.testnet` | `fishmonger.haggletown-v2.testnet` |
| $SMITH | `haggletown-smith-coin.testnet` (own faucet account: the deployer ran out of testnet NEAR) | `smith.haggletown-v2.testnet` |

Deploy: `bash scripts/deploy-coins.sh`. Back one:
`near contract call-function as-transaction <coin> back json-args '{}' prepaid-gas '30 Tgas' attached-deposit '0.01 NEAR' sign-as <you>.testnet network-config testnet sign-with-keychain send`

## Not in Roblox
The coins live only on the web dashboard (tab "Backer coins") and NEAR testnet. The Roblox game never shows, grants or
mentions them, and its Coin stays a closed in-game currency (Roblox policy).
