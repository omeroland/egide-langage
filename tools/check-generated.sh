#!/usr/bin/env bash
# Fails if generated files are stale (tokens from tools/gen/tokens.py, the LEX-003 table from tools/gen/unicode_forbidden.py).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/gen/tokens.py
git diff --exit-code -- compiler/lib/syntax/tokens.ml compiler/lib/syntax/token_decls.mly compiler/lib/syntax/token_table.ml \
  || { echo "Generated token files are stale: run python3 tools/gen/tokens.py and commit."; exit 1; }
# The Unicode files are verified against the digests pinned in tools/gen/unicode-16.0.0.sha256 (downloaded into the
# git-ignored tools/gen/.ucd-cache when absent); the generator stops on a mismatch.
python3 tools/gen/unicode_forbidden.py --check \
  || { echo "compiler/lib/source/forbidden_table.ml is stale: run python3 tools/gen/unicode_forbidden.py and commit."; exit 1; }
echo "generated files: up to date"
