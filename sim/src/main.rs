//! Fast-forward simulator: a week of Haggle Town with scripted bot traders (Fisher, Logger, Miner and
//! classless), using the same pricing and drop rules as the contract (economy/src/pricing.rs).
//! Writes JSON for the dashboard. Usage: cargo run -p sim -- --days 7 --bots 10 --seed 42 --out web/public/sim/week.json

use economy::coin;
use economy::pricing::{self, Category, Item, Tier};

pub const TICKS_PER_DAY: u32 = 60; // one tick = one game minute-ish (5 real seconds)
const GATHER_P: [f64; 3] = [0.3, 0.5, 0.15]; // per Category::ALL (fish, wood, ore): wood fast, ore slow
const CLASSES: [Option<Category>; 4] = [Some(Category::Fish), Some(Category::Wood), Some(Category::Ore), None];
const DOUBLE_DROP: f64 = 0.15; // specialist yield bonus (spec s4)
/// Forge (server/src/game/forge.ts): extra-catch chance by tool level (index = level). A tool's next level costs goods
/// from the two other trades: level 2 = 3 common of each, level 3 = 2 rare of each; the goods are burned.
pub const TOOL_BONUS: [f64; 4] = [0.0, 0.0, 0.25, 0.5];
const FORGE_TRY: f64 = 0.02; // chance per tick that a bot works on its tool (about once a game day)
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
    pub gathered: u32,
    /// Goods bots bought from merchants only to forge with, and tool upgrades done.
    pub bought: u32,
    pub forged: u32,
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
    tools: [u32; 3], // tool level per Category::ALL
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
    run_with(seed, days, bots, TOOL_BONUS)
}

