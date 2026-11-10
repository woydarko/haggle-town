# Security

## Assets and trust boundaries
- Protected data and assets: chain keys (owner, game relayer, 3 merchant keys), HMAC secret, LLM API key; integrity of balances, merchant purses and deals; the "no chain words inside Roblox" rule (policy asset).
- Trusted inputs: the Roblox game server (it sets UserId and signs with HMAC); the contract's own state.
- Untrusted inputs: everything a player types (haggle messages go to the LLM), LLM output, RemoteEvent payloads from Roblox clients, public web requests, RPC responses (checked for errors), the stretch web game guest.
- Threats relevant to this product:
  1. Prompt injection: player talks the merchant into a free or out-of-range deal.
  2. Forged Roblox requests to the backend (someone calls `/rbx/*` directly).
  3. Client exploits in Roblox (fire RemoteEvents with fake goods, qty, prices).
  4. Replay of a signed deal; accepting another player's deal.
  5. Gather farming / bots minting goods; guest farming 100 Coin (stretch web).
  6. Leaked merchant key signing unfair deals; leaked game key.
  7. Draining merchants until the economy dies.
  8. LLM cost blow-up from spam.
  9. XSS via chat lines shown on the web dashboard.

## Authentication and authorization
- Identity: Roblox account (UserId from the Roblox server, never from the client payload). Web dashboard is public read-only. Stretch web game: guest id token issued by `/api/guest` (random UUID, stored in localStorage), 1 new guest per IP per 10 min.
- Roblox -> backend: HMAC-SHA256 over `timestamp + "." + body`, headers `X-Timestamp`, `X-Signature`; reject if timestamp skew > 60 s or signature mismatch (constant-time compare).
- Roles and permissions:
| Action | Player (via Roblox server) | Backend game key | Merchant key | Owner key | Public |
| --- | --- | --- | --- | --- | --- |
| Register player / grant 100 Coin | request | call `register_player` | - | - | - |
| Gather | request | call `gather_batch` | - | - | - |
| Haggle / quote | request | compute + sign quote | sign deal message | - | - |
| Settle deal | accept own deal only | call `settle_deal` | signature required | - | - |
| Day tick | - | call `day_tick` | - | - | - |
| Register merchant | - | - | - | `register_merchant` | - |
| Read market, feed, leaderboard | yes | yes | yes | yes | yes |
- Contract checks: `predecessor_account_id == game` for game methods, `== owner` for owner methods; `settle_deal` additionally verifies the merchant's ed25519 signature over the canonical deal string, nonce unused, not expired, price inside the room, balances sufficient.
- Ownership checks (backend): a deal can be accepted only by `deal.player_id`; a session belongs to one player; quantities and goods are re-validated server-side, never taken from client UI state.
- Recovery and revocation: rotate a leaked key by adding a new access key and deleting the old one (near-cli-rs), then update `*_PRIVATE_KEY` env and the merchant's registered public key (owner call; add `update_merchant_key` if needed). Rotate HMAC secret in Roblox Secrets + backend env together.

## Secrets and configuration
- Secret names only: `GAME_ACCOUNT_ID`, `GAME_PRIVATE_KEY`, `WOODCUTTER_PRIVATE_KEY`, `FISHMONGER_PRIVATE_KEY`, `SMITH_PRIVATE_KEY`, `RBX_HMAC_SECRET`, `LLM_API_KEY`. Non-secret config: `NEAR_NETWORK`, `NEAR_RPC_URL`, `NEAR_RPC_FALLBACK_URL`, `CONTRACT_ID`, `LLM_BASE_URL`, `LLM_MODEL`, `REPLAY_MODE`, `DB_PATH`, `PORT`, `DAY_LENGTH_MS`.
- Storage and rotation: local `.env` (gitignored) and Railway variables; Roblox HMAC secret in the experience's Secrets store, read only in server Scripts via `HttpService:GetSecret`; owner key in the near-cli-rs keychain on the dev machine. All keys are testnet burners. Owner: nabil.
- Client exposure: nothing secret in Roblox client scripts, `ReplicatedStorage`, or the web bundle; `/api/config` returns only contract id, network, explorer base URL.

## Input and output handling
- Validation: Fastify JSON schemas on every route (types, enums, lengths, ranges per DATABASE.md "Data validation"); Roblox server re-validates RemoteEvent args (types, ranges, distance to the NPC/node) before forwarding.
- Prompt injection: the LLM only proposes text and a number; the backend clamps the number into the room from `pricing.rs`; the contract rejects anything outside the room; the system prompt contains no secrets; the LLM has no tools and cannot trigger transactions; player text is passed as quoted user content with a length cap; merchant lines are filtered through Roblox `TextService:FilterStringAsync` before showing to players (also required by Roblox for user-influenced text).
- Injection/XSS: React escapes text by default; no `dangerouslySetInnerHTML`; SQLite via prepared statements only.
- Upload restrictions: no uploads.
- Rate limits/abuse: gather cooldowns enforced server-side (Wood 3 s, Fish 6 s, Iron 10 s, proposal); haggle max 1 message per 2 s per player and 5 rounds per session; patience system; LLM max 150 output tokens and response cache; `/api/*` 60 req/min per IP; guest creation 1 per IP per 10 min; contract caps qty per gather entry (20) and per deal (10); merchant cannot buy beyond its purse.

## Privacy
- Data collected and purpose: Roblox UserId and display name (identity, leaderboard), chat text with merchants (gameplay, public feed, replay), deals (economy). No email, no real names, no payments, no location.
- Retention, deletion, access: see DATABASE.md; SQLite purged after 2026-12-31; on-chain data is public and permanent (only ids, numbers, no chat text on chain).
- Logging redaction: never log private keys, HMAC secret, `LLM_API_KEY`, full request headers; chat text logged only at debug level locally.

## Dependencies and deployment
- Dependency review: add only packages listed in ARCHITECTURE.md; pin versions via lockfiles (`Cargo.lock`, `package-lock.json`); `npm audit` and `cargo audit` (if installed) before submission.
- Environment separation: local and Railway share the testnet contract; no mainnet keys exist anywhere in this project.
- Security-sensitive change review: contract changes and anything touching keys, HMAC or the pricing room go through `requesting-code-review` plus the web3 audit gate (x-ray) in Phase 5. Owner: nabil.

## Verification
Tests listed in TESTING.md: permission denial (non-game caller, non-owner caller), bad merchant signature, replayed nonce, expired deal, price outside room, accepting another player's deal, HMAC missing/invalid/stale, RemoteEvent with bad qty/good/distance, prompt-injection eval cases, secret scan of repo and web bundle.

Residual risks (owner: nabil):
- Game relayer key is a single point of trust for all players (custodial design); compromise lets an attacker gather-mint and settle within the pricing room.
- Merchant keys and game key live in the same backend process.
- Roblox moderation could still flag the experience despite no chain wording.
- AI audit (x-ray) only; no professional audit.
- This document does not establish regulatory compliance.
