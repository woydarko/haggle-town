#!/usr/bin/env bash
# Deploys the three backer coins ($WOOD, $FISH, $SMITH), one NEP-141 contract per merchant, as sub-accounts of the
# market contract. Testnet only. Parameters are fixed here at init and nothing in the contract can change them.
# Usage: CONTRACT_ID=haggletown-v2.testnet bash scripts/deploy-coins.sh
set -euo pipefail

CONTRACT_ID="${CONTRACT_ID:-haggletown-v2.testnet}"
NET=testnet
WASM=target/wasm32-unknown-unknown/release/haggle_coin.wasm
CAP_BP=500             # largest daily rebase: 5% (chosen from the 60-day simulation, docs/hackathon/MEMECOIN.md)
CLAIM=1000000000       # 1000 coins per backer (6 decimals)
CLAIMS=1000            # backers per coin

# --cfg near: see scripts/deploy.sh
RUSTFLAGS="--cfg near -C link-arg=-s" cargo build -p haggle-coin --target wasm32-unknown-unknown --release

for spec in "wood:woodcutter:Woodcutter Backer:WOOD" "fish:fishmonger:Fishmonger Backer:FISH" "smith:smith:Smith Backer:SMITH"; do
  IFS=: read -r short merchant name symbol <<<"$spec"
  acct="$short-coin.$CONTRACT_ID"
  if ! near account view-account-summary "$acct" network-config $NET now >/dev/null 2>&1; then
    echo "creating $acct"
    near account create-account fund-myself "$acct" '2.15 NEAR' autogenerate-new-keypair save-to-legacy-keychain \
      sign-as "$CONTRACT_ID" network-config $NET sign-with-legacy-keychain send
  fi
  args="{\"market\":\"$CONTRACT_ID\",\"merchant\":\"$merchant.$CONTRACT_ID\",\"name\":\"$name\",\"symbol\":\"$symbol\",\"cap_bp\":$CAP_BP,\"claim\":\"$CLAIM\",\"claims\":$CLAIMS}"
  near contract deploy "$acct" use-file "$WASM" with-init-call new json-args "$args" \
    prepaid-gas '30 Tgas' attached-deposit '0 NEAR' network-config $NET sign-with-legacy-keychain send
  echo "deployed $acct"
done