/// `bonus` = extra-catch chance per tool level; all zero = no Forge (bots never upgrade).
pub fn run_with(seed: u64, days: u32, bots: usize, bonus: [f64; 4]) -> Run {
    let forge = bonus.iter().any(|b| *b > 0.0);
    let (mut gathered, mut bought, mut forged) = (0u32, 0u32, 0u32);
    let mut rng = Lcg(seed ^ 0x9E37_79B9_7F4A_7C15);
    let mut merchants: Vec<Merchant> = Category::ALL
        .iter()
        .map(|_| Merchant { stock: Tier::ALL.map(|t| t.target()), purse: 10_000 })
        .collect();
    let mut bots: Vec<Bot> = (0..bots).map(|b| Bot { coin: 1_000, items: [0; 12], class: CLASSES[b % CLASSES.len()], tools: [1; 3] }).collect();
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
                    let chance = if specialist { DOUBLE_DROP } else { 0.0 } + bonus[bot.tools[c] as usize];
                    let qty = if chance > 0.0 && rng.next() < chance { 2 } else { 1 };
                    bot.items[c * 4 + tier as usize] += qty;
                    gathered += qty;
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
        // Forge: each bot works on its trade's tool (classless: the axe); it buys what it lacks from the other merchants.
        if forge {
            for bot in bots.iter_mut() {
                let c = bot.class.and_then(|k| Category::ALL.iter().position(|x| *x == k)).unwrap_or(1);
                let level = bot.tools[c];
                if level >= 3 || rng.next() >= FORGE_TRY {
                    continue;
                }
                let (tier, qty) = if level == 1 { (0usize, 3u32) } else { (1usize, 2u32) };
                let mut ready = true;
                for o in (0..3).filter(|&o| o != c) {
                    let k = o * 4 + tier;
                    let missing = qty.saturating_sub(bot.items[k]);
                    if missing == 0 {
                        continue;
                    }
                    let m = &mut merchants[o];
                    let (lo, hi) = pricing::buy_room(Item::of(Category::ALL[o], Tier::ALL[tier]), m.stock[tier]);
                    let cost = (lo + hi) / 2 * missing as u128;
                    if m.stock[tier] >= missing && bot.coin >= cost + 200 {
                        bot.coin -= cost;
                        m.purse += cost;
                        m.stock[tier] -= missing;
                        bot.items[k] += missing;
                        bought += missing;
                    } else {
                        ready = false;
                    }
                }
                if ready {
                    for o in (0..3).filter(|&o| o != c) {
                        bot.items[o * 4 + tier] -= qty; // burned
                    }
                    bot.tools[c] += 1;
                    forged += 1;
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
    Run { days, series, gathered, bought, forged }
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

/// Backer-coin index per merchant (fish, wood, ore) at the end of every market day, read back from a run's
/// series exactly as the coin contract reads get_market: net worth = purse + stock x bid, one capped step a day.
pub fn coin_index(r: &Run, cap_bp: u32) -> Vec<[u128; 3]> {
    let (mut index, mut last, mut out) = ([coin::INDEX_ONE; 3], [0u128; 3], Vec::new());
    for end in r.series.chunks(12).filter(|c| (c[0].tick + 1) % TICKS_PER_DAY == 0) {
        for (c, cat) in ["fish", "wood", "ore"].iter().enumerate() {
            let rows: Vec<&Point> = end.iter().filter(|p| p.item.starts_with(cat)).collect();
            let worth = coin::net_worth(rows[0].purse, &rows.iter().map(|p| (p.stock, p.bid)).collect::<Vec<_>>());
            index[c] = coin::apply(index[c], coin::step_bp(last[c], worth, cap_bp));
            last[c] = worth;
        }
        out.push(index);
    }
    out
}

/// 60-day coin scenarios: quiet town, normal, busy town (bot count) x daily cap. Supply = index (1.00 at launch).
fn coin_report() {
    println!("60 days, 3 seeds each. final = supply multiple at day 60 (fish/wood/ore); range = lowest..highest any day; capped = share of days that hit the cap");
    for bots in [4usize, 10, 30] {
        for cap in [300u32, 500, 1000] {
            let (mut fin, mut lo, mut hi, mut capped, mut days) = ([0f64; 3], f64::MAX, 0f64, 0usize, 0usize);
            for seed in [1u64, 42, 7] {
                let idx = coin_index(&run(seed, 60, bots), cap);
                let f = |x: u128| x as f64 / coin::INDEX_ONE as f64;
                let mut prev = [coin::INDEX_ONE; 3];
                for d in &idx {
                    for c in 0..3 {
                        lo = lo.min(f(d[c]));
                        hi = hi.max(f(d[c]));
                        let step = (f(d[c]) / f(prev[c]) - 1.0).abs() * 10_000.0;
                        capped += (step + 0.5 >= cap as f64) as usize;
                        days += 1;
                    }
                    prev = *d;
                }
                for c in 0..3 {
                    fin[c] += f(idx[idx.len() - 1][c]) / 3.0;
                }
            }
            println!(
                "bots {bots:>2} cap {:>4.1}%/day: final {:.2}/{:.2}/{:.2} range {lo:.2}..{hi:.2} capped {:>3.0}% of days",
                cap as f64 / 100.0, fin[0], fin[1], fin[2], capped as f64 * 100.0 / days as f64
            );
        }
    }
}

/// One line per run: goods gathered, forge activity, and end-of-run price and purse health.
pub fn report(r: &Run) -> String {
    let last = &r.series[r.series.len() - 12..];
    let ratio = |id: &str| {
        let p = last.iter().find(|p| p.item == id).unwrap();
        p.ask as f64 / Item::from_id(id).unwrap().base() as f64
    };
    let min_purse = |cat: &str| r.series.iter().filter(|p| p.item.starts_with(cat)).map(|p| p.purse).min().unwrap_or(0);
    format!(
        "gathered {:>5} | bought for forge {:>4} | upgrades {:>3} | ask/base sardine {:.2} pine {:.2} copper {:.2} trout {:.2} oak {:.2} iron {:.2} | min purse fish {:>6} wood {:>6} ore {:>6}",
        r.gathered, r.bought, r.forged,
        ratio("fish_sardine"), ratio("wood_pine"), ratio("ore_copper"), ratio("fish_trout"), ratio("wood_oak"), ratio("ore_iron"),
        min_purse("fish"), min_purse("wood"), min_purse("ore"),
    )
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--coins") {
        coin_report();
        return;
    }
    if args.iter().any(|a| a == "--compare") {
        for (name, b) in [("no forge     ", [0.0; 4]), ("forge 25/50% ", TOOL_BONUS), ("forge 50/100%", [0.0, 0.0, 0.5, 1.0])] {
            for seed in [1u64, 42, 7] {
                println!("{name} seed {seed:>2}: {}", report(&run_with(seed, 7, 10, b)));
            }
        }
        return;
    }
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
    fn forge_buys_across_trades_and_upgrades() {
        let r = run(42, 7, 10);
        assert!(r.forged >= 5, "only {} upgrades", r.forged);
        assert!(r.bought > 0, "bots never bought goods to forge");
    }

    #[test]
    fn no_forge_means_no_upgrades() {
        let r = run_with(42, 7, 10, [0.0; 4]);
        assert_eq!((r.forged, r.bought), (0, 0));
    }

    #[test]
    fn coins_move_daily_but_stay_bounded() {
        let idx = coin_index(&run(42, 60, 10), 500);
        assert_eq!(idx.len(), 60, "one rebase per market day");
        for c in 0..3 {
            let moved = idx.windows(2).filter(|w| w[0][c] != w[1][c]).count();
            assert!(moved >= 40, "coin {c} moved on only {moved} of 59 days");
            let last = idx[59][c] as f64 / coin::INDEX_ONE as f64;
            assert!((0.2..5.0).contains(&last), "coin {c} ended at {last}");
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
