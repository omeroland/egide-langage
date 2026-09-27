#!/usr/bin/env bash
# Fails if generated files are stale (tokens from tools/gen/tokens.py).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/gen/tokens.py
git diff --exit-code -- compiler/lib/syntax/tokens.mly compiler/lib/syntax/token_table.ml \
  || { echo "Generated token files are stale: run python3 tools/gen/tokens.py and commit."; exit 1; }
echo "generated files: up to date"
