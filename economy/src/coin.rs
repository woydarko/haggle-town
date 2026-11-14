//! Backer coins ($WOOD, $FISH, $SMITH): each coin's supply follows its merchant's net worth, one step per
//! market day. Shared by the coin contract (coin/) and the simulator (sim/), like pricing.rs.
//! Holders own shares; a balance is shares x index. A rebase changes the index, so every wallet moves by the
//! same percent at O(1) cost, and splitting coins across many accounts (sybils) gains nothing.

/// Fixed-point scale of the share index (coins per share).
pub const INDEX_ONE: u128 = 1_000_000_000_000;

/// A merchant's net worth: its purse plus every item it stocks, valued at its own bid.
pub fn net_worth(purse: u128, stock_and_bid: &[(u32, u128)]) -> u128 {
    purse + stock_and_bid.iter().map(|(s, b)| *s as u128 * b).sum::<u128>()
}

/// Daily rebase in basis points: the change in net worth since the last market day, clamped to +-cap_bp.
pub fn step_bp(last: u128, now: u128, cap_bp: u32) -> i64 {
    if last == 0 {
        return 0;
    }
    let raw = (now as i128 - last as i128) * 10_000 / last as i128;
    raw.clamp(-(cap_bp as i128), cap_bp as i128) as i64
}

/// Share index after one step (cap_bp < 10_000, so the index never reaches zero).
pub fn apply(index: u128, step_bp: i64) -> u128 {
    index * (10_000 + step_bp) as u128 / 10_000
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn worth_counts_stock_at_bid() {
        assert_eq!(net_worth(1_000, &[(10, 12), (2, 100)]), 1_000 + 120 + 200);
    }

    #[test]
    fn step_follows_worth_and_is_capped() {
        assert_eq!(step_bp(10_000, 10_300, 500), 300);
        assert_eq!(step_bp(10_000, 9_800, 500), -200);
        assert_eq!(step_bp(10_000, 20_000, 500), 500, "a windfall day is capped");
        assert_eq!(step_bp(10_000, 1_000, 500), -500, "a crash day is capped");
        assert_eq!(step_bp(0, 5_000, 500), 0, "no baseline yet");
    }

    #[test]
    fn apply_moves_every_balance_by_the_step() {
        assert_eq!(apply(INDEX_ONE, 300), INDEX_ONE * 103 / 100);
        assert_eq!(apply(INDEX_ONE, -500), INDEX_ONE * 95 / 100);
        assert_eq!(apply(INDEX_ONE, 0), INDEX_ONE);
    }
}
