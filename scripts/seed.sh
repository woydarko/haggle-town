#!/usr/bin/env bash
# Registers the 3 merchants (10000 coin, stock 100, target 100) and writes their keys + the game key into .env.
# Usage: CONTRACT_ID=haggletown.testnet bash scripts/seed.sh   (run after deploy.sh)
# Private keys are read from ~/.near-credentials/testnet/*.json and written only to .env (gitignored); never printed.
set -euo pipefail

CONTRACT_ID="${CONTRACT_ID:-haggletown.testnet}"
NET=testnet
CREDS="$HOME/.near-credentials/$NET"

field() { python -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$CREDS/$1.json" "$2"; }

registered=$(near contract call-function as-read-only "$CONTRACT_ID" get_market json-args '{}' network-config $NET now 2>/dev/null | grep -o '"account_id": *"[^"]*"' || true)

for pair in woodcutter:wood fishmonger:fish smith:iron; do
  name="${pair%%:*}"; good="${pair##*:}"; acct="$name.$CONTRACT_ID"
  if grep -q "\"$acct\"" <<<"$registered"; then echo "$acct already registered"; continue; fi
  pk=$(field "$acct" public_key)
  args="{\"account_id\":\"$acct\",\"good\":\"$good\",\"public_key\":\"$pk\",\"coin\":\"10000\",\"stock\":100,\"target\":100}"
  near contract call-function as-transaction "$CONTRACT_ID" register_merchant json-args "$args" \
    prepaid-gas '30 Tgas' attached-deposit '0 NEAR' sign-as "$CONTRACT_ID" network-config $NET \
    sign-with-legacy-keychain send >/dev/null
  echo "registered $acct ($good)"
done

touch .env
python - "$CREDS" "$CONTRACT_ID" <<'EOF'
import json, sys
creds, cid = sys.argv[1], sys.argv[2]
want = {
    "CONTRACT_ID": cid,
    "GAME_ACCOUNT_ID": f"game.{cid}",
    "GAME_PRIVATE_KEY": json.load(open(f"{creds}/game.{cid}.json"))["private_key"],
    "WOODCUTTER_PRIVATE_KEY": json.load(open(f"{creds}/woodcutter.{cid}.json"))["private_key"],
    "FISHMONGER_PRIVATE_KEY": json.load(open(f"{creds}/fishmonger.{cid}.json"))["private_key"],
    "SMITH_PRIVATE_KEY": json.load(open(f"{creds}/smith.{cid}.json"))["private_key"],
    "NEAR_NETWORK": "testnet",
}
lines = [l for l in open(".env", encoding="utf-8").read().splitlines() if l.split("=", 1)[0] not in want]
lines += [f"{k}={v}" for k, v in want.items()]
open(".env", "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote .env keys:", ", ".join(want))
EOF
