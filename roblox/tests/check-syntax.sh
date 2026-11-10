#!/usr/bin/env bash
# Parses every Luau file with Lute so syntax errors fail here instead of in Studio.
# Roblox globals (game, script, ...) make the scripts error at runtime under Lute; only parse errors count.
# Usage: LUTE=path/to/lute bash roblox/tests/check-syntax.sh
set -uo pipefail
LUTE="${LUTE:-lute}"
fail=0
while IFS= read -r f; do
  out=$("$LUTE" run "$f" 2>&1 | head -3)
  if grep -qiE "expected|syntax error|got '" <<<"$out"; then
    echo "PARSE FAIL $f: $(head -1 <<<"$out")"
    fail=1
  fi
done < <(find roblox/src roblox/tests -name "*.luau")
[[ $fail -eq 0 ]] && echo "all Luau files parse"
exit $fail
