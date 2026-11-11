//! Fast-forward simulator: a week of Haggle Town with scripted bot traders (Fisher, Logger, Miner and
//! classless), using the same pricing and drop rules as the contract (economy/src/pricing.rs).
//! Writes JSON for the dashboard. Usage: cargo run -p sim -- --days 7 --bots 10 --seed 42 --out web/public/sim/week.json

use economy::pricing::{self, Category, Item, Tier};

pub const TICKS_PER_DAY: u32 = 60; // one tick = one game minute-ish (5 real seconds)
const GATHER_P: [f64; 3] = [0.3, 0.5, 0.15]; // per Category::ALL (fish, wood, ore): wood fast, ore slow
const CLASSES: [Option<Category>; 4] = [Some(Category::Fish), Some(Category::Wood), Some(Category::Ore), None];
const DOUBLE_DROP: f64 = 0.15; // specialist yield bonus (spec s4)
const SELL_AT_PCT: u128 = 85; // bots sell when the merchant bids at least this share of the base price

pub struct Point {
    pub tick: u32,
    pub day: u32,
    pub item: &'static str,
    pub ask: u128,
    pub bid: u128,
    pub stock: u32,
    pub purse: u128,
}

pub struct Run {
    pub days: u32,
    pub series: Vec<Point>,
}

/// One merchant per category: a stock per tier and one purse shared by its four items (as on chain).
struct Merchant {
    stock: [u32; 4],
    purse: u128,
}

struct Bot {
    coin: u128,
    items: [u32; 12], // Item::all() order: category * 4 + tier
    class: Option<Category>,
}

/// Tiny deterministic LCG so runs are reproducible without a rand dependency.
struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> f64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (self.0 >> 11) as f64 / (1u64 << 53) as f64
    }
}

pub fn run(seed: u64, days: u32, bots: usize) -> Run {
    let mut rng = Lcg(seed ^ 0x9E37_79B9_7F4A_7C15);
    let mut merchants: Vec<Merchant> = Category::ALL
        .iter()
        .map(|_| Merchant { stock: Tier::ALL.map(|t| t.target()), purse: 10_000 })
        .collect();
    let mut bots: Vec<Bot> = (0..bots).map(|b| Bot { coin: 1_000, items: [0; 12], class: CLASSES[b % CLASSES.len()] }).collect();
    let mut series = Vec::new();

    for tick in 0..days * TICKS_PER_DAY {
        let day = tick / TICKS_PER_DAY + 1;
        for bot in bots.iter_mut() {
            for (c, cat) in Category::ALL.iter().enumerate() {
                let specialist = bot.class == Some(*cat);
                // Gather: hidden roll + minigame quality 30..90, same rule as the server.
                if rng.next() < GATHER_P[c] {
                    let roll = (rng.next() * 10_000.0) as u32;
                    let quality = 30 + (rng.next() * 60.0) as u32;
                    let tier = pricing::roll_tier(roll, specialist, quality);
                    let qty = if specialist && rng.next() < DOUBLE_DROP { 2 } else { 1 };
                    bot.items[c * 4 + tier as usize] += qty;
                }
                let m = &mut merchants[c];
                for (t, tier) in Tier::ALL.iter().enumerate() {
                    let item = Item::of(*cat, *tier);
                    let k = c * 4 + t;
                    // Sell when the merchant pays well; haggle to the middle of the room.
                    if bot.items[k] > 0 && pricing::bid(item, m.stock[t]) * 100 >= item.base() * SELL_AT_PCT {
                        let qty = bot.items[k].min(10);
                        if let Some((lo, hi)) = pricing::sell_room(item, m.stock[t], m.purse, qty, specialist) {
                            let price = (lo + hi) / 2;
                            bot.items[k] -= qty;
                            bot.coin += price * qty as u128;
                            m.stock[t] += qty;
                            m.purse -= price * qty as u128;
                        }
                    }
                    // Everyday demand (cook, build, forge), rarer for rarer items; the goods leave the economy.
                    if m.stock[t] > 0 && rng.next() < 0.06 * (item.target() as f64 / 120.0).sqrt() {
                        let (lo, hi) = pricing::buy_room(item, m.stock[t]);
                        let price = (lo + hi) / 2;
                        let qty = (1 + (rng.next() * 3.0) as u32).min(m.stock[t]);
                        if bot.coin >= price * qty as u128 * 2 {
                            bot.coin -= price * qty as u128;
                            m.stock[t] -= qty;
                            m.purse += price * qty as u128;
                        }
                    }
                    // Buy cheap from an overstocked merchant, to resell when prices recover.
                    if m.stock[t] > item.target() * 6 / 5 && rng.next() < 0.3 {
                        let (lo, hi) = pricing::buy_room(item, m.stock[t]);
                        let price = (lo + hi) / 2;
                        let qty = 5u32.min(m.stock[t]);
                        if bot.coin >= price * qty as u128 {
                            bot.coin -= price * qty as u128;
                            bot.items[k] += qty;
                            m.stock[t] -= qty;
                            m.purse += price * qty as u128;
                        }
                    }
                }
            }
        }
        if (tick + 1) % TICKS_PER_DAY == 0 {
            for m in merchants.iter_mut() {
                for (t, tier) in Tier::ALL.iter().enumerate() {
                    m.stock[t] = pricing::burn(m.stock[t] + pricing::restock(m.stock[t], tier.target()));
                }
            }
        }
        for (c, cat) in Category::ALL.iter().enumerate() {
            let m = &merchants[c];
            for (t, tier) in Tier::ALL.iter().enumerate() {
                let item = Item::of(*cat, *tier);
                series.push(Point {
                    tick,
                    day,
                    item: item.id(),
                    ask: pricing::ask(item, m.stock[t]),
                    bid: pricing::bid(item, m.stock[t]),
                    stock: m.stock[t],
                    purse: m.purse,
                });
            }
        }
    }
    Run { days, series }
}

