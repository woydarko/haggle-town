# Database

## Storage model
- Database/provider: (1) NEAR testnet contract state for everything with value; (2) `node:sqlite` file on the backend (Railway volume, path from `DB_PATH`) for off-chain game state. See ARCHITECTURE.md "On-chain vs off-chain".
- Ownership model: single game world. Players are identified by `roblox:<UserId>` (or `web:<uuid>` for the stretch web game). Merchants are NEAR sub-accounts.
- Data classification: public - balances, merchant state, deals, prices (on a public chain). Internal - chat text, patience, sessions. Personal - Roblox UserId and display name (public on Roblox already); no emails, no real names, no payment data.

## Entities
| Entity | Purpose | Owner | Retention |
| --- | --- | --- | --- |
| Holder balance (on-chain) | Coin/Wood/Fish/Iron per holder | Contract | Life of the testnet contract |
| Player (on-chain) | Registered flag, one-time grant | Contract | Life of contract |
| Merchant (on-chain) | Account, good, public key, target (purse/stock are its balances) | Contract (owner registers) | Life of contract |
| Used nonce (on-chain) | Replay protection for deals | Contract | Life of contract (pruning post-hackathon) |
| Market clock (on-chain) | Last day tick timestamp, day number | Contract | Life of contract |
| Listing (on-chain, stretch) | Stall escrow | Contract | Until bought/cancelled |
| player_profile (SQLite) | UserId -> display name, first seen | Backend | Until 2026-12-31, then deleted |
| haggle_session (SQLite) | Open haggle with a merchant | Backend | 24 h |
| chat_turn (SQLite) | Player message + merchant line (feed + replay) | Backend | Until 2026-12-31 |
| deal (SQLite) | Quote and its settle outcome + tx hash | Backend | Until 2026-12-31 |
| patience (SQLite) | Patience per player/merchant/day | Backend | 2 game days |
| pending_gather (SQLite) | Gathers waiting for the next batch | Backend | Deleted when minted |
| price_point (SQLite) | Ask/bid/stock per merchant per minute for charts | Backend | Until 2026-12-31 |
| llm_cache (SQLite) | Prompt hash -> LLM JSON reply (replay mode) | Backend | Until 2026-12-31 |

## Schema
On-chain (near-sdk collections, borsh):
- `owner: AccountId`, `game: AccountId`
- `balances: LookupMap<(String holder, String token_id), u128>` - token_id in {coin, wood, fish, iron}
- `players: LookupSet<String>` - registered player ids
- `merchants: IterableMap<AccountId, Merchant>`; `Merchant { good: String, public_key: PublicKey (ed25519), target: u32 }`
- `used_nonces: LookupSet<u64>`
- `last_tick_ns: u64`, `day: u32`
- `listings: IterableMap<u64, Listing>` (stretch); `Listing { seller: String, good: String, qty: u32, unit_price: u128 }`
- `Deal` (call argument, not stored): `{ merchant: AccountId, player: String, good: String, qty: u32 (1..=10), unit_price: u128, side: "buy"|"sell" (player's view), nonce: u64, expires_at_ns: u64 }`

