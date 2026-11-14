-- Off-chain game state (docs/DATABASE.md). Anything with value lives on chain.
CREATE TABLE IF NOT EXISTS player_profile (
  player_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL DEFAULT 0
) STRICT;

CREATE TABLE IF NOT EXISTS haggle_session (
  id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  merchant TEXT NOT NULL,
  rounds INTEGER NOT NULL DEFAULT 0,
  opened_at INTEGER NOT NULL,
  closed_at INTEGER
) STRICT;

CREATE TABLE IF NOT EXISTS chat_turn (
  id INTEGER PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES haggle_session(id),
  role TEXT NOT NULL CHECK (role IN ('player', 'merchant')),
  text TEXT NOT NULL,
  mood TEXT,
  source TEXT CHECK (source IN ('llm', 'fallback', 'replay')),
  reasoning TEXT,
  created_at INTEGER NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS deal (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES haggle_session(id),
  merchant TEXT NOT NULL,
  player_id TEXT NOT NULL,
  good TEXT NOT NULL,
  side TEXT NOT NULL,
  qty INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  nonce INTEGER NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('quoted', 'settling', 'settled', 'requoted', 'failed', 'expired')),
  tx_hash TEXT,
  error TEXT,
  created_at INTEGER NOT NULL
) STRICT;
CREATE INDEX IF NOT EXISTS deal_status_created ON deal(status, created_at);

CREATE TABLE IF NOT EXISTS patience (
  player_id TEXT NOT NULL,
  merchant TEXT NOT NULL,
  day INTEGER NOT NULL,
  points INTEGER NOT NULL DEFAULT 3,
  PRIMARY KEY (player_id, merchant, day)
) STRICT;

CREATE TABLE IF NOT EXISTS pending_gather (
  id INTEGER PRIMARY KEY,
  player_id TEXT NOT NULL,
  good TEXT NOT NULL,
  qty INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  batch_tx TEXT
) STRICT;
CREATE INDEX IF NOT EXISTS pending_gather_batch ON pending_gather(batch_tx, id);

CREATE TABLE IF NOT EXISTS price_point (
  merchant TEXT NOT NULL,
  ts INTEGER NOT NULL,
  ask INTEGER NOT NULL,
  bid INTEGER NOT NULL,
  stock INTEGER NOT NULL,
  purse INTEGER NOT NULL,
  PRIMARY KEY (merchant, ts)
) STRICT;

CREATE TABLE IF NOT EXISTS llm_cache (
  prompt_hash TEXT PRIMARY KEY,
  model TEXT NOT NULL,
  reply_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
) STRICT;

-- v2 (2026-11-11): one row per gather minigame; item/qty set on finish (also the catch log for stats).
CREATE TABLE IF NOT EXISTS gather_session (
  id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  node TEXT NOT NULL,
  roll_bp INTEGER NOT NULL,
  started_at INTEGER NOT NULL,
  closed_at INTEGER,
  item TEXT,
  qty INTEGER
) STRICT;
CREATE INDEX IF NOT EXISTS gather_session_player ON gather_session(player_id, started_at);

CREATE TABLE IF NOT EXISTS player_class (
  player_id TEXT PRIMARY KEY,
  class TEXT NOT NULL,
  changed_at INTEGER NOT NULL
) STRICT;

-- v2 price history per item (v1 price_point was per merchant).
CREATE TABLE IF NOT EXISTS item_price (
  item TEXT NOT NULL,
  ts INTEGER NOT NULL,
  ask INTEGER NOT NULL,
  bid INTEGER NOT NULL,
  stock INTEGER NOT NULL,
  purse INTEGER NOT NULL,
  PRIMARY KEY (item, ts)
) STRICT;

-- Guardrail: every LLM price the backend had to pull back into the pricing room.
CREATE TABLE IF NOT EXISTS guard_event (
  id INTEGER PRIMARY KEY,
  merchant TEXT NOT NULL,
  item TEXT NOT NULL,
  side TEXT NOT NULL,
  wanted REAL NOT NULL,
  lo INTEGER NOT NULL,
  hi INTEGER NOT NULL,
  sent INTEGER NOT NULL,
  created_at INTEGER NOT NULL
) STRICT;
