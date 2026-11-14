#!/usr/bin/env bash
# Creates the Haggle Town testnet accounts (idempotent) and deploys the contract.
# Usage: CONTRACT_ID=haggletown.testnet bash scripts/deploy.sh
# Needs: near-cli-rs 0.31+, Rust with wasm32-unknown-unknown. Keys go to ~/.near-credentials (legacy keychain).
set -euo pipefail

CONTRACT_ID="${CONTRACT_ID:-haggletown.testnet}"
NET=testnet
SUBS=(game woodcutter fishmonger smith)
WASM=target/wasm32-unknown-unknown/release/haggle_contract.wasm

exists() { near account view-account-summary "$1" network-config $NET now >/dev/null 2>&1; }

if ! exists "$CONTRACT_ID"; then
  echo "creating $CONTRACT_ID via faucet"
  near account create-account sponsor-by-faucet-service "$CONTRACT_ID" \
    autogenerate-new-keypair save-to-legacy-keychain network-config $NET create
fi

for s in "${SUBS[@]}"; do
  acct="$s.$CONTRACT_ID"
  if ! exists "$acct"; then
    echo "creating $acct"
    near account create-account fund-myself "$acct" '0.5 NEAR' \
      autogenerate-new-keypair save-to-legacy-keychain \
      sign-as "$CONTRACT_ID" network-config $NET sign-with-legacy-keychain send
  fi
done

# shortcut: plain cargo build (cargo-near not installable on this machine yet); switch to `cargo near build` when available.
# --cfg near is what cargo-near sets: without it near-sdk compiles panic_str to a bare trap and every error code is lost.
RUSTFLAGS="--cfg near -C link-arg=-s" cargo build -p haggle-contract --target wasm32-unknown-unknown --release

INIT_ARGS="{\"owner\":\"$CONTRACT_ID\",\"game\":\"game.$CONTRACT_ID\"}"
if near contract call-function as-read-only "$CONTRACT_ID" get_market json-args '{}' network-config $NET now >/dev/null 2>&1; then
  echo "contract already initialized; redeploying code only"
  near contract deploy "$CONTRACT_ID" use-file "$WASM" without-init-call \
    network-config $NET sign-with-legacy-keychain send
else
  near contract deploy "$CONTRACT_ID" use-file "$WASM" with-init-call new json-args "$INIT_ARGS" \
    prepaid-gas '100 Tgas' attached-deposit '0 NEAR' network-config $NET sign-with-legacy-keychain send
fi
echo "deployed $CONTRACT_ID"