SQLite (tables `STRICT`, timestamps INTEGER unix ms):
- `player_profile(player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, first_seen INTEGER NOT NULL)`
- `haggle_session(id TEXT PRIMARY KEY, player_id TEXT NOT NULL, merchant TEXT NOT NULL, rounds INTEGER NOT NULL DEFAULT 0, opened_at INTEGER NOT NULL, closed_at INTEGER)`
- `chat_turn(id INTEGER PRIMARY KEY, session_id TEXT NOT NULL REFERENCES haggle_session(id), role TEXT NOT NULL CHECK(role IN ('player','merchant')), text TEXT NOT NULL, mood TEXT, source TEXT CHECK(source IN ('llm','fallback','replay')), created_at INTEGER NOT NULL)`
- `deal(id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES haggle_session(id), merchant TEXT NOT NULL, player_id TEXT NOT NULL, good TEXT NOT NULL, side TEXT NOT NULL, qty INTEGER NOT NULL, unit_price INTEGER NOT NULL, nonce INTEGER NOT NULL UNIQUE, expires_at INTEGER NOT NULL, status TEXT NOT NULL CHECK(status IN ('quoted','settling','settled','requoted','failed','expired')), tx_hash TEXT, error TEXT, created_at INTEGER NOT NULL)`
- `patience(player_id TEXT NOT NULL, merchant TEXT NOT NULL, day INTEGER NOT NULL, points INTEGER NOT NULL DEFAULT 3, PRIMARY KEY(player_id, merchant, day))`
- `pending_gather(id INTEGER PRIMARY KEY, player_id TEXT NOT NULL, good TEXT NOT NULL, qty INTEGER NOT NULL, created_at INTEGER NOT NULL, batch_tx TEXT)`
- `price_point(merchant TEXT NOT NULL, ts INTEGER NOT NULL, ask INTEGER NOT NULL, bid INTEGER NOT NULL, stock INTEGER NOT NULL, purse INTEGER NOT NULL, PRIMARY KEY(merchant, ts))`
- `llm_cache(prompt_hash TEXT PRIMARY KEY, model TEXT NOT NULL, reply_json TEXT NOT NULL, created_at INTEGER NOT NULL)`

## Relationships
- A holder has 0..4 balances (one per token id).
- A merchant has exactly one good; its stock and purse are its balances.
- A haggle_session has many chat_turns and many deals; a deal belongs to one session.
- A SQLite deal maps to at most one on-chain settle (by nonce).
- Delete/update behavior: no cascades on chain; SQLite rows deleted only by the retention cleanup script; chat_turn and deal deleted with their session.

## Access rules
- On-chain: views public. `register_merchant` owner only. `register_player`, `gather_batch`, `settle_deal`, `day_tick`, stall methods game relayer only (`predecessor_account_id == game`), checked in the contract. `mt_transfer` only moves the caller's own balance.
- SQLite: only the backend process reads/writes. Public dashboard routes expose the aggregated feed (display name, merchant, good, qty, price, tx hash, merchant line), never secrets.
- Isolation: a Roblox request acts only for the `userId` it carries and only with a valid HMAC (Roblox server is trusted for UserId); a player can accept only deals where `deal.player_id` equals the caller.

## Queries and indexes
- Feed: `deal WHERE status='settled' ORDER BY created_at DESC LIMIT 50` -> index `deal(status, created_at)`.
- Chart: `price_point WHERE merchant=? AND ts>=? ORDER BY ts` -> primary key.
- Patience lookup: primary key.
- Pending gathers: `pending_gather WHERE batch_tx IS NULL ORDER BY id LIMIT 100` -> index `pending_gather(batch_tx, id)`.
- Leaderboard: computed in memory from `get_market` + balances of recently active players (cached 30 s).

## Migrations and seed data
- Migration tool: `server/src/db/schema.sql` applied with `CREATE TABLE IF NOT EXISTS` at boot; hackathon changes add tables/columns only. Contract: no migrations; a breaking change redeploys to a fresh sub-account and re-seeds.
- Seed data (synthetic): 3 merchants (Woodcutter/wood, Fishmonger/fish, Smith/iron), each 1000 coin and stock = target 100, via `scripts/seed.sh`. Demo players: Roblox test accounts or `web:demo-*` ids.
- Rollback/backups: SQLite can be deleted and rebuilt (history lost, no value lost); on-chain state is the source of truth for balances.

## Data validation
- player_id: `^roblox:[0-9]{1,20}$` or `^web:[0-9a-f-]{36}$`.
- good: wood, fish, iron; token_id: coin or a good.
- qty: integer 1..=10 per deal, 1..=20 per gather entry; unit_price: integer >= 1 and within the room.
- haggle message: 1..=200 chars, trimmed, control characters stripped.
- Failures return the ARCHITECTURE.md error shape; the contract panics with the named error and changes nothing.
