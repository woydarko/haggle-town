// Writes economy/test-vectors.json: the backend's TypeScript pricing port is tested against it.
// Run: cargo test -p economy -- --ignored write_vectors
use economy::pricing::*;

#[test]
#[ignore]
fn write_vectors() {
    let mut rows = Vec::new();
    for good in [Good::Wood, Good::Fish, Good::Iron] {
        for stock in [0u32, 1, 9, 15, 50, 99, 100, 101, 140, 200, 1000] {
            for purse in [39u128, 500, 10_000] {
                for qty in [1u32, 5, 10] {
                    let (f, a) = buy_room(good, stock, TARGET);
                    let sell = match sell_room(good, stock, TARGET, purse, qty) {
                        Some((b, c)) => format!("[{b},{c}]"),
                        None => "null".to_string(),
                    };
                    rows.push(format!(
                        "{{\"good\":\"{}\",\"stock\":{stock},\"target\":{TARGET},\"purse\":{purse},\"qty\":{qty},\"ask\":{},\"bid\":{},\"buy_room\":[{f},{a}],\"sell_room\":{sell},\"burn\":{}}}",
                        good.as_str(),
                        ask(good, stock, TARGET),
                        bid(good, stock, TARGET),
                        burn(stock)
                    ));
                }
            }
        }
    }
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/test-vectors.json");
    std::fs::write(path, format!("[\n{}\n]\n", rows.join(",\n"))).unwrap();
}
