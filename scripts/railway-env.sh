#!/usr/bin/env bash
# Copies the backend's env vars from .env into the linked Railway service. Prints names only, never values.
# Run after `railway login` and `railway init` (or `railway link`), from the repo root:  bash scripts/railway-env.sh
set -euo pipefail

KEYS=(CONTRACT_ID GAME_ACCOUNT_ID GAME_PRIVATE_KEY WOODCUTTER_PRIVATE_KEY FISHMONGER_PRIVATE_KEY SMITH_PRIVATE_KEY
      RBX_HMAC_SECRET NEAR_NETWORK NEAR_RPC_URL NEAR_RPC_FALLBACK_URL LLM_BASE_URL LLM_MODEL LLM_API_KEY REPLAY_MODE DAY_LENGTH_MS)

args=()
names=()
while IFS= read -r line || [[ -n $line ]]; do
  line="${line%$'\r'}"
  [[ -z $line || $line == \#* || $line != *=* ]] && continue
  k="${line%%=*}"
  v="${line#*=}"
  for want in "${KEYS[@]}"; do
    if [[ $k == "$want" && -n $v ]]; then
      args+=(--set "$k=$v")
      names+=("$k")
    fi
  done
done < .env

if [[ ${#args[@]} -eq 0 ]]; then
  echo "no variables found in .env" >&2
  exit 1
fi
railway variables "${args[@]}" --skip-deploys > /dev/null
echo "set ${#names[@]} variables on Railway: ${names[*]}"
