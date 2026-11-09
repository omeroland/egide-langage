# Tests

| Directory | Content | Owner |
|-----------|---------|-------|
| `conformance/<chapter>/` | black-box language tests, one `.egd` per case, rule-tagged | test-engineer + implementers |
| `security/` | attacks that MUST be rejected or neutralised — **append-only** | security-reviewer |
| `quarantine/` | flaky tests awaiting a fix (blocks phase exit); not run by default | test-engineer |

Format and rules: [`docs/testing.md`](../docs/testing.md). Run with `make conformance` or
`./tools/run-conformance.sh <dir-or-file>...`.

## The conformance runner

`tools/run-conformance.sh` builds the compiler and the runner (`tools/conformance/`, OCaml) and runs it from the
repository root. Useful options (`--help` lists them all):

| Option | Default | Effect |
|--------|---------|--------|
| `PATH...` | `tests/conformance tests/security` | `.egd` files or directories (recursive) |
| `--jobs N`, `-j N` | number of cores | compiler runs in parallel |
| `--junit FILE` | none | also write a JUnit XML report (one `<testsuite>` per directory) |
| `--phase N` | `tasks/PHASE` | current phase; tests with a higher `# phase:` are skipped |
| `--egide EXE` | `$EGIDE` or `_build/default/compiler/bin/main.exe` | compiler under test |
| `--timeout S` | 30 | seconds per compiler run; slower runs fail |
| `--spec-dir DIR` | `spec` | cited rule ids must be defined there (`''` disables the check) |
| `-v` | off | also list passing tests and timing |

Output: one `FAIL` line per failure (with the command and the compiler's output), one `SKIP` line per skipped test,
then `conformance: N passed, N failed, N skipped (phase P)`. Exit status: 0 nothing failed, 1 a test failed,
2 usage error.

### How a header is read

- The header is the leading block of `#` lines (blank lines allowed; a shebang, `##` doc comments and free comments
  are fine). It ends at the first code line. A UTF-8 BOM and CRLF line ends do not hide it (LEX-001/LEX-002 tests).
- `# spec:` is mandatory and every cited id must exist in `spec/`. A test without a valid header **fails**, even if
  its phase is in the future.
- Directives are `# key: value` with a lowercase key. An unknown key (`# diagnostics:`) is an error, and so is a
  runner directive after the header block, so that a typo can never silently weaken a test. `# requires:`
  (TOOL-011 scripts) is accepted and ignored.
- `lex-fail`, `parse-fail` and `compile-fail` need at least one `# diagnostic: CODE at L:C`.
  `# diagnostic:` is only allowed with them, `# stdout:` (or a sibling `<name>.stdout`, not both) only with
  `run-pass`, `# backends:` only with `run-pass`/`run-panic`.
- `# stdout:` keeps the text after `: ` verbatim (an empty value is an empty line).

### How a run is judged

| `# expect:` | Command | Passes when |
|-------------|---------|-------------|
| `lex-pass` / `parse-pass` | `egide lex\|parse --error-format=json FILE` | exit 0 |
| `lex-fail` / `parse-fail` | same | exit 1 and every `# diagnostic:` reported |
| `compile-fail` | `egide check --error-format=json FILE` | exit 1 and every `# diagnostic:` reported |
| `run-pass` | `egide run FILE`, once per backend | exit 0 and stdout lines equal to `# stdout:` (if given) |
| `run-panic` | same | exit 101 (ERR-040) |

- Diagnostics are read from the JSON objects of `--error-format=json` (TOOL-042, schema in `docs/diagnostics.md`).
  Each expected diagnostic must match a distinct reported one with the same code and start line/column; other
  reported diagnostics are allowed.
- A crash fails the test whatever it expects: exit 70, an `ICE` diagnostic, an uncaught OCaml exception, a signal
  or a timeout.
- `run-*` tests run on each backend in both `# backends:` (default: all) and the runner's `--backends`. The runner
  only drives `interp` today; a test with no common backend is skipped.

### Tests of the runner

`tools/conformance/test/`: expect tests per module, and an end-to-end run (`e2e.expected`) of the real runner over
`fixtures/tests/` with a scripted stand-in compiler (`fake_egide.ml`). They run with `dune test`.
