//! Backer coin: an NEP-141 memecoin for one Haggle Town merchant ($WOOD, $FISH or $SMITH).
//! The mechanic lives here, not in a backend: anyone may call `tick()`; it reads the market contract's
//! `get_market`, values the merchant (purse + stock x bid, economy/src/coin.rs) and, once per market day,
//! rebases every holder by the change in that worth, capped at `cap_bp`. Every parameter is set in `new()`;
//! the contract has no owner and no method that changes them.
use economy::coin;
use near_sdk::json_types::U128;
use near_sdk::store::{LookupMap, Vector};
use near_sdk::{env, near, require, AccountId, BorshStorageKey, Gas, NearToken, PanicOnDefault, Promise, PromiseError, PromiseOrValue};

/// Attached to `back()`: pays the holder's storage and makes each extra identity cost something (sybil brake).
pub const BACK_DEPOSIT: NearToken = NearToken::from_millinear(10);
/// NEP-145 registration without a claim (e.g. a wallet that only receives transfers).
pub const STORAGE_DEPOSIT: NearToken = NearToken::from_micronear(1_250);
const VIEW_GAS: Gas = Gas::from_tgas(15);
const CALLBACK_GAS: Gas = Gas::from_tgas(20);
const TRANSFER_CALL_GAS: Gas = Gas::from_tgas(30);
const RESOLVE_GAS: Gas = Gas::from_tgas(10);

#[derive(BorshStorageKey)]
#[near]
enum Key {
    Shares,
    Rebases,
}

/// The part of the market contract's `get_market` rows the coin needs (extra fields are ignored).
#[near(serializers = [json])]
#[derive(Clone)]
pub struct MarketRow {
    pub merchant: AccountId,
    pub stock: u32,
    pub bid: U128,
    pub purse: U128,
    pub day: u32,
}

#[near(serializers = [borsh, json])]
#[derive(Clone)]
pub struct Rebase {
    pub day: u32,
    pub worth: U128,
    pub step_bp: i64,
    pub supply: U128,
}

#[near(serializers = [json])]
pub struct Info {
    pub symbol: String,
    pub market: AccountId,
    pub merchant: AccountId,
    pub cap_bp: u32,
    pub claim: U128,
    pub claims_left: u32,
    pub holders: u32,
    pub index: U128,
    pub total_supply: U128,
    pub last_worth: U128,
    pub last_day: u32,
    pub rebases: u32,
}

#[near(serializers = [json])]
pub struct StorageBalance {
    pub total: U128,
    pub available: U128,
}

#[near(serializers = [json])]
pub struct Metadata {
    pub spec: String,
    pub name: String,
    pub symbol: String,
    pub icon: Option<String>,
    pub reference: Option<String>,
    pub reference_hash: Option<String>,
    pub decimals: u8,
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Coin {
    market: AccountId,
    merchant: AccountId,
    name: String,
    symbol: String,
    cap_bp: u32,
    claim: u128,
    claims_left: u32,
    holders: u32,
    shares: LookupMap<AccountId, u128>,
    total_shares: u128,
    index: u128,
    last_worth: u128,
    last_day: u32,
    rebases: Vector<Rebase>,
}

fn event(standard: &str, name: &str, data: String) {
    env::log_str(&format!("EVENT_JSON:{{\"standard\":\"{standard}\",\"version\":\"1.0.0\",\"event\":\"{name}\",\"data\":[{data}]}}"));
}

#[near]
impl Coin {
    /// cap_bp: largest daily rebase (500 = 5%); claim: coins per `back()` (6 decimals); claims: how many backers.
    #[init]
    pub fn new(market: AccountId, merchant: AccountId, name: String, symbol: String, cap_bp: u32, claim: U128, claims: u32) -> Self {
        require!(cap_bp > 0 && cap_bp <= 2_000, "BadCap");
        require!(claim.0 > 0, "BadClaim");
        Self {
            market,
            merchant,
            name,
            symbol,
            cap_bp,
            claim: claim.0,
            claims_left: claims,
            holders: 0,
            shares: LookupMap::new(Key::Shares),
            total_shares: 0,
            index: coin::INDEX_ONE,
            last_worth: 0,
            last_day: 0,
            rebases: Vector::new(Key::Rebases),
        }
    }

