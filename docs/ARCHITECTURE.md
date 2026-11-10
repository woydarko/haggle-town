# Architecture

## System purpose
Haggle Town (see docs/PRD.md and docs/superpowers/specs/2026-11-10-haggle-town-design.md): a public Roblox game where players gather goods and haggle in chat with AI merchants. Economy state (balances of Coin/Wood/Fish/Iron, merchant stock and purses, deals) lives in one NEAR testnet contract; pricing rules live in one Rust file shared by the contract and a simulator. A Node backend is the only bridge: Roblox and the web dashboard talk to it; it talks to the LLM and signs transactions. Players never see the chain inside Roblox.

Constraints: solo, ~54 h build budget, deadline 2026-11-14 23:59 UTC, NEAR testnet only, NEAR AI Cloud $10 credits.

## Stack decisions
| Layer | Selected technology | Reason | Constraints |
| --- | --- | --- | --- |
| Game client | Roblox Studio + Luau, synced with Rojo 7.7.1 (`roblox/`) | User's chosen platform; Rojo keeps Luau in git | HttpService only from server Scripts; 500 req/min per server; no chain words in UI |
| Web frontend | React 18 + Vite + TypeScript (`web/`), uPlot for charts | Small, fast, known; uPlot is tiny and handles live series | Served as static files by the backend; no keys in bundle |
| Backend/API | Node 24 + TypeScript + Fastify (`server/`) | One service for Roblox API, web API, haggle agent, LLM proxy, tx relayer; Fastify JSON schemas validate input at the trust boundary | Single instance (in-memory per-signer tx queue) |
| Chain client | near-api-js (v7 line, exact version pinned at install) | Official JS SDK for signing and sending txs | API to be verified at install (signer-based API changed in v7) |
| Smart contract | Rust, near-sdk (5.x), built with cargo-near (`contract/`) | Mature NEAR toolchain; `env::ed25519_verify` for merchant signatures | Keep surface small; testnet only |
| Economy rules | Rust crate `economy` (`economy/src/pricing.rs`), no NEAR deps | One readable file used by contract and simulator; deterministic integer math | Integer Coin only; no floats in contract |
| Simulator | Rust bin `sim` (`sim/`) | Reuses `economy`; writes `web/public/sim/week.json` | Does not touch the chain |
| Database | On-chain contract state (economy) + `node:sqlite` file (off-chain game state) | Chain holds anything with value; SQLite holds sessions, chat, cache, history; `node:sqlite` needs no extra dependency | SQLite file on a Railway volume; loss is tolerable (no value) |
| LLM | NEAR AI Cloud, OpenAI-compatible `https://cloud-api.near.ai/v1` via `LLM_BASE_URL`/`LLM_MODEL` | Track ecosystem; TEE-verifiable models available | $10 credits; 4 s timeout; JSON output; replay mode |
| Authentication | Roblox: HMAC-SHA256 of timestamp+body with shared secret (Roblox Secrets store -> `HttpService:GetSecret`). Web dashboard: public read-only. Web game (stretch): guest id token | Players are identified by Roblox UserId; no wallets | HMAC secret never in client scripts |
| Hosting | Railway: one Node service (backend + static web) with a volume for SQLite; Roblox public experience; contract on NEAR testnet | One deploy, public URL Roblox can reach | Keep running until at least 2026-11-25 |

## System boundaries
- **Roblox client owns:** rendering, input, UI states (HUD, haggle panel, boards). Sends intents to the Roblox server via RemoteEvents. Trusts nothing it computes about balances.
- **Roblox server owns:** player session, gather cooldown display, rate limiting per player, forwarding intents to the backend with HMAC; it never holds chain keys.
- **Backend owns:** authentication (HMAC / guest token), validation, gather cooldown enforcement, haggle sessions, patience, calling the LLM, clamping prices into the room, merchant signing of deals, the per-signer tx queue, gather batching, the day tick timer, read models for the dashboard.
- **Contract owns (trust + settlement):** balances of all four NEP-245 tokens, player registration and the one-time 1000 Coin, merchant registry (account, good, public key, purse, stock), pricing room checks at settle, nonce/expiry replay protection, day tick burn, stall escrow (stretch). Access control: owner and game relayer roles.
- **External services own:** NEAR testnet RPC (fastnear primary, near.org fallback) - failure: retry with backoff, then "Market offline - your goods are safe"; NEAR AI Cloud - failure: rule-based reply; Roblox - hosting the experience.
- **Out of scope:** NEAR Intents, mainnet, player-owned NEAR accounts, NPC-to-NPC trading, Robux, indexer service (backend keeps its own history).

