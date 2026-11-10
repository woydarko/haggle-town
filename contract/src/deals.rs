//! Signed deals between a merchant agent and a player, and the daily restock + burn.
//! The game relayer submits; the merchant's ed25519 signature proves the merchant agreed;
//! the price must sit inside the room from economy/src/pricing.rs at settle time
//! (specialists of the item's category get the wider sell room).

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
        let item = item_of(&deal.good);
        if item.category.as_str() != m.category {
            env::panic_str("BadGood");
        }
        let pk = m.public_key.clone();
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
            pricing::buy_room(item, stock)
        } else {
            let specialist = self.is_specialist(&deal.player, item.category);
            pricing::sell_room(item, stock, purse, deal.qty, specialist).unwrap_or_else(|| env::panic_str("MerchantPurseEmpty"))
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

    /// Once per game day: every merchant restocks each item toward its target, then uses up 10%.
    /// Calls closer than 290 s apart are no-ops.
    pub fn day_tick(&mut self) -> bool {
        self.assert_game();
        let now = env::block_timestamp();
        if now.saturating_sub(self.last_tick_ns) < MIN_TICK_GAP_NS {
            return false;
        }
        let list: Vec<(AccountId, String)> = self.merchants.iter().map(|(a, m)| (a.clone(), m.category.clone())).collect();
        for (acct, category) in list {
            let Some(cat) = Category::from_str(&category) else { continue };
            for tier in Tier::ALL {
                let item = Item::of(cat, tier);
                let imported = pricing::restock(self.stock_of(acct.as_str(), item.id()), item.target()) as u128;
                if imported > 0 {
                    self.add(acct.as_str(), item.id(), imported);
                    nep245::emit_mint(acct.as_str(), &[item.id()], &[imported]);
                }
                let stock = self.stock_of(acct.as_str(), item.id());
                let burned = (stock - pricing::burn(stock)) as u128;
                if burned > 0 {
                    self.sub(acct.as_str(), item.id(), burned);
                    nep245::emit_burn(acct.as_str(), &[item.id()], &[burned]);
                }
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

    fn sk(seed: u8) -> SigningKey {
        SigningKey::from_bytes(&[seed; 32])
    }

    fn deal(good: &str, side: &str, qty: u32, price: u128, nonce: u64) -> Deal {
        Deal {
            merchant: acc(FISH_M),
            player: "roblox:1".into(),
            good: good.into(),
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

    /// Fishmonger signed by sk(7) with purse; player roblox:1 holds `trout` trout.
    fn world(purse: u128, trout: u32) -> Contract {
        let mut c = setup(sk(7).verifying_key().to_bytes(), purse);
        if trout > 0 {
            c.gather_batch(vec![GatherEntry { player_id: "roblox:1".into(), good: "fish_trout".into(), qty: trout }]);
        }
        c
    }

    fn settle(c: &mut Contract, d: Deal) -> SettleResult {
        let s = sig(&sk(7), &d);
        c.settle_deal(d, s)
    }

    #[test]
    fn message_format() {
        let mut d = deal("fish_trout", "buy", 5, 21, 7);
        d.merchant = acc("fishmonger.haggletown.testnet");
        d.expires_at_ns = U64(1_700_000_000_000_000_000);
        assert_eq!(deal_message(&d), "haggle:v1|fishmonger.haggletown.testnet|roblox:1|fish_trout|5|21|buy|7|1700000000000000000");
    }

    #[test]
    fn settle_buy_trout_happy_path() {
        let mut c = world(10_000, 0);
        let r = settle(&mut c, deal("fish_trout", "buy", 2, 60, 1)); // trout at target: floor = ask = 60
        assert_eq!(r.player.balances["coin"], U128(880));
        assert_eq!(r.player.balances["fish_trout"], U128(2));
        assert_eq!(r.merchant_stock, 38);
        assert_eq!(r.merchant_purse, U128(10_120));
    }

    #[test]
    fn settle_sell_happy_path() {
        let mut c = world(10_000, 5);
        let r = settle(&mut c, deal("fish_trout", "sell", 5, 48, 1)); // bid 48 at target
        assert_eq!(r.player.balances["coin"], U128(1_240));
        assert_eq!(r.merchant_stock, 45);
    }

    #[test]
    #[should_panic(expected = "BadGood")]
    fn ore_to_fishmonger_rejected() {
        let mut c = world(10_000, 0);
        settle(&mut c, deal("ore_iron", "buy", 1, 90, 1));
    }

    #[test]
    fn specialist_sells_above_normal_ceiling() {
        let mut c = world(10_000, 2);
        c.set_class("roblox:1".into(), "fisher".into());
        settle(&mut c, deal("fish_trout", "sell", 1, 52, 1)); // 48 x 110% = 52
    }

    #[test]
    #[should_panic(expected = "PriceOutOfRoom")]
    fn non_specialist_capped_at_normal_ceiling() {
        let mut c = world(10_000, 2);
        c.set_class("roblox:1".into(), "miner".into());
        settle(&mut c, deal("fish_trout", "sell", 1, 52, 1));
    }

    #[test]
    #[should_panic(expected = "BadSignature")]
    fn bad_signature() {
        let mut c = world(10_000, 0);
        let d = deal("fish_trout", "buy", 1, 60, 1);
        let s = sig(&sk(8), &d);
        c.settle_deal(d, s);
    }

    #[test]
    #[should_panic(expected = "NonceUsed")]
    fn nonce_reuse() {
        let mut c = world(10_000, 0);
        settle(&mut c, deal("fish_trout", "buy", 1, 60, 1));
        settle(&mut c, deal("fish_trout", "buy", 1, 61, 1));
    }

    #[test]
    #[should_panic(expected = "Expired")]
    fn expired() {
        let mut c = world(10_000, 0);
        ctx(GAME, 0, FAR + 1);
        settle(&mut c, deal("fish_trout", "buy", 1, 60, 1));
    }

    #[test]
    #[should_panic(expected = "PriceOutOfRoom")]
    fn price_below_floor() {
        let mut c = world(10_000, 0);
        c.add(FISH_M, "fish_trout", 40); // stock 80: ask 30, floor 18
        settle(&mut c, deal("fish_trout", "buy", 1, 17, 1));
    }

    #[test]
    #[should_panic(expected = "MerchantPurseEmpty")]
    fn purse_empty() {
        let mut c = world(10, 1);
        settle(&mut c, deal("fish_trout", "sell", 1, 48, 1));
    }

    #[test]
    #[should_panic(expected = "InsufficientGoods")]
    fn insufficient_goods() {
        let mut c = world(10_000, 1);
        settle(&mut c, deal("fish_trout", "sell", 2, 48, 1));
    }

    #[test]
    #[should_panic(expected = "BadQty")]
    fn qty_limit() {
        let mut c = world(10_000, 0);
        settle(&mut c, deal("fish_trout", "buy", 11, 60, 1));
    }

    #[test]
    #[should_panic(expected = "NotGame")]
    fn settle_requires_game() {
        let mut c = world(10_000, 0);
        ctx("alice.testnet", 0, 1);
        settle(&mut c, deal("fish_trout", "buy", 1, 60, 1));
    }

    #[test]
    fn day_tick_per_item() {
        let mut c = world(10_000, 0);
        c.sub(FISH_M, "fish_trout", 20); // trout 20 of 40
        ctx(GAME, 0, 1 + 300_000_000_000);
        assert!(c.day_tick());
        assert_eq!(c.bal(FISH_M, "fish_trout"), 26); // +8 restock -> 28, burn 2 -> 26
        assert_eq!(c.bal(FISH_M, "fish_sardine"), 108); // at target: burn 12
        ctx(GAME, 0, 1 + 400_000_000_000);
        assert!(!c.day_tick());
    }
}
