//! Signed deals between a merchant agent and a player, and the daily stock burn.
//! The game relayer submits; the merchant's ed25519 signature proves the merchant agreed;
//! the price must sit inside the room from economy/src/pricing.rs at settle time.

use crate::*;
use near_sdk::json_types::Base64VecU8;
use near_sdk::CurveType;

const MIN_TICK_GAP_NS: u64 = 290_000_000_000;

#[near(serializers = [json])]
#[derive(Clone)]
pub struct Deal {
    pub merchant: AccountId,
    pub player: String,
    pub good: String,
    pub qty: u32,
    pub unit_price: U128,
    pub side: String,
    pub nonce: U64,
    pub expires_at_ns: U64,
}

#[near(serializers = [json])]
pub struct SettleResult {
    pub player: PlayerView,
    pub merchant_stock: u32,
    pub merchant_purse: U128,
}

/// Canonical bytes the merchant signs. The backend builds the identical string.
pub fn deal_message(d: &Deal) -> String {
    format!(
        "haggle:v1|{}|{}|{}|{}|{}|{}|{}|{}",
        d.merchant, d.player, d.good, d.qty, d.unit_price.0, d.side, d.nonce.0, d.expires_at_ns.0
    )
}

#[near]
impl Contract {
    pub fn settle_deal(&mut self, deal: Deal, merchant_sig: Base64VecU8) -> SettleResult {
        self.assert_game();
        let m = self.merchants.get(&deal.merchant).unwrap_or_else(|| env::panic_str("UnknownMerchant"));
        if deal.good != m.good {
            env::panic_str("BadGood");
        }
        let (good, target, pk) = (good_of(&m.good), m.target, m.public_key.clone());
        if !(1..=10).contains(&deal.qty) {
            env::panic_str("BadQty");
        }
        let buying = match deal.side.as_str() {
            "buy" => true,
            "sell" => false,
            _ => env::panic_str("BadSide"),
        };
        let sig: [u8; 64] = merchant_sig.0.as_slice().try_into().unwrap_or_else(|_| env::panic_str("BadSignature"));
        if pk.curve_type() != CurveType::ED25519 {
            env::panic_str("BadSignature");
        }
        let pk32: [u8; 32] = pk.as_bytes()[1..].try_into().unwrap_or_else(|_| env::panic_str("BadSignature"));
        if !env::ed25519_verify(&sig, deal_message(&deal).as_bytes(), &pk32) {
            env::panic_str("BadSignature");
        }
        if self.used_nonces.contains(&deal.nonce.0) {
            env::panic_str("NonceUsed");
        }
        if deal.expires_at_ns.0 < env::block_timestamp() {
            env::panic_str("Expired");
        }
        if !self.players.contains(&deal.player) {
            env::panic_str("UnknownPlayer");
        }

        let merchant = deal.merchant.as_str();
        let stock = self.stock_of(merchant, &deal.good);
        let purse = self.bal(merchant, "coin");
        let (lo, hi) = if buying {
            pricing::buy_room(good, stock, target)
        } else {
            pricing::sell_room(good, stock, target, purse, deal.qty).unwrap_or_else(|| env::panic_str("MerchantPurseEmpty"))
        };
        let p = deal.unit_price.0;
        if p < lo || p > hi {
            env::panic_str("PriceOutOfRoom");
        }

        let total = p * deal.qty as u128;
        let qty = deal.qty as u128;
        let (coin_from, coin_to, good_from, good_to) = if buying {
            (deal.player.as_str(), merchant, merchant, deal.player.as_str())
        } else {
            (merchant, deal.player.as_str(), deal.player.as_str(), merchant)
        };
        self.sub(coin_from, "coin", total);
        self.sub(good_from, &deal.good, qty);
        self.add(coin_to, "coin", total);
        self.add(good_to, &deal.good, qty);
        self.used_nonces.insert(deal.nonce.0);
        nep245::emit_transfer(coin_from, coin_to, &["coin"], &[total]);
        nep245::emit_transfer(good_from, good_to, &[&deal.good], &[qty]);

        SettleResult {
            player: self.get_player(deal.player.clone()).unwrap(),
            merchant_stock: self.stock_of(merchant, &deal.good),
            merchant_purse: U128(self.bal(merchant, "coin")),
        }
    }

