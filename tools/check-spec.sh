#!/usr/bin/env bash
# Checks the specification: rule ids unique and well-formed; with --coverage, lists rules and the number of
# conformance tests citing them. Rule format: **[PREFIX-NNN]** or **[PREFIX-NNN] Title.** (spec/README.md).
set -euo pipefail
cd "${EGIDE_ROOT:-$(dirname "$0")/..}"   # EGIDE_ROOT: fixture root for tools/tests/check-spec-test.sh

files=$(ls spec/[0-9]*.md spec/appendix/*.md)
ids=$(grep -ohE '\*\*\[[A-Z]+-[0-9]{3}\]' $files | sed -E 's/\*\*\[(.*)\]/\1/')
dups=$(printf '%s\n' "$ids" | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "Duplicate rule ids:"; echo "$dups"; exit 1
fi
total=$(printf '%s\n' "$ids" | grep -c . || true)

# Every rule id referenced anywhere in spec/ and docs/ must exist.
refs=$({ grep -ohE '\b(INT|LEX|SYN|TYP|MEM|CAP|CON|ERR|CT|PKG|GO|SEC|TOOL|GOP)-[0-9]{3}\b' spec docs -r || true; } | sort -u)
missing=$(comm -23 <(printf '%s\n' "$refs") <(printf '%s\n' "$ids" | sort -u))
if [ -n "$missing" ]; then
  echo "Referenced but undefined rule ids:"; echo "$missing"; exit 1
fi
echo "spec: $total rule ids, all unique; all references resolve."

if [ "${1:-}" = "--coverage" ]; then
  echo
  printf '%-10s %s\n' RULE TESTS
  uncovered=0
  for id in $(printf '%s\n' "$ids" | sort); do
    # grep exits 1 when nothing matches; that is a count of 0, not a failure (set -e, pipefail).
    n=$({ grep -rlE "^# spec:.*\b$id\b" tests 2>/dev/null || true; } | wc -l | tr -d ' ')
    printf '%-10s %s\n' "$id" "$n"
    [ "$n" = 0 ] && uncovered=$((uncovered + 1))
  done
  echo
  echo "uncovered rules: $uncovered / $total"
fi
