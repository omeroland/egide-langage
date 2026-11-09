#!/usr/bin/env bash
# Conformance runner (docs/testing.md §2). The implementation is the OCaml program in tools/conformance/;
# this wrapper builds it and the compiler, then runs it from the repository root.
#   ./tools/run-conformance.sh [OPTIONS] [PATH...]     default PATHs: tests/conformance tests/security
#   ./tools/run-conformance.sh --help                  all options (--jobs, --junit FILE, --phase, -v, ...)
# The compiler under test is $EGIDE, or _build/default/compiler/bin/main.exe.
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v dune >/dev/null; then dune=(dune); else dune=(opam exec -- dune); fi
"${dune[@]}" build ./compiler/bin/main.exe ./tools/conformance/main.exe
exec ./_build/default/tools/conformance/main.exe "$@"