    /// Back this merchant: one claim of `claim` coins per account, while claims last.
    #[payable]
    pub fn back(&mut self) -> U128 {
        require!(env::attached_deposit() >= BACK_DEPOSIT, "AttachDeposit");
        let who = env::predecessor_account_id();
        require!(self.shares.get(&who).is_none(), "AlreadyBacked");
        require!(self.claims_left > 0, "NoClaimsLeft");
        let s = (self.claim * coin::INDEX_ONE).div_ceil(self.index); // rounded up: a backer gets the full claim
        self.shares.insert(who.clone(), s);
        self.total_shares += s;
        self.claims_left -= 1;
        self.holders += 1;
        let amount = self.to_coins(s);
        event("nep141", "ft_mint", format!("{{\"owner_id\":\"{who}\",\"amount\":\"{amount}\"}}"));
        U128(amount)
    }

    /// Anyone, any time: the next market day's rebase (a no-op until the market day moves on).
    pub fn tick(&mut self) -> Promise {
        Promise::new(self.market.clone())
            .function_call("get_market", b"{}".to_vec(), NearToken::from_yoctonear(0), VIEW_GAS)
            .then(Self::ext(env::current_account_id()).with_static_gas(CALLBACK_GAS).on_market())
    }

    #[private]
    pub fn on_market(&mut self, #[callback_result] rows: Result<Vec<MarketRow>, PromiseError>) -> Option<Rebase> {
        rows.ok().and_then(|r| self.apply_market(&r))
    }

    // ---- NEP-141 ----

    #[payable]
    pub fn ft_transfer(&mut self, receiver_id: AccountId, amount: U128, memo: Option<String>) {
        near_sdk::assert_one_yocto();
        let _ = memo;
        let sender = env::predecessor_account_id();
        self.move_coins(&sender, &receiver_id, amount.0);
    }

    #[payable]
    pub fn ft_transfer_call(&mut self, receiver_id: AccountId, amount: U128, memo: Option<String>, msg: String) -> PromiseOrValue<U128> {
        near_sdk::assert_one_yocto();
        let _ = memo;
        let sender = env::predecessor_account_id();
        self.move_coins(&sender, &receiver_id, amount.0);
        let args = format!("{{\"sender_id\":\"{sender}\",\"amount\":\"{}\",\"msg\":{}}}", amount.0, near_sdk::serde_json::to_string(&msg).unwrap());
        Promise::new(receiver_id.clone())
            .function_call("ft_on_transfer", args.into_bytes(), NearToken::from_yoctonear(0), TRANSFER_CALL_GAS)
            .then(Self::ext(env::current_account_id()).with_static_gas(RESOLVE_GAS).ft_resolve_transfer(sender, receiver_id, amount))
            .into()
    }

    /// Returns the amount the receiver kept; the unused part (capped by what it still holds) goes back.
    #[private]
    pub fn ft_resolve_transfer(&mut self, sender_id: AccountId, receiver_id: AccountId, amount: U128, #[callback_result] unused: Result<U128, PromiseError>) -> U128 {
        let unused = unused.map(|u| u.0.min(amount.0)).unwrap_or(amount.0);
        let back = unused.min(self.ft_balance_of(receiver_id.clone()).0);
        if back > 0 && self.shares.get(&sender_id).is_some() {
            self.move_coins(&receiver_id, &sender_id, back);
        }
        U128(amount.0 - back)
    }

    pub fn ft_total_supply(&self) -> U128 {
        U128(self.to_coins(self.total_shares))
    }

    pub fn ft_balance_of(&self, account_id: AccountId) -> U128 {
        U128(self.to_coins(self.shares.get(&account_id).copied().unwrap_or(0)))
    }

    pub fn ft_metadata(&self) -> Metadata {
        Metadata { spec: "ft-1.0.0".into(), name: self.name.clone(), symbol: self.symbol.clone(), icon: None, reference: None, reference_hash: None, decimals: 6 }
    }

    // ---- NEP-145 (registration so a wallet can receive without backing) ----

    #[payable]
    pub fn storage_deposit(&mut self, account_id: Option<AccountId>, registration_only: Option<bool>) -> StorageBalance {
        let _ = registration_only;
        require!(env::attached_deposit() >= STORAGE_DEPOSIT, "AttachDeposit");
        let who = account_id.unwrap_or_else(env::predecessor_account_id);
        if self.shares.get(&who).is_none() {
            self.shares.insert(who, 0);
        }
        StorageBalance { total: U128(STORAGE_DEPOSIT.as_yoctonear()), available: U128(0) }
    }

