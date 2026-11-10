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
pub(crate) const WOOD_M: &str = "woodcutter.testnet";

/// Contract with one wood merchant (given pubkey bytes, stock, purse) and owner/game roles.
pub(crate) fn setup(pk: [u8; 32], stock: u32, purse: u128) -> Contract {
    ctx(OWNER, 0, 1);
    let mut c = Contract::new(acc(OWNER), acc(GAME));
    let mut raw = vec![0u8]; // curve type 0 = ed25519
    raw.extend_from_slice(&pk);
    let key = PublicKey::try_from(raw).unwrap();
    c.register_merchant(acc(WOOD_M), "wood".into(), key, U128(purse), stock, 100);
    c
}

fn entry(p: &str, g: &str, q: u32) -> GatherEntry {
    GatherEntry { player_id: p.into(), good: g.into(), qty: q }
}

#[test]
fn register_player_grants_once() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c.register_player("roblox:1".into());
    assert_eq!(c.get_player("roblox:1".into()).unwrap().coin, U128(1000));
}

#[test]
#[should_panic(expected = "NotGame")]
fn register_player_requires_game() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx("alice.testnet", 0, 1);
    c.register_player("roblox:1".into());
}

#[test]
#[should_panic(expected = "NotOwner")]
fn register_merchant_requires_owner() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    let mut raw = vec![0u8];
    raw.extend_from_slice(&[2; 32]);
    c.register_merchant(acc("smith.testnet"), "iron".into(), PublicKey::try_from(raw).unwrap(), U128(1), 1, 100);
}

#[test]
#[should_panic(expected = "MerchantExists")]
fn register_merchant_twice_rejected() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(OWNER, 0, 1);
    let mut raw = vec![0u8];
    raw.extend_from_slice(&[1; 32]);
    c.register_merchant(acc(WOOD_M), "wood".into(), PublicKey::try_from(raw).unwrap(), U128(1), 1, 100);
}

#[test]
#[should_panic(expected = "BadPlayerId")]
fn bad_player_id_rejected() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("steam:1".into());
}

#[test]
fn player_id_formats() {
    assert!(valid_player_id("roblox:123"));
    assert!(valid_player_id("web:0a1b2c3d-0000-4000-8000-123456789abc"));
    assert!(!valid_player_id("roblox:"));
    assert!(!valid_player_id("roblox:12a"));
    assert!(!valid_player_id("roblox:123456789012345678901"));
    assert!(!valid_player_id("web:xyz"));
}

#[test]
fn gather_batch_mints() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c.gather_batch(vec![entry("roblox:1", "wood", 3), entry("roblox:1", "wood", 2)]);
    assert_eq!(c.get_player("roblox:1".into()).unwrap().wood, U128(5));
}

#[test]
#[should_panic(expected = "QtyTooLarge")]
fn gather_qty_limit() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c.gather_batch(vec![entry("roblox:1", "wood", 21)]);
}

#[test]
#[should_panic(expected = "BatchTooLarge")]
fn gather_batch_limit() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c.gather_batch((0..101).map(|_| entry("roblox:1", "wood", 1)).collect());
}

#[test]
#[should_panic(expected = "UnknownPlayer")]
fn gather_unknown_player() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.gather_batch(vec![entry("roblox:9", "wood", 1)]);
}

#[test]
#[should_panic(expected = "BadGood")]
fn gather_bad_good() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(GAME, 0, 1);
    c.register_player("roblox:1".into());
    c.gather_batch(vec![entry("roblox:1", "gold", 1)]);
}

#[test]
fn market_view_prices() {
    let c = setup([1; 32], 140, 10_000);
    let m = &c.get_market()[0];
    assert_eq!(m.stock, 140);
    assert_eq!(m.ask, U128(35));
    assert_eq!(m.floor, U128(21));
    assert_eq!(m.bid, U128(28));
    assert_eq!(m.purse, U128(10_000));
}

#[test]
fn mt_transfer_moves_own_balance() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(WOOD_M, 1, 1);
    c.mt_transfer(acc(OWNER), "coin".into(), U128(5), None, None);
    assert_eq!(c.mt_balance_of(acc(OWNER), "coin".into()), U128(5));
    assert_eq!(c.mt_balance_of(acc(WOOD_M), "coin".into()), U128(9_995));
    assert_eq!(
        c.mt_batch_balance_of(acc(WOOD_M), vec!["coin".into(), "wood".into()]),
        vec![U128(9_995), U128(100)]
    );
}

#[test]
#[should_panic]
fn mt_transfer_requires_one_yocto() {
    let mut c = setup([1; 32], 100, 10_000);
    ctx(WOOD_M, 0, 1);
    c.mt_transfer(acc(OWNER), "coin".into(), U128(5), None, None);
}
