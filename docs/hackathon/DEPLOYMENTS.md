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
| Haggle Town market (NEP-245 + merchants + stalls) | Not deployed | - | No | `contract/` |

## Roles and keys (names only)
| Role | Address | Key storage |
| --- | --- | --- |
| Deployer / owner | Not created (proposal: `haggletown.testnet`) | near-cli-rs keychain on dev machine; burner, testnet only |
| Game relayer (acts for players, gather mint, stalls, day tick) | Not created (proposal: `game.haggletown.testnet`) | `GAME_PRIVATE_KEY` env var on backend only |
| Merchant: Woodcutter | Not created (proposal: `woodcutter.haggletown.testnet`) | `WOODCUTTER_PRIVATE_KEY` env var on backend only |
| Merchant: Fishmonger | Not created (proposal: `fishmonger.haggletown.testnet`) | `FISHMONGER_PRIVATE_KEY` env var on backend only |
| Merchant: Smith | Not created (proposal: `smith.haggletown.testnet`) | `SMITH_PRIVATE_KEY` env var on backend only |
| Demo players | Not NEAR accounts: contract-internal ids `roblox:<UserId>`, `web:<uuid>` | n/a |

## Demo state
- Pre-funded wallets: Not done
- Seed data already on-chain: Not done (plan: 3 merchants with 10000 Coin + target stock each)
- Reference transactions for the demo script: Not done
- Fallback if RPC or chain is down: switch to fallback RPC; recorded demo video; LLM replay mode for merchant replies

## Frontend config
- Env var names (not values): `NEAR_NETWORK`, `NEAR_RPC_URL`, `CONTRACT_ID` (backend); web reads config from backend `/api/config`, no keys in the bundle
- Network switch / add-network prompt tested with a fresh wallet: n/a (no player wallets; relayer signs)
- ABI / IDL committed at: Not done (plan: `contract/abi.json` via cargo-near if available)

## Known risks (honest list)
- Owner, game relayer and merchant keys are single burner keys held by one backend; no multisig/timelock.
- Players are custodial contract-internal balances; the game relayer is trusted to act for them.
- AI audit only (x-ray), not a guarantee.