    pub fn storage_balance_of(&self, account_id: AccountId) -> Option<StorageBalance> {
        self.shares.get(&account_id).map(|_| StorageBalance { total: U128(STORAGE_DEPOSIT.as_yoctonear()), available: U128(0) })
    }

    // ---- views ----

    pub fn info(&self) -> Info {
        Info {
            symbol: self.symbol.clone(),
            market: self.market.clone(),
            merchant: self.merchant.clone(),
            cap_bp: self.cap_bp,
            claim: U128(self.claim),
            claims_left: self.claims_left,
            holders: self.holders,
            index: U128(self.index),
            total_supply: self.ft_total_supply(),
            last_worth: U128(self.last_worth),
            last_day: self.last_day,
            rebases: self.rebases.len(),
        }
    }

    /// Rebase log, newest last: from `from`, at most `limit` entries.
    pub fn rebases(&self, from: u32, limit: u32) -> Vec<Rebase> {
        (from..self.rebases.len().min(from.saturating_add(limit))).filter_map(|i| self.rebases.get(i).cloned()).collect()
    }
}

impl Coin {
    fn to_coins(&self, shares: u128) -> u128 {
        shares * self.index / coin::INDEX_ONE
    }

    /// The day's rebase from the market rows; None when the market day has not moved on (or no rows for us).
    fn apply_market(&mut self, rows: &[MarketRow]) -> Option<Rebase> {
        let mine: Vec<&MarketRow> = rows.iter().filter(|r| r.merchant == self.merchant).collect();
        let day = mine.first()?.day;
        if self.last_worth != 0 && day <= self.last_day {
            return None;
        }
        let worth = coin::net_worth(mine[0].purse.0, &mine.iter().map(|r| (r.stock, r.bid.0)).collect::<Vec<_>>());
        let step = coin::step_bp(self.last_worth, worth, self.cap_bp);
        self.index = coin::apply(self.index, step);
        self.last_worth = worth;
        self.last_day = day;
        let r = Rebase { day, worth: U128(worth), step_bp: step, supply: self.ft_total_supply() };
        self.rebases.push(r.clone());
        event("haggle_coin", "rebase", format!("{{\"day\":{day},\"worth\":\"{worth}\",\"step_bp\":{step},\"supply\":\"{}\"}}", r.supply.0));
        Some(r)
    }

