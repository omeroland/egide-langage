#!/usr/bin/env bash
# Checks the specification: rule ids unique and well-formed; with --coverage, lists rules with the number of
# positive/negative conformance tests citing them (tools/spec_coverage.py); --strict enforces both kinds.
# Rule format: **[PREFIX-NNN]** or **[PREFIX-NNN] Title.** (spec/README.md).
set -euo pipefail
tools_dir="$(cd "$(dirname "$0")" && pwd)"
cd "${EGIDE_ROOT:-$tools_dir/..}"   # EGIDE_ROOT: fixture root for tools/tests/check-spec-test.sh

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

# --coverage: per-rule report; --strict: also exit 1 if rules in the current phase's chapters lack a positive or a
# negative test (see tools/spec_coverage.py --help). Extra arguments (--phase N, --chapters ...) are passed through.
case "${1:-}" in
  --coverage | --strict)
    echo
    exec python3 -I "$tools_dir/spec_coverage.py" --root "$PWD" "$@"
    ;;
esac
