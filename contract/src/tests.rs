use super::*;
use near_sdk::test_utils::VMContextBuilder;
use near_sdk::{testing_env, NearToken};

pub(crate) fn acc(s: &str) -> AccountId {
    s.parse().unwrap()
}

pub(crate) fn ctx(pred: &str, deposit: u128, ts_ns: u64) {
    let mut b = VMContextBuilder::new();
    b.current_account_id(acc("haggle.testnet"))
        .predecessor_account_id(acc(pred))
        .attached_deposit(NearToken::from_yoctonear(deposit))
        .block_timestamp(ts_ns);
    testing_env!(b.build());
}

pub(crate) const OWNER: &str = "owner.testnet";
pub(crate) const GAME: &str = "game.testnet";
pub(crate) const FISH_M: &str = "fishmonger.testnet";

pub(crate) fn key(pk: [u8; 32]) -> PublicKey {
    let mut raw = vec![0u8]; // curve type 0 = ed25519
    raw.extend_from_slice(&pk);
    PublicKey::try_from(raw).unwrap()
}

/// Contract with a fishmonger (given pubkey, purse) stocked at every item's target, and player roblox:1.
pub(crate) fn setup(pk: [u8; 32], purse: u128) -> Contract {
    ctx(OWNER, 0, 1);
    let mut c = Contract::new(acc(OWNER), acc(GAME));
    c.register_merchant(acc(FISH_M), "fish".into(), key(pk), U128(purse));
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c
}

fn bal(c: &Contract, holder: &str, token: &str) -> u128 {
    c.bal(holder, token)
}

#[test]
fn register_merchant_mints_targets() {
    let c = setup([1; 32], 10_000);
    assert_eq!(bal(&c, FISH_M, "fish_sardine"), 120);
    assert_eq!(bal(&c, FISH_M, "fish_koi"), 3);
    assert_eq!(bal(&c, FISH_M, "coin"), 10_000);
    assert_eq!(c.get_market().len(), 4);
}

#[test]
#[should_panic(expected = "BadCategory")]
fn register_merchant_bad_category() {
    let mut c = setup([1; 32], 10_000);
    ctx(OWNER, 0, 1);
    c.register_merchant(acc("x.testnet"), "gems".into(), key([2; 32]), U128(1));
}

#[test]
#[should_panic(expected = "NotOwner")]
fn register_merchant_requires_owner() {
    let mut c = setup([1; 32], 10_000);
    c.register_merchant(acc("smith.testnet"), "ore".into(), key([2; 32]), U128(1));
}

#[test]
fn register_player_grants_once() {
    let mut c = setup([1; 32], 10_000);
    c.register_player("roblox:1".into());
    let p = c.get_player("roblox:1".into()).unwrap();
    assert_eq!(p.balances["coin"], U128(1000));
    assert_eq!(p.class, None);
}

#[test]
#[should_panic(expected = "BadPlayerId")]
fn bad_player_id_rejected() {
    let mut c = setup([1; 32], 10_000);
    c.register_player("steam:1".into());
}

#[test]
fn player_id_formats() {
    assert!(valid_player_id("roblox:123"));
    assert!(valid_player_id("web:0a1b2c3d-0000-4000-8000-123456789abc"));
    assert!(!valid_player_id("roblox:"));
    assert!(!valid_player_id("roblox:12a"));
}

#[test]
fn set_class_first_free_then_costs_100() {
    let mut c = setup([1; 32], 10_000);
    c.set_class("roblox:1".into(), "fisher".into());
    assert_eq!(bal(&c, "roblox:1", "coin"), 1000);
    c.set_class("roblox:1".into(), "fisher".into()); // same class: no-op
    assert_eq!(bal(&c, "roblox:1", "coin"), 1000);
    c.set_class("roblox:1".into(), "logger".into());
    assert_eq!(bal(&c, "roblox:1", "coin"), 900);
    assert_eq!(c.get_player("roblox:1".into()).unwrap().class, Some("logger".to_string()));
}

#[test]
#[should_panic(expected = "BadClass")]
fn set_class_bad_class_rejected() {
    let mut c = setup([1; 32], 10_000);
    c.set_class("roblox:1".into(), "king".into());
}

#[test]
#[should_panic(expected = "InsufficientFunds")]
fn set_class_switch_needs_100() {
    let mut c = setup([1; 32], 10_000);
    c.set_class("roblox:1".into(), "fisher".into());
    c.sub("roblox:1", "coin", 950);
    c.set_class("roblox:1".into(), "miner".into());
}

#[test]
fn gather_mints_item() {
    let mut c = setup([1; 32], 10_000);
    c.gather_batch(vec![GatherEntry { player_id: "roblox:1".into(), good: "fish_trout".into(), qty: 2 }]);
    assert_eq!(c.get_player("roblox:1".into()).unwrap().balances["fish_trout"], U128(2));
}

#[test]
#[should_panic(expected = "BadGood")]
fn gather_rejects_category_name() {
    let mut c = setup([1; 32], 10_000);
    c.gather_batch(vec![GatherEntry { player_id: "roblox:1".into(), good: "fish".into(), qty: 1 }]);
}

#[test]
fn market_view_per_item() {
    let c = setup([1; 32], 10_000);
    let m = c.get_market();
    let koi = m.iter().find(|r| r.item == "fish_koi").unwrap();
    assert_eq!(koi.ask, U128(600));
    assert_eq!(koi.tier, "legendary");
    assert_eq!(koi.category, "fish");
}

#[test]
fn mt_transfer_moves_own_balance() {
    let mut c = setup([1; 32], 10_000);
    ctx(FISH_M, 1, 1);
    c.mt_transfer(acc(OWNER), "fish_trout".into(), U128(5), None, None);
    assert_eq!(c.mt_balance_of(acc(OWNER), "fish_trout".into()), U128(5));
}