    /// Moves `amount` coins as shares, rounding the shares up so a transfer can never mint dust.
    fn move_coins(&mut self, from: &AccountId, to: &AccountId, amount: u128) {
        require!(amount > 0, "ZeroAmount");
        require!(from != to, "SelfTransfer");
        let need = (amount * coin::INDEX_ONE).div_ceil(self.index);
        let have = self.shares.get(from).copied().unwrap_or_else(|| env::panic_str("NotRegistered"));
        require!(have >= need, "InsufficientBalance");
        let to_have = self.shares.get(to).copied().unwrap_or_else(|| env::panic_str("ReceiverNotRegistered"));
        self.shares.insert(from.clone(), have - need);
        self.shares.insert(to.clone(), to_have + need);
        event("nep141", "ft_transfer", format!("{{\"old_owner_id\":\"{from}\",\"new_owner_id\":\"{to}\",\"amount\":\"{amount}\"}}"));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use near_sdk::test_utils::VMContextBuilder;
    use near_sdk::testing_env;

    const COIN: u128 = 1_000_000; // 6 decimals

    fn acc(s: &str) -> AccountId {
        s.parse().unwrap()
    }
    fn ctx(who: &str, deposit: NearToken) {
        testing_env!(VMContextBuilder::new().current_account_id(acc("smith-coin.testnet")).predecessor_account_id(acc(who)).attached_deposit(deposit).build());
    }
    fn coin(claims: u32) -> Coin {
        ctx("deployer.testnet", NearToken::from_yoctonear(0));
        Coin::new(acc("market.testnet"), acc("smith.testnet"), "Smith Backer".into(), "SMITH".into(), 500, U128(1_000 * COIN), claims)
    }
    fn back(c: &mut Coin, who: &str) -> u128 {
        ctx(who, BACK_DEPOSIT);
        c.back().0
    }
    fn rows(purse: u128, day: u32) -> Vec<MarketRow> {
        let row = |m: &str, stock, bid| MarketRow { merchant: acc(m), stock, bid: U128(bid), purse: U128(purse), day };
        vec![row("smith.testnet", 100, 24), row("smith.testnet", 40, 72), row("woodcutter.testnet", 999, 999)]
    }

    #[test]
    fn back_mints_one_claim_per_account() {
        let mut c = coin(5);
        assert_eq!(back(&mut c, "ana.testnet"), 1_000 * COIN);
        assert_eq!(c.ft_balance_of(acc("ana.testnet")).0, 1_000 * COIN);
        assert_eq!(c.info().claims_left, 4);
    }

    #[test]
    #[should_panic(expected = "AlreadyBacked")]
    fn back_twice_rejected() {
        let mut c = coin(5);
        back(&mut c, "ana.testnet");
        back(&mut c, "ana.testnet");
    }

    #[test]
    #[should_panic(expected = "NoClaimsLeft")]
    fn claims_run_out() {
        let mut c = coin(1);
        back(&mut c, "ana.testnet");
        back(&mut c, "bo.testnet");
    }

    #[test]
    #[should_panic(expected = "AttachDeposit")]
    fn back_needs_the_deposit() {
        let mut c = coin(5);
        ctx("ana.testnet", NearToken::from_yoctonear(1));
        c.back();
    }

    #[test]
    fn rebase_follows_merchant_worth_capped_once_a_day() {
        let mut c = coin(5);
        back(&mut c, "ana.testnet");
        back(&mut c, "bo.testnet");
        // worth = purse + 100*24 + 40*72 = purse + 5280; the woodcutter row is ignored
        assert_eq!(c.apply_market(&rows(4_720, 1)).unwrap().step_bp, 0, "first tick sets the baseline");
        assert!(c.apply_market(&rows(9_999, 1)).is_none(), "same market day: no second step");
        let r = c.apply_market(&rows(4_920, 2)).unwrap(); // 10_000 -> 10_200
        assert_eq!(r.step_bp, 200);
        assert_eq!(c.ft_balance_of(acc("ana.testnet")).0, 1_020 * COIN);
        assert_eq!(c.ft_total_supply().0, 2_040 * COIN, "every wallet moved by the same percent");
        let r = c.apply_market(&rows(0, 3)).unwrap(); // a crash day is capped at -5%
        assert_eq!(r.step_bp, -500);
        assert_eq!(c.ft_balance_of(acc("bo.testnet")).0, 969 * COIN);
        assert_eq!(c.rebases(0, 10).len(), 3);
    }

    #[test]
    fn transfer_moves_coins_and_backing_after_a_rebase_is_fair() {
        let mut c = coin(5);
        back(&mut c, "ana.testnet");
        c.apply_market(&rows(4_720, 1));
        c.apply_market(&rows(5_220, 2)); // +5% (capped)
        ctx("bo.testnet", STORAGE_DEPOSIT);
        c.storage_deposit(None, None);
        ctx("ana.testnet", NearToken::from_yoctonear(1));
        c.ft_transfer(acc("bo.testnet"), U128(50 * COIN), None);
        assert_eq!(c.ft_balance_of(acc("bo.testnet")).0, 50 * COIN);
        assert!(c.ft_balance_of(acc("ana.testnet")).0 >= 1_000 * COIN - 1, "1050 - 50, within one unit of rounding");
        assert_eq!(back(&mut c, "cy.testnet"), 1_000 * COIN, "a late backer gets the same 1000, not an inflated share");
    }

    #[test]
    #[should_panic(expected = "ReceiverNotRegistered")]
    fn transfer_to_unregistered_rejected() {
        let mut c = coin(5);
        back(&mut c, "ana.testnet");
        ctx("ana.testnet", NearToken::from_yoctonear(1));
        c.ft_transfer(acc("nobody.testnet"), U128(COIN), None);
    }

    #[test]
    #[should_panic(expected = "BadCap")]
    fn cap_is_bounded_at_launch() {
        ctx("deployer.testnet", NearToken::from_yoctonear(0));
        Coin::new(acc("m.testnet"), acc("s.testnet"), "x".into(), "X".into(), 9_000, U128(1), 1);
    }
}
