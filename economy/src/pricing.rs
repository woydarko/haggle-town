//! Haggle Town pricing rules. This file is the whole economy; the contract and the
//! simulator call it, and the backend's TypeScript port is tested against its vectors.
//!
//! - items:   three categories (fish, wood, ore) x four tiers (common, rare, epic, legendary).
//!            base price = category base x tier multiplier; each item has its own target stock.
//! - ask:     what a merchant charges. base x target / stock, never below half or above triple base.
//! - bid:     what a merchant pays when you sell to it: 80% of ask.
//! - floor:   lowest price a merchant accepts when selling. Overstocked merchants give up to 40% off.
//! - ceil:    highest price a merchant pays when buying. Understocked merchants pay up to 40% over bid,
//!            specialists of that category get 10% more on top, never more than the purse covers.
//! - restock: before the daily burn, a merchant below target brings in 40% of the gap from outside town.
//! - burn:    every game day each merchant uses up 10% of its stock (rounded down).
//! - drops:   tier odds in basis points; specialists roll better; minigame quality (0..100) moves
//!            up to 2000 bp from common to the rarer tiers (60/30/10).
//!
//! All money is integer Coin; every division rounds down.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Category {
    Fish,
    Wood,
    Ore,
}

impl Category {
    pub const ALL: [Category; 3] = [Category::Fish, Category::Wood, Category::Ore];

    pub fn from_str(s: &str) -> Option<Category> {
        match s {
            "fish" => Some(Category::Fish),
            "wood" => Some(Category::Wood),
            "ore" => Some(Category::Ore),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Category::Fish => "fish",
            Category::Wood => "wood",
            Category::Ore => "ore",
        }
    }

    pub fn base(&self) -> u128 {
        match self {
            Category::Fish => 20,
            Category::Wood => 15,
            Category::Ore => 30,
        }
    }

    /// The category a class specialises in.
    pub fn of_class(class: &str) -> Option<Category> {
        match class {
            "fisher" => Some(Category::Fish),
            "logger" => Some(Category::Wood),
            "miner" => Some(Category::Ore),
            _ => None,
        }
    }

