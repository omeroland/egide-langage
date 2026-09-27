#!/usr/bin/env bash
# Seed conformance runner (docs/testing.md §2). T-0014 replaces it with a full runner.
# Supports: expect lex-pass | lex-fail | parse-pass | parse-fail, `# diagnostic: CODE at L:C`, `# phase: N`.
# Other expectations (compile-fail, run-pass, run-panic) are skipped until the compiler supports them.
set -uo pipefail
cd "$(dirname "$0")/.."
EGIDE="${EGIDE:-_build/default/compiler/bin/main.exe}"
PHASE="$(cat tasks/PHASE)"
dirs=("${@:-tests/conformance tests/security}")
pass=0; fail=0; skip=0
for f in $(find ${dirs[@]} -name '*.egd' | sort); do
  header=$(grep -E '^# (spec|expect|diagnostic|phase):' "$f")
  expect=$(sed -nE 's/^# expect: *([a-z-]+).*/\1/p' <<<"$header" | head -1)
  phase=$(sed -nE 's/^# phase: *([0-9]+).*/\1/p' <<<"$header" | head -1)
  if ! grep -qE '^# spec:' <<<"$header"; then echo "FAIL $f: missing '# spec:' header"; fail=$((fail+1)); continue; fi
  if [ -n "$phase" ] && [ "$phase" -gt "$PHASE" ]; then skip=$((skip+1)); continue; fi
  case "$expect" in
    lex-pass|lex-fail) cmd=lex ;;
    parse-pass|parse-fail) cmd=parse ;;
    *) skip=$((skip+1)); continue ;;
  esac
  out=$("$EGIDE" "$cmd" "$f" 2>&1 >/dev/null); status=$?
  ok=1
  case "$expect" in
    *-pass) [ $status -eq 0 ] || ok=0 ;;
    *-fail) [ $status -ne 0 ] || ok=0
            while read -r code at pos; do
              [ -z "$code" ] && continue
              grep -qE ":$pos: error\[$code\]" <<<"$out" || { ok=0; echo "  missing $code at $pos"; }
            done < <(sed -nE 's/^# diagnostic: *([A-Z0-9]+) +(at) +([0-9]+:[0-9]+).*/\1 \2 \3/p' <<<"$header") ;;
  esac
  if [ $ok -eq 1 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $f"; echo "$out" | sed 's/^/  | /'; fi
done
echo "conformance: $pass passed, $fail failed, $skip skipped (phase $PHASE)"
[ $fail -eq 0 ]
