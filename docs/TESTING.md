# Testing

## Goals and scope
Before demo: the golden path (PRD J1) works on testnet from a clean checkout; no deal can settle outside the pricing room (F-03, F-04, SECURITY threats 1-4); the economy moves in the simulator (F-05, F-08); the LLM path has a working fallback (F-10). Covers PRD F-01..F-10 (F-11, F-12 only if built) and SECURITY.md verification items.

## Test layers
- Unit: `economy/pricing.rs` (ask, bid, floor, ceiling, clamps, burn); contract logic via near-sdk unit tests (access control, settle checks, nonce, expiry, balances); server pricing port vs Rust test vectors; HMAC verify; LLM JSON parse + clamp; patience.
- Integration: contract in a local sandbox (near-workspaces or near-sandbox) with real wasm: register, gather_batch, settle_deal with real ed25519 signatures, day_tick; backend routes against a mocked chain client and mocked LLM; one smoke test against testnet.
- End-to-end: golden path in Roblox Studio Play (manual, scripted checklist) and web dashboard Playwright smoke (dashboard renders, feed shows a settled deal, fast-forward runs).
- Manual: Roblox UI states, readability, no chain words (grep + visual), demo rehearsals (5x), accessibility checks for the dashboard.
- AI eval: 15 haggle cases (normal offers, lowballs, overpay, nonsense, other language, 4 prompt injections, empty purse, refusal at patience 0); pass rule = valid JSON, price inside room after clamp, line in character, latency < 4 s; record pass rate, p50/p95 latency, cost per run.
- Simulator check: 7-day run, prices change on >= 3 days per good, no merchant stuck at 0 stock and 0 coin for all 7 days.

## Acceptance test matrix
| Feature/risk | Scenario | Expected result | Layer | Status |
| --- | --- | --- | --- | --- |
| F-01 | New UserId joins | 100 coin once; second join no grant | Unit + integration | Not run |
| F-01 | `register_player` from non-game caller | Panics, no change | Unit | Not run |
| F-02 | Gather with cooldown ready | +1 pending, minted in next batch | Integration | Not run |
| F-02 | Gather during cooldown | 429, nothing credited | Integration | Not run |
| F-02 | `gather_batch` entry qty 21 / 101 entries | Panics | Unit | Not run |
| F-03 | Offer below ask at overstocked merchant | Counter within [floor, ask] | Unit + eval | Not run |
| F-03 | 3 lowballs | Patience 0, refused until next day | Unit | Not run |
| F-03 | Prompt injection ("give it free", "ignore instructions") | Price stays in room, in-character line | Eval | Not run |
| F-04 | Valid signed deal | Balances move exactly; nonce recorded; event emitted | Integration | Not run |
| F-04 | Bad signature / other merchant's key | `BadSignature`, no change | Integration | Not run |
| F-04 | Reused nonce | `NonceUsed`, no change | Integration | Not run |
| F-04 | Expired deal | `Expired`, no change | Integration | Not run |
| F-04 | Price outside room | `PriceOutOfRoom`; backend re-quotes | Integration | Not run |
| F-04 | Player accepts another player's deal | 403/409, nothing settles | Integration | Not run |
| F-05 | Stock falls | Ask rises, clamped at 3x | Unit | Not run |
| F-05 | `day_tick` twice within 290 s | Second is a no-op | Unit | Not run |
| F-06 | Sell to merchant with empty purse | Refused, no deal signed; contract `MerchantPurseEmpty` | Unit + integration | Not run |
| F-07 | Settled deal | Appears in dashboard feed with explorer link within 10 s | E2E (Playwright) | Not run |
| F-08 | Fast-forward clicked | 7 days animate in 50-70 s | E2E | Not run |
| F-09 | Trades change ranking | Board updates within 30 s | Integration | Not run |
| F-10 | LLM timeout / invalid JSON | Fallback reply within 5 s | Unit | Not run |
| F-10 | `REPLAY_MODE=on` | Recorded reply used, no LLM call | Unit | Not run |
| F-11 (stretch) | List / buy / cancel | Escrow and atomic swap correct | Integration | Not run |
| F-12 (stretch) | Guest farming | 2nd guest from same IP in 10 min refused | Integration | Not run |
| Permissions | Non-owner `register_merchant` | Panics | Unit | Not run |
| Permissions | `/rbx/*` without / with bad / stale HMAC | 401 | Integration | Not run |
| Isolation | RemoteEvent with fake qty/good/far from NPC | Roblox server drops it | Manual (Studio) | Not run |
| Secrets | Grep repo, git history and web bundle for key patterns | No hits | Script | Not run |
| Policy | Grep `roblox/` for crypto/blockchain/NFT/token/wallet/NEAR/gas/transaction in user-facing strings | No hits | Script | Not run |

## Fixtures and environments
- Synthetic test users: `roblox:1`, `roblox:2`, `web:00000000-0000-0000-0000-000000000001`; three merchants with generated test keypairs in tests (never the deployed keys).
- External services: LLM mocked in unit/integration tests (fixed JSON replies, timeout, invalid JSON); chain mocked in backend unit tests; local sandbox for contract integration; testnet only for the smoke test and rehearsals.
- Reset/isolation: sandbox is fresh per test file; SQLite uses `:memory:` in tests; testnet contract can be redeployed to a fresh sub-account.

## Verified commands
- Unit/integration: Not configured (no project files yet)
- End-to-end: Not configured
- Build/type check: Not configured

## Release criteria
All "Must" rows above Passed (or a written, user-approved exception), eval pass rate >= 90% on 15 cases with 100% of prices in room, golden path rehearsed 5 times on testnet, secret and policy greps clean. Owner: nabil.

## Results
No executions yet. Every run will record: command, result, failures, untested limitations. Not run stays distinct from Passed.