    fn index(&self) -> usize {
        *self as usize
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Tier {
    Common,
    Rare,
    Epic,
    Legendary,
}

impl Tier {
    pub const ALL: [Tier; 4] = [Tier::Common, Tier::Rare, Tier::Epic, Tier::Legendary];

    pub fn mult(&self) -> u128 {
        [1, 3, 8, 30][*self as usize]
    }

    pub fn target(&self) -> u32 {
        [120, 40, 12, 3][*self as usize]
    }

    pub fn as_str(&self) -> &'static str {
        ["common", "rare", "epic", "legendary"][*self as usize]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Item {
    pub category: Category,
    pub tier: Tier,
}

const IDS: [[&str; 4]; 3] = [
    ["fish_sardine", "fish_trout", "fish_salmon", "fish_koi"],
    ["wood_pine", "wood_oak", "wood_maple", "wood_redwood"],
    ["ore_copper", "ore_iron", "ore_gold", "ore_crystal"],
];

impl Item {
    pub fn all() -> [Item; 12] {
        let mut out = [Item { category: Category::Fish, tier: Tier::Common }; 12];
        for (c, cat) in Category::ALL.iter().enumerate() {
            for (t, tier) in Tier::ALL.iter().enumerate() {
                out[c * 4 + t] = Item { category: *cat, tier: *tier };
            }
        }
        out
    }

    pub fn of(category: Category, tier: Tier) -> Item {
        Item { category, tier }
    }

    pub fn from_id(id: &str) -> Option<Item> {
        Item::all().into_iter().find(|i| i.id() == id)
    }

    pub fn id(&self) -> &'static str {
        IDS[self.category.index()][self.tier as usize]
    }

    pub fn base(&self) -> u128 {
        self.category.base() * self.tier.mult()
    }

    pub fn target(&self) -> u32 {
        self.tier.target()
    }
}

pub const BID_PCT: u128 = 80;
pub const MAX_DISCOUNT_PCT: u32 = 40;
pub const MAX_PREMIUM_PCT: u32 = 40;
pub const SPECIALIST_BONUS_PCT: u128 = 10;
pub const BURN_PCT: u32 = 10;
pub const RESTOCK_PCT: u32 = 40;
pub const PLAYER_GRANT: u128 = 1000;

const ODDS: [u32; 4] = [7000, 2200, 700, 100];
const SPECIALIST_ODDS: [u32; 4] = [5500, 3000, 1200, 300];

pub fn ask(item: Item, stock: u32) -> u128 {
    let base = item.base();
    let raw = base * item.target() as u128 / stock.max(1) as u128;
    raw.clamp(base / 2, base * 3)
}

pub fn bid(item: Item, stock: u32) -> u128 {
    ask(item, stock) * BID_PCT / 100
}

/// (floor, ask) for a player buying from the merchant.
pub fn buy_room(item: Item, stock: u32) -> (u128, u128) {
    let a = ask(item, stock);
    let d = pct_over(stock, item.target(), MAX_DISCOUNT_PCT);
    (a * (100 - d as u128) / 100, a)
}

/// (bid, ceiling) for a player selling `qty`; None if the purse cannot pay bid x qty.
pub fn sell_room(item: Item, stock: u32, purse: u128, qty: u32, specialist: bool) -> Option<(u128, u128)> {
    let b = bid(item, stock);
    let qty = qty.max(1) as u128;
    if purse < b * qty {
        return None;
    }
    let p = pct_over(item.target(), stock, MAX_PREMIUM_PCT);
    let mut ceil = b * (100 + p as u128) / 100;
    if specialist {
        ceil = ceil * (100 + SPECIALIST_BONUS_PCT) / 100;
    }
    Some((b, ceil.min(purse / qty).max(b)))
}

/// Tier for a roll in 0..10000 basis points.
pub fn roll_tier(roll_bp: u32, specialist: bool, quality: u32) -> Tier {
    let base = if specialist { SPECIALIST_ODDS } else { ODDS };
    let shift = quality.min(100) * 20;
    let odds = [base[0] - shift, base[1] + shift * 6 / 10, base[2] + shift * 3 / 10, base[3] + shift / 10];
    let mut acc = 0;
    for (i, w) in odds.iter().enumerate() {
        acc += w;
        if roll_bp < acc {
            return Tier::ALL[i];
        }
    }
    Tier::Legendary
}

/// Goods a merchant brings in from outside town each day: 40% of the gap to target, none at or above it.
pub fn restock(stock: u32, target: u32) -> u32 {
    target.saturating_sub(stock) * RESTOCK_PCT / 100
}

pub fn burn(stock: u32) -> u32 {
    stock - stock * BURN_PCT / 100
}

/// How far `a` is above `b`, in percent of `b`, capped at `cap`. 0 when a <= b.
fn pct_over(a: u32, b: u32, cap: u32) -> u32 {
    if a <= b || b == 0 {
        return 0;
    }
    (((a - b) as u64 * 100 / b as u64) as u32).min(cap)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn it(id: &str) -> Item { Item::from_id(id).unwrap() }

    #[test] fn item_ids_roundtrip() { for x in Item::all() { assert_eq!(Item::from_id(x.id()), Some(x)); } assert_eq!(Item::from_id("wood"), None); }
    #[test] fn base_is_category_times_tier() { assert_eq!(it("fish_koi").base(), 600); assert_eq!(it("ore_iron").base(), 90); assert_eq!(it("wood_pine").base(), 15); }
    #[test] fn targets_by_tier() { assert_eq!(it("wood_pine").target(), 120); assert_eq!(it("wood_redwood").target(), 3); }
    #[test] fn ask_at_target_is_base() { assert_eq!(ask(it("fish_koi"), 3), 600); assert_eq!(ask(it("fish_sardine"), 120), 20); }
    #[test] fn ask_clamped() { assert_eq!(ask(it("ore_gold"), 0), 720); assert_eq!(ask(it("fish_sardine"), 10_000), 10); }
    #[test] fn bid_is_80_pct() { assert_eq!(bid(it("ore_iron"), 40), 72); }
    #[test] fn overstock_discount() { let t = it("fish_trout"); let (f, a) = buy_room(t, 80); assert_eq!(a, 30); assert_eq!(f, 18); }
    #[test] fn specialist_sell_bonus() { let t = it("fish_trout"); let (_, c) = sell_room(t, 40, 100_000, 1, false).unwrap(); let (_, cs) = sell_room(t, 40, 100_000, 1, true).unwrap(); assert_eq!(cs, c * 110 / 100); }
    #[test] fn empty_purse_refuses() { assert_eq!(sell_room(it("ore_crystal"), 3, 10, 1, false), None); }
    #[test] fn class_categories() { assert_eq!(Category::of_class("fisher"), Some(Category::Fish)); assert_eq!(Category::of_class("logger"), Some(Category::Wood)); assert_eq!(Category::of_class("miner"), Some(Category::Ore)); assert_eq!(Category::of_class("king"), None); }
    #[test] fn roll_base_edges() { assert_eq!(roll_tier(0, false, 0), Tier::Common); assert_eq!(roll_tier(6999, false, 0), Tier::Common); assert_eq!(roll_tier(7000, false, 0), Tier::Rare); assert_eq!(roll_tier(9899, false, 0), Tier::Epic); assert_eq!(roll_tier(9900, false, 0), Tier::Legendary); }
    #[test] fn roll_specialist_and_quality() { assert_eq!(roll_tier(5500, true, 0), Tier::Rare); assert_eq!(roll_tier(5000, false, 100), Tier::Rare); assert_eq!(roll_tier(9700, true, 100), Tier::Legendary); }
    #[test] fn quality_is_clamped() { assert_eq!(roll_tier(5000, false, 999), roll_tier(5000, false, 100)); }
    #[test] fn restock_40_pct_of_gap() { assert_eq!(restock(37, 100), 25); assert_eq!(restock(90, 100), 4); assert_eq!(restock(99, 100), 0); }
    #[test] fn no_restock_at_or_above_target() { assert_eq!(restock(100, 100), 0); assert_eq!(restock(140, 100), 0); }
    #[test] fn idle_market_settles_near_target() { let mut s = 0u32; for _ in 0..200 { s += restock(s, 100); s = burn(s); } assert!((70..=85).contains(&s), "settled at {s}"); }
    #[test] fn burn_10_pct_floor() { assert_eq!(burn(100), 90); assert_eq!(burn(9), 9); assert_eq!(burn(15), 14); }
}
