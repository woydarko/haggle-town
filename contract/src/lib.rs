//! Haggle Town market contract: NEP-245 balances for coin/wood/fish/iron, merchants with
//! their own purse and stock, players (game-relayed ids), gathering, signed deals, day tick.
//! Pricing rules live in the shared `economy` crate (economy/src/pricing.rs).

use economy::pricing::{self, Good, PLAYER_GRANT};
use near_sdk::json_types::{U128, U64};
use near_sdk::store::{IterableMap, LookupMap, LookupSet};
use near_sdk::{env, near, AccountId, BorshStorageKey, PanicOnDefault, PublicKey};

mod nep245;

pub const TOKENS: [&str; 4] = ["coin", "wood", "fish", "iron"];
const MAX_BATCH: usize = 100;
const MAX_GATHER_QTY: u32 = 20;

#[derive(BorshStorageKey)]
#[near]
enum Key {
    Balances,
    Players,
    Merchants,
    Nonces,
}

#[near(serializers = [borsh])]
pub struct Merchant {
    pub good: String,
    pub public_key: PublicKey,
    pub target: u32,
}

#[near(serializers = [json])]
pub struct GatherEntry {
    pub player_id: String,
    pub good: String,
    pub qty: u32,
}

#[near(serializers = [json])]
#[derive(Debug, PartialEq)]
pub struct PlayerView {
    pub coin: U128,
    pub wood: U128,
    pub fish: U128,
    pub iron: U128,
}

#[near(serializers = [json])]
pub struct MerchantView {
    pub account_id: AccountId,
    pub good: String,
    pub stock: u32,
    pub purse: U128,
    pub target: u32,
    pub ask: U128,
    pub bid: U128,
    pub floor: U128,
    pub ceiling_one: Option<U128>,
    pub day: u32,
    pub last_tick_ns: U64,
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Contract {
    owner: AccountId,
    game: AccountId,
    balances: LookupMap<(String, String), u128>,
    players: LookupSet<String>,
    merchants: IterableMap<AccountId, Merchant>,
    used_nonces: LookupSet<u64>,
    last_tick_ns: u64,
    day: u32,
}

/// `roblox:<1-20 digits>` or `web:<36 chars of hex and dashes>`.
pub fn valid_player_id(id: &str) -> bool {
    if let Some(n) = id.strip_prefix("roblox:") {
        return (1..=20).contains(&n.len()) && n.bytes().all(|b| b.is_ascii_digit());
    }
    if let Some(u) = id.strip_prefix("web:") {
        return u.len() == 36 && u.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-');
    }
    false
}

pub(crate) fn good_of(s: &str) -> Good {
    Good::from_str(s).unwrap_or_else(|| env::panic_str("BadGood"))
}

#[near]
impl Contract {
    #[init]
    pub fn new(owner: AccountId, game: AccountId) -> Self {
        Self {
            owner,
            game,
            balances: LookupMap::new(Key::Balances),
            players: LookupSet::new(Key::Players),
            merchants: IterableMap::new(Key::Merchants),
            used_nonces: LookupSet::new(Key::Nonces),
            last_tick_ns: env::block_timestamp(),
            day: 0,
        }
    }

    pub fn register_merchant(&mut self, account_id: AccountId, good: String, public_key: PublicKey, coin: U128, stock: u32, target: u32) {
        self.assert_owner();
        good_of(&good);
        if self.merchants.contains_key(&account_id) {
            env::panic_str("MerchantExists");
        }
        self.add(account_id.as_str(), "coin", coin.0);
        self.add(account_id.as_str(), &good, stock as u128);
        nep245::emit_mint(account_id.as_str(), &["coin", &good], &[coin.0, stock as u128]);
        self.merchants.insert(account_id, Merchant { good, public_key, target });
    }

    pub fn register_player(&mut self, player_id: String) {
        self.assert_game();
        if !valid_player_id(&player_id) {
            env::panic_str("BadPlayerId");
        }
        if self.players.insert(player_id.clone()) {
            self.add(&player_id, "coin", PLAYER_GRANT);
            nep245::emit_mint(&player_id, &["coin"], &[PLAYER_GRANT]);
        }
    }

    pub fn gather_batch(&mut self, entries: Vec<GatherEntry>) {
        self.assert_game();
        if entries.len() > MAX_BATCH {
            env::panic_str("BatchTooLarge");
        }
        for e in &entries {
            if e.qty > MAX_GATHER_QTY {
                env::panic_str("QtyTooLarge");
            }
            good_of(&e.good);
            if !self.players.contains(&e.player_id) {
                env::panic_str("UnknownPlayer");
            }
            self.add(&e.player_id, &e.good, e.qty as u128);
            nep245::emit_mint(&e.player_id, &[&e.good], &[e.qty as u128]);
        }
    }

    pub fn get_market(&self) -> Vec<MerchantView> {
        self.merchants
            .iter()
            .map(|(id, m)| {
                let g = good_of(&m.good);
                let stock = self.stock_of(id.as_str(), &m.good);
                let purse = self.bal(id.as_str(), "coin");
                let (floor, ask) = pricing::buy_room(g, stock, m.target);
                MerchantView {
                    account_id: id.clone(),
                    good: m.good.clone(),
                    stock,
                    purse: U128(purse),
                    target: m.target,
                    ask: U128(ask),
                    bid: U128(pricing::bid(g, stock, m.target)),
                    floor: U128(floor),
                    ceiling_one: pricing::sell_room(g, stock, m.target, purse, 1).map(|(_, c)| U128(c)),
                    day: self.day,
                    last_tick_ns: U64(self.last_tick_ns),
                }
            })
            .collect()
    }

    pub fn get_player(&self, player_id: String) -> Option<PlayerView> {
        if !self.players.contains(&player_id) {
            return None;
        }
        let b = |t| U128(self.bal(&player_id, t));
        Some(PlayerView { coin: b("coin"), wood: b("wood"), fish: b("fish"), iron: b("iron") })
    }
}

impl Contract {
    pub(crate) fn bal(&self, holder: &str, token: &str) -> u128 {
        self.balances.get(&(holder.to_string(), token.to_string())).copied().unwrap_or(0)
    }

    pub(crate) fn stock_of(&self, holder: &str, token: &str) -> u32 {
        self.bal(holder, token).min(u32::MAX as u128) as u32
    }

    pub(crate) fn add(&mut self, holder: &str, token: &str, amt: u128) {
        let v = self.bal(holder, token) + amt;
        self.balances.insert((holder.to_string(), token.to_string()), v);
    }

    pub(crate) fn sub(&mut self, holder: &str, token: &str, amt: u128) {
        let cur = self.bal(holder, token);
        if cur < amt {
            env::panic_str(if token == "coin" { "InsufficientFunds" } else { "InsufficientGoods" });
        }
        self.balances.insert((holder.to_string(), token.to_string()), cur - amt);
    }

    pub(crate) fn assert_game(&self) {
        if env::predecessor_account_id() != self.game {
            env::panic_str("NotGame");
        }
    }

    pub(crate) fn assert_owner(&self) {
        if env::predecessor_account_id() != self.owner {
            env::panic_str("NotOwner");
        }
    }
}

#[cfg(test)]
mod tests;