### On-chain vs off-chain
| On-chain (needs trust/settlement) | Off-chain (backend SQLite / memory) |
| --- | --- |
| Token balances (coin, wood, fish, iron) per holder | Haggle sessions, chat turns, patience counters |
| Merchant registry, purse, stock | LLM replay cache |
| Deal settlement + nonce set | Price/deal history for charts (also derivable from events) |
| Day tick (last tick timestamp, burn) | Gather cooldowns and the pending gather batch |
| Stall listings + escrow (stretch) | Guest ids (stretch), Roblox display names |

## Request and data flow
Golden path (haggle + accept):
1. Player types an offer in the Roblox haggle panel (client) -> RemoteEvent `Haggle` -> Roblox server Script.
2. Server Script POSTs `/rbx/haggle` with `X-Timestamp` and `X-Signature` (HMAC); backend rejects if the HMAC is wrong or the timestamp is older than 60 s.
3. Backend loads merchant state (cached `get_market` view, refreshed every 5 s and after each settle), computes the room with the same rules as `pricing.rs` (TS port checked against Rust test vectors), checks patience, builds the LLM prompt, calls the LLM (4 s timeout), parses JSON, clamps `counter_price` into the room, creates a deal {merchant, player, good, qty <= 10, unit_price, side, nonce, expires_at = now + 30 s} and stores it in the session. Returns line, mood, counter, patience, reasoning, deal id.
4. Player presses Accept -> `/rbx/accept` -> backend builds the canonical deal message `haggle:v1|<merchant>|<player>|<good>|<qty>|<unit_price>|<side>|<nonce>|<expires_at>`, signs it with the merchant's ed25519 key, and enqueues `settle_deal(deal, merchant_sig)` on the game signer queue.
5. Contract checks: caller == game; merchant registered; `ed25519_verify(sig, message, merchant_pubkey)`; nonce unused; `expires_at >= block_timestamp`; unit_price within the room computed from current stock/purse; buyer has funds/goods; moves balances atomically; emits NEP-297 `mt_transfer` events; records nonce.
6. Backend gets the outcome: success -> updates read model, feed, history, returns new balances; `PriceOutOfRoom` -> re-quotes and returns `requoted` with the new counter; other failure -> `failed`, nothing changed. Roblox UI shows "Deal done" / "Prices just moved..." / "Deal failed, try again".

Gather: `/rbx/gather` -> backend checks cooldown, credits a pending +1 (returned immediately) -> every ~10 s one `gather_batch` tx mints all pending entries -> confirmed balances replace pending ones.
Day tick: backend timer every 5 min -> `day_tick()`; contract ignores calls earlier than 290 s after the last tick.

## Interfaces
### Contract (`contract/`, NEAR testnet)
Token ids: `"coin"`, `"wood"`, `"fish"`, `"iron"`. Holders are strings: NEAR account ids (merchants, owner) and player ids `roblox:<UserId>` / `web:<uuid>`.
| Method | Kind | Caller | Purpose / errors |
| --- | --- | --- | --- |
| `new(owner, game)` | init | deployer | set roles |
| `register_merchant(account_id, good, public_key, coin, stock, target)` | change | owner | create merchant; error if exists |
| `register_player(player_id)` | change | game | grant 1000 coin once; no-op if exists |
| `gather_batch(entries: [{player_id, good, qty}])` | change | game | mint goods; qty per entry <= 20; max 100 entries |
| `settle_deal(deal, merchant_sig)` | change | game | see flow step 5; errors `BadSignature`, `NonceUsed`, `Expired`, `PriceOutOfRoom`, `InsufficientFunds`, `InsufficientGoods`, `MerchantPurseEmpty` |
| `day_tick()` | change | game | burn 10% stock per merchant if >= 290 s since last tick; else no-op |
| `list_item / buy_listing / cancel_listing` | change | game | stretch F-11 |
| `get_market()` | view | any | merchants with stock, purse, ask, bid, floor, ceiling, last tick |
| `get_player(player_id)` | view | any | balances of all four tokens |
| `mt_balance_of(account_id, token_id)`, `mt_batch_balance_of(account_id, token_ids)` | view | any | NEP-245 views for account holders |
| `mt_transfer(receiver_id, token_id, amount, ...)` | change | NEAR account holder (1 yocto) | NEP-245 transfer between NEAR accounts (merchants/owner); players are not NEAR accounts |
Events: NEP-297 `nep245` standard `mt_mint`, `mt_burn`, `mt_transfer`.