    /// Burns 10% of every merchant's stock once per game day. Calls closer than 290 s apart are no-ops.
    pub fn day_tick(&mut self) -> bool {
        self.assert_game();
        let now = env::block_timestamp();
        if now.saturating_sub(self.last_tick_ns) < MIN_TICK_GAP_NS {
            return false;
        }
        let list: Vec<(AccountId, String)> = self.merchants.iter().map(|(a, m)| (a.clone(), m.good.clone())).collect();
        for (acct, good) in list {
            let stock = self.stock_of(acct.as_str(), &good);
            let burned = (stock - pricing::burn(stock)) as u128;
            if burned > 0 {
                self.sub(acct.as_str(), &good, burned);
                nep245::emit_burn(acct.as_str(), &[&good], &[burned]);
            }
        }
        self.day += 1;
        self.last_tick_ns = now;
        true
    }
}

#[cfg(test)]
mod tests {
    use crate::tests::*;
    use crate::*;
    use ed25519_dalek::{Signer, SigningKey};
    use near_sdk::json_types::Base64VecU8;

    const FAR: u64 = 1_000_000_000_000_000_000;

    fn key(seed: u8) -> SigningKey {
        SigningKey::from_bytes(&[seed; 32])
    }

    fn deal(side: &str, qty: u32, price: u128, nonce: u64) -> Deal {
        Deal {
            merchant: acc(WOOD_M),
            player: "roblox:1".into(),
            good: "wood".into(),
            qty,
            unit_price: U128(price),
            side: side.into(),
            nonce: U64(nonce),
            expires_at_ns: U64(FAR),
        }
    }

    fn sig(k: &SigningKey, d: &Deal) -> Base64VecU8 {
        Base64VecU8(k.sign(deal_message(d).as_bytes()).to_bytes().to_vec())
    }

    /// Merchant signed by key(7), one registered player roblox:1 holding `wood` wood.
    fn world(stock: u32, purse: u128, wood: u32) -> Contract {
        let mut c = setup(key(7).verifying_key().to_bytes(), stock, purse);
        ctx(GAME, 0, 1);
        c.register_player("roblox:1".into());
        if wood > 0 {
            c.gather_batch(vec![GatherEntry { player_id: "roblox:1".into(), good: "wood".into(), qty: wood }]);
        }
        c
    }

    fn settle(c: &mut Contract, d: Deal) -> SettleResult {
        let s = sig(&key(7), &d);
        c.settle_deal(d, s)
    }

    #[test]
    fn message_format() {
        let mut d = deal("buy", 5, 21, 7);
        d.merchant = acc("woodcutter.haggletown.testnet");
        d.expires_at_ns = U64(1_700_000_000_000_000_000);
        assert_eq!(deal_message(&d), "haggle:v1|woodcutter.haggletown.testnet|roblox:1|wood|5|21|buy|7|1700000000000000000");
    }

    #[test]
    fn settle_buy_happy_path() {
        let mut c = world(140, 10_000, 0);
        let r = settle(&mut c, deal("buy", 5, 21, 1));
        assert_eq!(r.player.coin, U128(895));
        assert_eq!(r.player.wood, U128(5));
        assert_eq!(r.merchant_stock, 135);
        assert_eq!(r.merchant_purse, U128(10_105));
    }

    #[test]
    fn settle_sell_happy_path() {
        let mut c = world(50, 10_000, 5);
        let r = settle(&mut c, deal("sell", 5, 100, 1));
        assert_eq!(r.player.coin, U128(1_500));
        assert_eq!(r.player.wood, U128(0));
        assert_eq!(r.merchant_stock, 55);
        assert_eq!(r.merchant_purse, U128(9_500));
    }

