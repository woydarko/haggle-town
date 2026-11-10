//! Minimal NEP-245 surface: balance views, transfer between NEAR-account holders, NEP-297 events.
//! Players are not NEAR accounts; their balances are read with `get_player`.

use crate::*;
use near_sdk::serde_json::json;
use near_sdk::assert_one_yocto;

fn log_event(event: &str, data: near_sdk::serde_json::Value) {
    let ev = json!({"standard": "nep245", "version": "1.0.0", "event": event, "data": [data]});
    env::log_str(&format!("EVENT_JSON:{ev}"));
}

fn amounts(a: &[u128]) -> Vec<String> {
    a.iter().map(|x| x.to_string()).collect()
}

pub(crate) fn emit_mint(owner: &str, tokens: &[&str], amts: &[u128]) {
    log_event("mt_mint", json!({"owner_id": owner, "token_ids": tokens, "amounts": amounts(amts)}));
}

pub(crate) fn emit_burn(owner: &str, tokens: &[&str], amts: &[u128]) {
    log_event("mt_burn", json!({"owner_id": owner, "token_ids": tokens, "amounts": amounts(amts)}));
}

pub(crate) fn emit_transfer(from: &str, to: &str, tokens: &[&str], amts: &[u128]) {
    log_event(
        "mt_transfer",
        json!({"old_owner_id": from, "new_owner_id": to, "token_ids": tokens, "amounts": amounts(amts)}),
    );
}

fn token_ok(t: &str) {
    if !TOKENS.contains(&t) {
        env::panic_str("BadToken");
    }
}

#[near]
impl Contract {
    pub fn mt_balance_of(&self, account_id: AccountId, token_id: String) -> U128 {
        token_ok(&token_id);
        U128(self.bal(account_id.as_str(), &token_id))
    }

    pub fn mt_batch_balance_of(&self, account_id: AccountId, token_ids: Vec<String>) -> Vec<U128> {
        token_ids.iter().map(|t| self.mt_balance_of(account_id.clone(), t.clone())).collect()
    }

    #[payable]
    pub fn mt_transfer(
        &mut self,
        receiver_id: AccountId,
        token_id: String,
        amount: U128,
        approval: Option<(AccountId, u64)>,
        memo: Option<String>,
    ) {
        assert_one_yocto();
        let _ = (approval, memo);
        token_ok(&token_id);
        let from = env::predecessor_account_id();
        self.sub(from.as_str(), &token_id, amount.0);
        self.add(receiver_id.as_str(), &token_id, amount.0);
        emit_transfer(from.as_str(), receiver_id.as_str(), &[&token_id], &[amount.0]);
    }
}
