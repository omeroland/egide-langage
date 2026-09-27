# Testing strategy

A language is only as trustworthy as its test suite. **No behaviour exists until a test demonstrates it.**

## 1. Test layers

| Layer | Location | Tool | Purpose |
|-------|----------|------|---------|
| Unit | `compiler/test/<library>/` | ppx_expect, alcotest | internal functions, data structures |
| Snapshot | `compiler/test/<library>/*.ml` with `[%expect]` | ppx_expect | token streams, ASTs, diagnostics rendering |
| Property / fuzz | `compiler/test/fuzz/` | qcheck, AFL++ (`crowbar`) later | lexer/parser never crash; `fmt` idempotence; pretty-print → parse round-trip |
| Conformance | `tests/conformance/` | `tools/run-conformance.sh` | language behaviour, black-box, rule-tagged |
| Security | `tests/security/` | conformance runner | each test is an attack that MUST be rejected or neutralised |
| Differential | `tests/conformance/run-pass/` | runner `--backends interp,go,native` | all engines produce identical output |
| Runtime | `runtime/go/**/_test.go` | `go test -race` | Go runtime package |
| Benchmarks | `bench/` | `egide bench` (phase 5+) | performance regressions > 5 % fail CI |

## 2. Conformance test format

One `.egd` file per test. The header declares the expectation and the spec rules covered:

```egide
# spec: MEM-021
# expect: compile-fail
# diagnostic: E0301 at 11:14
module tests.mem.exclusivity_same_call

fn add(inout xs: List[int], x: int):
    xs.push(x)

fn main(sys: Sys) -> Result[(), Error]:
    var xs = [1]
    add(&xs, xs[0])
    Ok(())
```

| Header | Values |
|--------|--------|
| `# spec:` | one or more rule ids — **mandatory** |
| `# expect:` | `lex-pass`, `lex-fail`, `parse-pass`, `parse-fail`, `compile-fail`, `run-pass`, `run-panic` |
| `# diagnostic:` | `<code> at <line>:<col>` (repeatable) for `*-fail` |
| `# stdout:` | expected output line (repeatable) for `run-pass`, or a sibling `<name>.stdout` file |
| `# phase:` | minimum roadmap phase; tests of later phases are skipped, not failed |
| `# backends:` | subset of `interp,go,native` (default all available) |

Directory layout: `tests/conformance/<chapter>/<topic>_<case>.egd`, e.g. `tests/conformance/lexical/layout_bad_dedent.egd`.

## 3. Rules for agents

1. **Test first.** Write the failing conformance test from the spec rule, then implement.
2. **Every rule has at least one positive and one negative test** before its phase closes.
   `tools/check-spec.sh --coverage` lists rules without tests.
3. **Never weaken a test to make it pass.** Changing an expected diagnostic requires citing the spec rule that justifies
   the new expectation in the PR description.
4. **Snapshot updates** (`dune promote`) must be reviewed line by line in the PR diff; blind promotion is a review
   rejection reason.
5. **Security tests are append-only.** A test under `tests/security/` may only be removed by an ADR.
6. **Flaky tests** are quarantined within 24 h by moving them to `tests/quarantine/` with an issue; a quarantined test
   blocks the phase exit.
