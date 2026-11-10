#!/usr/bin/env bash
# Tests of tools/check-spec.sh itself, on a fixture repository in a temp dir (EGIDE_ROOT overrides the repo root).
# Regression test for T-1003: --coverage must not abort at the first uncovered rule.
set -euo pipefail
here="$(cd "$(dirname "$0")/../.." && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/spec/appendix" "$tmp/docs" "$tmp/tests/conformance/a"
printf '# 2\n- **[LEX-001]** one.\n- **[LEX-002]** two.\n- **[CAP-001]** three.\n' > "$tmp/spec/02-x.md"
printf '# A\n' > "$tmp/spec/appendix/a.md"
printf '# spec: CAP-001\n# expect: lex-pass\n' > "$tmp/tests/conformance/a/t.egd"
fail=0
check() { if ! eval "$2"; then echo "FAIL: $1"; fail=1; fi; }

out=$(EGIDE_ROOT="$tmp" "$here/tools/check-spec.sh" --coverage) && rc=0 || rc=$?
check "coverage exits 0 although some rules are uncovered" "[ $rc = 0 ]"
check "lists an uncovered rule" "grep -qE '^LEX-001 +02 +0 +0$' <<<\"\$out\""
check "lists the last rule" "grep -qE '^CAP-001 +02 +1 +0$' <<<\"\$out\""
check "prints the uncovered total" "grep -q '^uncovered rules: 2 / 3\$' <<<\"\$out\""

out=$(EGIDE_ROOT="$tmp" "$here/tools/check-spec.sh") && rc=0 || rc=$?
check "plain run exits 0" "[ $rc = 0 ]"
check "plain run has no coverage table" "! grep -q RULE <<<\"\$out\""

printf '%s\n' '- **[LEX-001]** dup.' >> "$tmp/spec/02-x.md"
EGIDE_ROOT="$tmp" "$here/tools/check-spec.sh" >/dev/null && rc=0 || rc=$?
check "duplicate ids still fail" "[ $rc = 1 ]"
[ $fail = 0 ] && echo "check-spec tests: ok"
exit $fail