pub fn to_json(r: &Run) -> String {
    let pts: Vec<String> = r
        .series
        .iter()
        .map(|p| {
            format!(
                "{{\"tick\":{},\"day\":{},\"item\":\"{}\",\"ask\":{},\"bid\":{},\"stock\":{},\"purse\":{}}}",
                p.tick, p.day, p.item, p.ask, p.bid, p.stock, p.purse
            )
        })
        .collect();
    format!("{{\"days\":{},\"ticksPerDay\":{},\"series\":[{}]}}", r.days, TICKS_PER_DAY, pts.join(","))
}

fn arg(args: &[String], name: &str, default: &str) -> String {
    args.iter().position(|a| a == name).and_then(|i| args.get(i + 1)).cloned().unwrap_or_else(|| default.to_string())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let days: u32 = arg(&args, "--days", "7").parse().expect("--days must be a number");
    let bots: usize = arg(&args, "--bots", "10").parse().expect("--bots must be a number");
    let seed: u64 = arg(&args, "--seed", "42").parse().expect("--seed must be a number");
    let out = arg(&args, "--out", "web/public/sim/week.json");
    let r = run(seed, days, bots);
    if let Some(dir) = std::path::Path::new(&out).parent() {
        std::fs::create_dir_all(dir).expect("create output dir");
    }
    std::fs::write(&out, to_json(&r)).expect("write output");
    println!("wrote {} points for {} days to {}", r.series.len(), days, out);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    /// Days on which the ask of `item` changed tick to tick.
    fn change_days(r: &Run, item: &str) -> usize {
        let pts: Vec<&Point> = r.series.iter().filter(|p| p.item == item).collect();
        let mut days = HashSet::new();
        for w in pts.windows(2) {
            if w[1].ask != w[0].ask {
                days.insert(w[1].day);
            }
        }
        days.len()
    }

    #[test]
    fn every_category_moves_on_three_days() {
        let r = run(42, 7, 10);
        for item in ["fish_sardine", "wood_pine", "ore_copper"] {
            let d = change_days(&r, item);
            assert!(d >= 3, "{item} ask changed on only {d} days");
        }
    }

    #[test]
    fn legendary_prices_move() {
        let r = run(42, 7, 10);
        for item in ["fish_koi", "wood_redwood", "ore_crystal"] {
            let d = change_days(&r, item);
            assert!(d >= 2, "{item} ask changed on only {d} days");
        }
    }

    #[test]
    fn no_merchant_dead_all_week() {
        let r = run(42, 7, 10);
        for cat in ["fish", "wood", "ore"] {
            let dead_all = r.series.iter().filter(|p| p.item.starts_with(cat)).all(|p| p.purse == 0);
            assert!(!dead_all, "{cat} merchant broke all week");
        }
    }

    #[test]
    fn deterministic_for_a_seed() {
        assert_eq!(to_json(&run(42, 7, 10)), to_json(&run(42, 7, 10)));
        assert_ne!(to_json(&run(42, 7, 10)), to_json(&run(7, 7, 10)));
    }

    #[test]
    fn json_shape() {
        let r = run(1, 1, 2);
        assert_eq!(r.series.len(), 60 * 12, "one point per item per tick");
        let j = to_json(&r);
        assert!(j.starts_with("{\"days\":1,\"ticksPerDay\":60,\"series\":["));
        assert!(j.contains("\"item\":\"wood_pine\""));
    }
}
