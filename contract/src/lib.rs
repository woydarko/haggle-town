//! Haggle Town market contract v2: NEP-245 balances for coin and 12 tiered items, merchants per
//! category with per-item stock and their own purse, players with a class, gathering, signed deals,
//! day tick. Pricing and drop rules live in the shared `economy` crate (economy/src/pricing.rs).

use economy::pricing::{self, Category, Item, Tier, PLAYER_GRANT, TOOL_PRICE};
use near_sdk::json_types::{U128, U64};
use near_sdk::store::{IterableMap, LookupMap, LookupSet};
use near_sdk::{env, near, AccountId, BorshStorageKey, PanicOnDefault, PublicKey};
use std::collections::BTreeMap;

mod deals;
mod nep245;
pub use deals::{deal_message, Deal, SettleResult};

const MAX_BATCH: usize = 100;
const MAX_GATHER_QTY: u32 = 20;
const MAX_USE: usize = 4;
pub const CLASS_SWITCH_FEE: u128 = 100;

#[derive(BorshStorageKey)]
#[near]
enum Key {
    Balances,
    Players,
    Merchants,
    Nonces,
    Classes,
}

#[near(serializers = [borsh])]
pub struct Merchant {
    pub category: String,
    pub public_key: PublicKey,
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
    pub class: Option<String>,
    pub balances: BTreeMap<String, U128>,
}

#[near(serializers = [json])]
pub struct ItemView {
    pub merchant: AccountId,
    pub category: String,
    pub item: String,
    pub tier: String,
    pub stock: u32,
    pub purse: U128,
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
    classes: LookupMap<String, String>,
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

pub(crate) fn item_of(s: &str) -> Item {
    Item::from_id(s).unwrap_or_else(|| env::panic_str("BadGood"))
}

pub(crate) fn is_token(t: &str) -> bool {
    t == "coin" || Item::from_id(t).is_some()
}

pub(crate) fn token_ids() -> Vec<&'static str> {
    std::iter::once("coin").chain(Item::all().iter().map(|i| i.id())).collect()
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
            classes: LookupMap::new(Key::Classes),
        }
    }

    /// Creates a merchant for one category with its purse and every item of that category at target stock.
    pub fn register_merchant(&mut self, account_id: AccountId, category: String, public_key: PublicKey, coin: U128) {
        self.assert_owner();
        let cat = Category::from_str(&category).unwrap_or_else(|| env::panic_str("BadCategory"));
        if self.merchants.contains_key(&account_id) {
            env::panic_str("MerchantExists");
        }
        self.add(account_id.as_str(), "coin", coin.0);
        nep245::emit_mint(account_id.as_str(), &["coin"], &[coin.0]);
        for tier in Tier::ALL {
            let item = Item::of(cat, tier);
            self.add(account_id.as_str(), item.id(), item.target() as u128);
            nep245::emit_mint(account_id.as_str(), &[item.id()], &[item.target() as u128]);
        }
        self.merchants.insert(account_id, Merchant { category, public_key });
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

    /// First pick is free; switching to another class burns 100 coin. Cooldown is enforced off-chain.
    pub fn set_class(&mut self, player_id: String, class: String) {
        self.assert_game();
        if Category::of_class(&class).is_none() {
            env::panic_str("BadClass");
        }
        if !self.players.contains(&player_id) {
            env::panic_str("UnknownPlayer");
        }
        match self.classes.get(&player_id) {
            Some(current) if *current == class => return,
            Some(_) => {
                self.sub(&player_id, "coin", CLASS_SWITCH_FEE);
                nep245::emit_burn(&player_id, &["coin"], &[CLASS_SWITCH_FEE]);
            }
            None => {}
        }
        self.classes.insert(player_id, class);
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
            item_of(&e.good);
            if !self.players.contains(&e.player_id) {
                env::panic_str("UnknownPlayer");
            }
            self.add(&e.player_id, &e.good, e.qty as u128);
            nep245::emit_mint(&e.player_id, &[&e.good], &[e.qty as u128]);
        }
    }

    /// Buys a gathering tool for `category`: TOOL_PRICE coin goes from the player to that trade's merchant.
    /// Relayer only; which tools a player owns is kept off-chain by the game.
    pub fn buy_tool(&mut self, player_id: String, category: String) {
        self.assert_game();
        if !self.players.contains(&player_id) {
            env::panic_str("UnknownPlayer");
        }
        let cat = Category::from_str(&category).unwrap_or_else(|| env::panic_str("BadCategory"));
        let merchant = self
            .merchants
            .iter()
            .find(|(_, m)| m.category == cat.as_str())
            .map(|(a, _)| a.clone())
            .unwrap_or_else(|| env::panic_str("UnknownMerchant"));
        self.sub(&player_id, "coin", TOOL_PRICE);
        self.add(merchant.as_str(), "coin", TOOL_PRICE);
        nep245::emit_transfer(&player_id, merchant.as_str(), &["coin"], &[TOOL_PRICE]);
    }

    /// Consumes a player's goods (forging a tool). Relayer only, like set_class's fee; the goods are burned.
    pub fn use_items(&mut self, player_id: String, items: Vec<(String, U128)>) {
        self.assert_game();
        if !self.players.contains(&player_id) {
            env::panic_str("UnknownPlayer");
        }
        if items.is_empty() || items.len() > MAX_USE {
            env::panic_str("BadItems");
        }
        for (good, amount) in &items {
            item_of(good);
            if amount.0 == 0 || amount.0 > MAX_GATHER_QTY as u128 {
                env::panic_str("BadItems");
            }
            self.sub(&player_id, good, amount.0);
            nep245::emit_burn(&player_id, &[good.as_str()], &[amount.0]);
        }
    }

    pub fn get_market(&self) -> Vec<ItemView> {
        let mut out = Vec::new();
        for (id, m) in self.merchants.iter() {
            let Some(cat) = Category::from_str(&m.category) else { continue };
            let purse = self.bal(id.as_str(), "coin");
            for tier in Tier::ALL {
                let item = Item::of(cat, tier);
                let stock = self.stock_of(id.as_str(), item.id());
                let (floor, ask) = pricing::buy_room(item, stock);
                out.push(ItemView {
                    merchant: id.clone(),
                    category: m.category.clone(),
                    item: item.id().to_string(),
                    tier: tier.as_str().to_string(),
                    stock,
                    purse: U128(purse),
                    ask: U128(ask),
                    bid: U128(pricing::bid(item, stock)),
                    floor: U128(floor),
                    ceiling_one: pricing::sell_room(item, stock, purse, 1, false).map(|(_, c)| U128(c)),
                    day: self.day,
                    last_tick_ns: U64(self.last_tick_ns),
                });
            }
        }
        out
    }

    pub fn get_player(&self, player_id: String) -> Option<PlayerView> {
        if !self.players.contains(&player_id) {
            return None;
        }
        let balances = token_ids().into_iter().map(|t| (t.to_string(), U128(self.bal(&player_id, t)))).collect();
        Some(PlayerView { class: self.classes.get(&player_id).cloned(), balances })
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

    pub(crate) fn is_specialist(&self, player_id: &str, cat: Category) -> bool {
        self.classes.get(player_id).and_then(|c| Category::of_class(c)) == Some(cat)
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