### Backend HTTP (`server/`)
Roblox routes (HMAC required):
- `POST /rbx/join` {userId, name} -> {balances}
- `POST /rbx/gather` {userId, good} -> {balances, pending, cooldownMs} | 429 {error:"cooldown"}
- `POST /rbx/haggle` {userId, merchant, message} -> {line, mood, patience, reasoning, counter:{side, good, qty, unitPrice, total, dealId, expiresAt}} | {refused:true, line, until}
- `POST /rbx/accept` {userId, dealId} -> {status:"settled", balances, txHash} | {status:"requoted", counter, line} | {status:"failed", reason}
- `GET /rbx/state?userId=` -> {balances, board, leaderboard}
Public routes (read-only, no auth): `GET /api/config`, `/api/market`, `/api/feed`, `/api/leaderboard`, `/api/history`, static `/` (dashboard) and `/sim/week.json`.
Stretch web game routes (guest token): `POST /api/guest`, `/api/gather`, `/api/haggle`, `/api/accept`.
Error shape: `{error: string_code, message: string}` with 400 validation, 401 auth, 409 conflict (deal expired/used), 429 rate limit, 502 chain/LLM upstream.

### Jobs
- Gather flush: every 10 s, one `gather_batch`; idempotent per pending entry id; failed batch is retried, entries stay pending.
- Day tick: every 5 min; contract enforces spacing, so a duplicate call is harmless.
- Market cache refresh: every 5 s + after each settle.

## Project structure
```
Cargo.toml          Rust workspace: contract, economy, sim
economy/            pricing.rs (+ unit tests, test vectors JSON for the TS port)
contract/           NEAR contract (lib.rs, nep245.rs, deals.rs, stalls.rs) + integration tests
sim/                fast-forward simulator -> web/public/sim/week.json
server/             Node 24 TS backend (src/routes, src/haggle, src/chain, src/llm, src/db)
web/                React + Vite dashboard (+ stretch web game)
roblox/             Rojo project: default.project.json, src/server, src/client, src/shared
scripts/            deploy + seed scripts (near-cli-rs)
docs/               PRD, DESIGN_SYSTEM, ARCHITECTURE, DATABASE, SECURITY, CODE_STYLE, TESTING, hackathon/
```

## Operations
- Environments: local (backend on localhost + cloudflared tunnel when Roblox live servers must reach it; Studio Play can use the Railway URL too), testnet contract shared by local and Railway, production = Railway service + public Roblox experience.
- Configuration: env vars only (names in SECURITY.md); `.env.example` committed.
- Deployment: contract via `cargo near build` + `near contract deploy` (scripts/deploy.sh); backend via Railway GitHub deploy; Roblox via Studio publish (Rojo build -> Studio). Walking skeleton deployed by ~40% of build (planned 2026-11-12 ~09:00 +0700).
- Rollback: backend = Railway redeploy of previous build; contract = redeploy to a fresh sub-account and re-seed (no state migrations during the hackathon); Roblox = revert published version in Creator Dashboard.
- Logs: backend structured JSON logs (Fastify/pino) to stdout, secrets redacted; dashboard deal feed doubles as an audit trail with explorer links.
- Scale limits: single backend instance; one game signer queue (optionally several access keys for parallel nonces); Roblox 500 HTTP req/min per server -> Roblox server batches state polls (one `/rbx/state` per player per 5 s max).

## Decisions and unknowns
Confirmed by user: Roblox is the main product and is published publicly; testnet only; Rust contract; NEAR AI Cloud; Railway + web dashboard; stalls and web game are stretch.
Builder's calls (proposals, approve with the design): Fastify, uPlot, `node:sqlite`, canonical deal string + ed25519 signature, gather batching, cache refresh intervals, player ids as strings.
Unknowns:
- near-api-js v7 exact signing API - owner: builder, before chain module.
- cargo-near not installed yet - owner: builder, before contract build.
- Which LLM model passes the eval - owner: builder, before haggle done.
- Roblox Secrets store availability for published experience - owner: builder, before Roblox server wiring (fallback: ServerStorage config script not replicated to clients).
