// Writes economy/test-vectors.json: the backend's TypeScript pricing port is tested against it.
// Run: cargo test -p economy -- --ignored write_vectors
use economy::pricing::*;

#[test]
#[ignore]
fn write_vectors() {
    let mut prices = Vec::new();
    for item in Item::all() {
        for stock in [0u32, 1, 3, 12, 40, 100, 120, 200] {
            for purse in [50u128, 10_000] {
                for qty in [1u32, 5] {
                    for specialist in [false, true] {
                        let (f, a) = buy_room(item, stock);
                        let sell = match sell_room(item, stock, purse, qty, specialist) {
                            Some((b, c)) => format!("[{b},{c}]"),
                            None => "null".to_string(),
                        };
                        prices.push(format!(
                            "{{\"item\":\"{}\",\"stock\":{stock},\"purse\":{purse},\"qty\":{qty},\"specialist\":{specialist},\"ask\":{},\"bid\":{},\"buy_room\":[{f},{a}],\"sell_room\":{sell},\"burn\":{},\"restock\":{}}}",
                            item.id(),
                            ask(item, stock),
                            bid(item, stock),
                            burn(stock),
                            restock(stock, item.target())
                        ));
                    }
                }
            }
        }
    }
    let mut rolls = Vec::new();
    for roll in [0u32, 4999, 5000, 6999, 7000, 9099, 9100, 9699, 9700, 9899, 9900, 9999] {
        for specialist in [false, true] {
            for quality in [0u32, 50, 100] {
                rolls.push(format!(
                    "{{\"roll\":{roll},\"specialist\":{specialist},\"quality\":{quality},\"tier\":\"{}\"}}",
                    roll_tier(roll, specialist, quality).as_str()
                ));
            }
        }
    }
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/test-vectors.json");
    std::fs::write(path, format!("{{\"prices\":[\n{}\n],\"rolls\":[\n{}\n]}}\n", prices.join(",\n"), rolls.join(",\n"))).unwrap();
}
