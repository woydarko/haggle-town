//! Fast-forward simulator: a week of Haggle Town with scripted bot traders, using the same
//! pricing rules as the contract (economy/src/pricing.rs). Writes JSON for the dashboard.
//! Usage: cargo run -p sim -- --days 7 --bots 10 --seed 42 --out web/public/sim/week.json

use economy::pricing::{self, Good, TARGET};

pub const TICKS_PER_DAY: u32 = 60; // one tick = one game minute-ish (5 real seconds)
const GOODS: [Good; 3] = [Good::Wood, Good::Fish, Good::Iron];
const GATHER_P: [f64; 3] = [0.5, 0.3, 0.15]; // wood fast, fish medium, iron slow

pub struct Point {
    pub tick: u32,
    pub day: u32,
    pub good: &'static str,
    pub ask: u128,
    pub bid: u128,
    pub stock: u32,
    pub purse: u128,
}

pub struct Run {
    pub days: u32,
    pub series: Vec<Point>,
}

struct Merchant {
    stock: u32,
    purse: u128,
}

struct Bot {
    coin: u128,
    goods: [u32; 3],
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
    let mut merchants: Vec<Merchant> = GOODS.iter().map(|_| Merchant { stock: TARGET, purse: 10_000 }).collect();
    let mut bots: Vec<Bot> = (0..bots).map(|_| Bot { coin: 1_000, goods: [0; 3] }).collect();
    let mut series = Vec::new();

    for tick in 0..days * TICKS_PER_DAY {
        let day = tick / TICKS_PER_DAY + 1;
        for bot in bots.iter_mut() {
            for (i, good) in GOODS.iter().enumerate() {
                let m = &mut merchants[i];
                if rng.next() < GATHER_P[i] {
                    bot.goods[i] += 1;
                }
                // Sell when the merchant pays well; haggle to the middle of the room.
                let bid = pricing::bid(*good, m.stock, TARGET);
                if bot.goods[i] > 0 && bid * 10 >= good.base() * 9 {
                    let qty = bot.goods[i].min(10);
                    if let Some((lo, hi)) = pricing::sell_room(*good, m.stock, TARGET, m.purse, qty) {
                        let price = (lo + hi) / 2;
                        bot.goods[i] -= qty;
                        bot.coin += price * qty as u128;
                        m.stock += qty;
                        m.purse -= price * qty as u128;
                    }
                }
                // Everyday demand: bots buy a little to use (cook, build, forge); the goods leave the economy.
                if m.stock > 0 && rng.next() < 0.06 {
                    let (lo, hi) = pricing::buy_room(*good, m.stock, TARGET);
                    let price = (lo + hi) / 2;
                    let qty = (1 + (rng.next() * 3.0) as u32).min(m.stock);
                    if bot.coin >= price * qty as u128 * 2 {
                        bot.coin -= price * qty as u128;
                        m.stock -= qty;
                        m.purse += price * qty as u128;
                    }
                }
                // Buy cheap from an overstocked merchant, to resell when prices recover.
                if m.stock > TARGET * 6 / 5 && rng.next() < 0.3 {
                    let (lo, hi) = pricing::buy_room(*good, m.stock, TARGET);
                    let price = (lo + hi) / 2;
                    let qty = 5u32.min(m.stock);
                    if bot.coin >= price * qty as u128 {
                        bot.coin -= price * qty as u128;
                        bot.goods[i] += qty;
                        m.stock -= qty;
                        m.purse += price * qty as u128;
                    }
                }
            }
        }
        if (tick + 1) % TICKS_PER_DAY == 0 {
            for m in merchants.iter_mut() {
                m.stock = pricing::burn(m.stock);
            }
        }
        for (i, good) in GOODS.iter().enumerate() {
            let m = &merchants[i];
            series.push(Point {
                tick,
                day,
                good: good.as_str(),
                ask: pricing::ask(*good, m.stock, TARGET),
                bid: pricing::bid(*good, m.stock, TARGET),
                stock: m.stock,
                purse: m.purse,
            });
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
                "{{\"tick\":{},\"day\":{},\"good\":\"{}\",\"ask\":{},\"bid\":{},\"stock\":{},\"purse\":{}}}",
                p.tick, p.day, p.good, p.ask, p.bid, p.stock, p.purse
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

    #[test]
    fn week_moves_prices() {
        let r = run(42, 7, 10);
        for good in ["wood", "fish", "iron"] {
            let pts: Vec<&Point> = r.series.iter().filter(|p| p.good == good).collect();
            let mut days = HashSet::new();
            for w in pts.windows(2) {
                if w[1].ask != w[0].ask {
                    days.insert(w[1].day);
                }
            }
            assert!(days.len() >= 3, "{good} ask changed on only {} days", days.len());
        }
    }

    #[test]
    fn no_merchant_dead_all_week() {
        let r = run(42, 7, 10);
        for good in ["wood", "fish", "iron"] {
            let dead_all = r.series.iter().filter(|p| p.good == good).all(|p| p.stock == 0 && p.purse == 0);
            assert!(!dead_all, "{good} merchant dead all week");
        }
    }

    #[test]
    fn deterministic_for_a_seed() {
        assert_eq!(to_json(&run(42, 7, 10)), to_json(&run(42, 7, 10)));
        assert_ne!(to_json(&run(42, 7, 10)), to_json(&run(7, 7, 10)));
    }

    #[test]
    fn json_shape() {
        let j = to_json(&run(1, 1, 2));
        assert!(j.starts_with("{\"days\":1,\"ticksPerDay\":60,\"series\":["));
        assert!(j.contains("\"good\":\"wood\""));
    }
}