    #[test]
    #[should_panic(expected = "BadSignature")]
    fn bad_signature() {
        let mut c = world(140, 10_000, 0);
        let d = deal("buy", 5, 21, 1);
        let s = sig(&key(8), &d);
        c.settle_deal(d, s);
    }

    #[test]
    #[should_panic(expected = "BadSignature")]
    fn tampered_deal() {
        let mut c = world(140, 10_000, 0);
        let d = deal("buy", 5, 21, 1);
        let s = sig(&key(7), &d);
        c.settle_deal(deal("buy", 5, 22, 1), s);
    }

    #[test]
    #[should_panic(expected = "NonceUsed")]
    fn nonce_reuse() {
        let mut c = world(140, 10_000, 0);
        settle(&mut c, deal("buy", 1, 30, 1));
        settle(&mut c, deal("buy", 1, 30, 1));
    }

    #[test]
    #[should_panic(expected = "Expired")]
    fn expired() {
        let mut c = world(140, 10_000, 0);
        ctx(GAME, 0, FAR + 1);
        settle(&mut c, deal("buy", 5, 21, 1));
    }

    #[test]
    #[should_panic(expected = "PriceOutOfRoom")]
    fn price_below_floor() {
        let mut c = world(140, 10_000, 0);
        settle(&mut c, deal("buy", 5, 20, 1));
    }

    #[test]
    #[should_panic(expected = "PriceOutOfRoom")]
    fn price_above_ask() {
        let mut c = world(140, 10_000, 0);
        settle(&mut c, deal("buy", 5, 36, 1));
    }

    #[test]
    #[should_panic(expected = "PriceOutOfRoom")]
    fn sell_above_ceiling() {
        let mut c = world(50, 10_000, 5);
        settle(&mut c, deal("sell", 5, 113, 1));
    }

    #[test]
    #[should_panic(expected = "MerchantPurseEmpty")]
    fn purse_empty() {
        let mut c = world(100, 39, 1);
        settle(&mut c, deal("sell", 1, 40, 1));
    }

    #[test]
    #[should_panic(expected = "InsufficientFunds")]
    fn insufficient_coin() {
        let mut c = world(140, 10_000, 0);
        settle(&mut c, deal("buy", 10, 35, 1)); // 650 left, stock 130
        settle(&mut c, deal("buy", 10, 35, 2)); // 300 left, stock 120
        settle(&mut c, deal("buy", 10, 35, 3)); // needs 350
    }

    #[test]
    #[should_panic(expected = "InsufficientGoods")]
    fn insufficient_goods() {
        let mut c = world(50, 10_000, 2);
        settle(&mut c, deal("sell", 5, 100, 1));
    }

    #[test]
    #[should_panic(expected = "BadQty")]
    fn qty_limit() {
        let mut c = world(140, 10_000, 0);
        settle(&mut c, deal("buy", 11, 30, 1));
    }

    #[test]
    #[should_panic(expected = "NotGame")]
    fn settle_requires_game() {
        let mut c = world(140, 10_000, 0);
        ctx("alice.testnet", 0, 1);
        settle(&mut c, deal("buy", 5, 21, 1));
    }

    #[test]
    fn day_tick_spacing() {
        let mut c = world(100, 10_000, 0);
        let t0 = 1 + 300_000_000_000;
        ctx(GAME, 0, t0);
        assert!(c.day_tick());
        assert_eq!(c.get_market()[0].stock, 90);
        ctx(GAME, 0, t0 + 100_000_000_000);
        assert!(!c.day_tick());
        assert_eq!(c.get_market()[0].stock, 90);
        ctx(GAME, 0, t0 + 291_000_000_000);
        assert!(c.day_tick());
        assert_eq!(c.get_market()[0].stock, 81);
        assert_eq!(c.get_market()[0].day, 2);
    }
}
