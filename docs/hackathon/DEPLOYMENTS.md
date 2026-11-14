# Deployments

Judges and teammates read this to reproduce the on-chain demo. Testnet only unless the user explicitly approved mainnet. Never put private keys or seed phrases here.

## Network
| Field | Value |
| --- | --- |
| Chain / ecosystem | NEAR Protocol testnet |
| Chain ID / cluster | `testnet` (protocol version 88, checked 2026-11-10) |
| RPC URL (public) | https://test.rpc.fastnear.com |
| Fallback RPC | https://rpc.testnet.near.org |
| Block explorer | https://testnet.nearblocks.io |
| Faucet | `near account create-account sponsor-by-faucet-service <name>.testnet ...` (near-cli-rs 0.31.1) |

## Contracts / programs
| Name | Address / program ID | Deploy tx | Verified on explorer | Source path |
| --- | --- | --- | --- | --- |
| Haggle Town market (NEP-245 + merchants + deals + day tick) | `haggletown.testnet` | [4QYjA8ET5tabFC1Tr7XVixmhFGdHzzd7912pQGzBLW25](https://testnet.nearblocks.io/txns/4QYjA8ET5tabFC1Tr7XVixmhFGdHzzd7912pQGzBLW25) (deploy + init, 2026-11-10) | No (plain cargo build; reproducible cargo-near build not available on dev box) | `contract/` |

## v2 contract (2026-11-11)
- `haggletown-v2.testnet` (fresh account; v1 `haggletown.testnet` keeps running for the live v1 backend until Task 12 switches Railway).
- Merchants `woodcutter|fishmonger|smith.haggletown-v2.testnet` registered by category (wood/fish/ore), 20000 coin each, every item at target stock; game relayer `game.haggletown-v2.testnet`.
- get_market: 12 rows; asks pine 15, oak 45, maple 120, redwood 450, sardine 20, trout 60, salmon 160, koi 600, copper 30, iron 90, gold 240, crystal 900.

## Backer coins (2026-11-14, Memecoins With Mechanics; docs/hackathon/MEMECOIN.md)
| Coin | Contract | Merchant | Notes |
| --- | --- | --- | --- |
| $WOOD | `wood-coin.haggletown-v2.testnet` | woodcutter | sub-account, 2.15 NEAR |
| $FISH | `fish-coin.haggletown-v2.testnet` | fishmonger | sub-account, 2.15 NEAR |
| $SMITH | `haggletown-smith-coin.testnet` | smith | faucet account (deployer was out of testnet NEAR) |
- Init: cap_bp 500, claim 1000 coins (6 decimals), 1000 claims. First tick (baseline): day 553/554; worth 24287 / 26590 / 29379. Server ticks all three after each day_tick (45 Tgas each).
- Full-access keys of the coin accounts are still in the legacy keychain (contract has no admin method, but the account owner could redeploy code until the keys are deleted).

## Relayer gas (2026-11-14)
- `game.haggletown-v2.testnet` fell to 0.098 NEAR; calls reserving 100 Tgas were rejected. Calls now reserve 50 Tgas. Top the relayer up before the demo.

## Roles and keys (names only)
| Role | Address | Key storage |
| --- | --- | --- |
| Deployer / owner | `haggletown.testnet` (faucet, created 2026-11-10, tx HeXjR4svTQ2awrNasXRDtv8JMT1fLifLqHbqbtDaR8Hi) | near-cli-rs keychain on dev machine; burner, testnet only |
| Game relayer (acts for players, gather mint, stalls, day tick) | `game.haggletown.testnet` (0.5 NEAR) | `GAME_PRIVATE_KEY` env var on backend only |
| Merchant: Woodcutter | `woodcutter.haggletown.testnet` (0.5 NEAR) | `WOODCUTTER_PRIVATE_KEY` env var on backend only |
| Merchant: Fishmonger | `fishmonger.haggletown.testnet` (0.5 NEAR) | `FISHMONGER_PRIVATE_KEY` env var on backend only |
| Merchant: Smith | `smith.haggletown.testnet` (0.5 NEAR) | `SMITH_PRIVATE_KEY` env var on backend only |
| Demo players | Not NEAR accounts: contract-internal ids `roblox:<UserId>`, `web:<uuid>` | n/a |

## Demo state
- Pre-funded wallets: haggletown.testnet 7.97 NEAR (storage 256 KB), 4 sub-accounts 0.5 NEAR each (2026-11-10 21:10)
- Seed data already on-chain: 3 merchants registered (woodcutter/wood, fishmonger/fish, smith/iron), 10000 coin, stock 100, target 100; get_market shows ask 50/80/150, bid 40/64/120
- Reference transactions for the demo script:
  - Guardrail proof (2026-11-14): a deal the Woodcutter really signed, pine at 1 coin (under the floor), refused with `PriceOutOfRoom`: [FLb7YA38r3r1ESFuHoapirMX5bFsbGteK8mTVfVgN2zN](https://testnet.nearblocks.io/txns/FLb7YA38r3r1ESFuHoapirMX5bFsbGteK8mTVfVgN2zN). Re-run: `cd server && node --env-file=../.env scripts/guardrail-proof.ts`.
  - v2 code redeploy (2026-11-14 18:40, `use_items` for the Forge): [J9HJt49ARMaWbCUjC5piHSk1ZLQuSAVcQP5Nnxu6bsDz](https://testnet.nearblocks.io/txns/J9HJt49ARMaWbCUjC5piHSk1ZLQuSAVcQP5Nnxu6bsDz). First prod forge (Sturdy Axe, burned 3 Copper + 3 Sardine): [CdK2vq3c...](https://testnet.nearblocks.io/txns/CdK2vq3cNoQ34xJbZnCosBAC2Q4yJpTygARm4gdc3qHk).
  - v2 code redeploy (2026-11-14, `price_ok` rule + `--cfg near` build so panics keep their error codes): [AD3fESQnVrLEgGczFzNfJaWF8hCq8zrFAg6EkmJYn961](https://testnet.nearblocks.io/txns/AD3fESQnVrLEgGczFzNfJaWF8hCq8zrFAg6EkmJYn961). Smoke after redeploy: SMOKE OK.
- Fallback if RPC or chain is down: switch to fallback RPC; recorded demo video; LLM replay mode for merchant replies

## Backend + dashboard hosting
- Railway project `haggle-town`, service `backend` (Dockerfile), volume `/data` for SQLite.
- Public URL: https://backend-production-fccb03fb.up.railway.app (dashboard at `/`, `/health`, `/api/*`; Roblox calls `/rbx/*` with HMAC).
- Deployed 2026-11-10 ~22:30 +0700; verified /health, /api/config, /api/market, /sim/week.json 200; unsigned /rbx 401; signed join + haggle 200 against testnet.
- NEAR Builders project: `haggle-town` (id proj_1794324838912_9twhgjb, private, owner goatdarko.near).

## Frontend config
- Env var names (not values): `NEAR_NETWORK`, `NEAR_RPC_URL`, `CONTRACT_ID` (backend); web reads config from backend `/api/config`, no keys in the bundle
- Network switch / add-network prompt tested with a fresh wallet: n/a (no player wallets; relayer signs)
- ABI / IDL committed at: Not done (plan: `contract/abi.json` via cargo-near if available)

## Known risks (honest list)
- Owner, game relayer and merchant keys are single burner keys held by one backend; no multisig/timelock.
- Players are custodial contract-internal balances; the game relayer is trusted to act for them.
- AI audit only (x-ray), not a guarantee.
