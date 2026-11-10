//! Haggle Town pricing rules. This file is the whole economy; the contract and the
//! simulator both call it, and the backend's TypeScript port is tested against its vectors.
//!
//! - ask:   what a merchant charges. base x target / stock, never below half or above triple base.
//! - bid:   what a merchant pays when you sell to it: 80% of ask.
//! - floor: lowest price a merchant accepts when selling. Overstocked merchants give up to 40% off;
//!          merchants at or below target give no discount.
//! - ceil:  highest price a merchant pays when buying. Understocked merchants pay up to 40% over bid,
//!          but never more than their purse can cover for the whole deal.
//! - burn:  every game day each merchant uses up 10% of its stock (rounded down), so demand never dies.
//!
//! All money is integer Coin; every division rounds down.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Good {
    Wood,
    Fish,
    Iron,
}

impl Good {
    pub fn from_str(s: &str) -> Option<Good> {
        match s {
            "wood" => Some(Good::Wood),
            "fish" => Some(Good::Fish),
            "iron" => Some(Good::Iron),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Good::Wood => "wood",
            Good::Fish => "fish",
            Good::Iron => "iron",
        }
    }

    pub fn base(&self) -> u128 {
        match self {
            Good::Wood => 50,
            Good::Fish => 80,
            Good::Iron => 150,
        }
    }
}

pub const TARGET: u32 = 100;
pub const BID_PCT: u128 = 80;
pub const MAX_DISCOUNT_PCT: u32 = 40;
pub const MAX_PREMIUM_PCT: u32 = 40;
pub const BURN_PCT: u32 = 10;
pub const PLAYER_GRANT: u128 = 1000;

pub fn ask(good: Good, stock: u32, target: u32) -> u128 {
    let base = good.base();
    let raw = base * target as u128 / stock.max(1) as u128;
    raw.clamp(base / 2, base * 3)
}

pub fn bid(good: Good, stock: u32, target: u32) -> u128 {
    ask(good, stock, target) * BID_PCT / 100
}

/// (floor, ask) for a player buying from the merchant.
pub fn buy_room(good: Good, stock: u32, target: u32) -> (u128, u128) {
    let a = ask(good, stock, target);
    let d = pct_over(stock, target, MAX_DISCOUNT_PCT);
    (a * (100 - d as u128) / 100, a)
}

/// (bid, ceiling) for a player selling `qty` to the merchant; None if the purse cannot pay bid x qty.
pub fn sell_room(good: Good, stock: u32, target: u32, purse: u128, qty: u32) -> Option<(u128, u128)> {
    let b = bid(good, stock, target);
    let qty = qty.max(1) as u128;
    if purse < b * qty {
        return None;
    }
    let p = pct_over(target, stock, MAX_PREMIUM_PCT);
    let ceil = (b * (100 + p as u128) / 100).min(purse / qty);
    Some((b, ceil.max(b)))
}

pub fn burn(stock: u32) -> u32 {
    stock - stock * BURN_PCT / 100
}

/// How far `a` is above `b`, in percent of `target`-like `b`, capped at `cap`. 0 when a <= b.
fn pct_over(a: u32, b: u32, cap: u32) -> u32 {
    if a <= b || b == 0 {
        return 0;
    }
    (((a - b) as u64 * 100 / b as u64) as u32).min(cap)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test] fn ask_at_target_is_base() { assert_eq!(ask(Good::Wood, 100, 100), 50); }
    #[test] fn ask_rises_when_stock_falls() { assert_eq!(ask(Good::Wood, 50, 100), 100); }
    #[test] fn ask_clamped_high() { assert_eq!(ask(Good::Iron, 1, 100), 450); assert_eq!(ask(Good::Iron, 0, 100), 450); }
    #[test] fn ask_clamped_low() { assert_eq!(ask(Good::Fish, 1000, 100), 40); }
    #[test] fn bid_is_80_pct() { assert_eq!(bid(Good::Wood, 100, 100), 40); }
    #[test] fn overstock_gives_discount() { assert_eq!(buy_room(Good::Wood, 140, 100), (21, 35)); }
    #[test] fn understock_no_discount() { let (f, a) = buy_room(Good::Iron, 50, 100); assert_eq!(f, a); }
    #[test] fn understock_gives_premium() { assert_eq!(sell_room(Good::Wood, 50, 100, 10_000, 1), Some((80, 112))); }
    #[test] fn empty_purse_refuses() { assert_eq!(sell_room(Good::Wood, 100, 100, 39, 1), None); }
    #[test] fn ceiling_capped_by_purse() { assert_eq!(sell_room(Good::Wood, 50, 100, 500, 5), Some((80, 100))); }
    #[test] fn burn_10_pct_floor() { assert_eq!(burn(100), 90); assert_eq!(burn(9), 9); assert_eq!(burn(15), 14); }
    #[test] fn good_roundtrip() {
        for g in [Good::Wood, Good::Fish, Good::Iron] { assert_eq!(Good::from_str(g.as_str()), Some(g)); }
        assert_eq!(Good::from_str("gold"), None);
    }
}
