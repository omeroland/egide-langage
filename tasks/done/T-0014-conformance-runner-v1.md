---
id: T-0014
title: Conformance runner v1
kind: task
phase: 0
role: test-engineer
depends_on: [T-0001]
spec: []
paths: [tools/run-conformance.sh, tools/conformance/, tests/README.md]
estimate: M
labels: []
status: done
claimed_by: test-engineer/wave1
claimed_at: 2026-11-09T09:32:03Z
---

## Goal

Replace the seed shell runner with an OCaml (or Python 3 stdlib-only) runner supporting all headers of docs/testing.md §2, phase skipping, parallel execution, and a JUnit XML report for CI.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [x] Supports lex-fail, parse-fail, compile-fail, run-pass, run-panic, diagnostic code+position checks, stdout checks
- [x] Skips tests with `# phase:` above tasks/PHASE and reports them as skipped
- [x] Fails when a test has no `# spec:` header
- [x] Runs the whole suite in parallel

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: OCaml rather than Python, so the runner's own tests run under `dune test` (hence `make ci`
  and CI) without touching the Makefile or the workflow. Dependencies: stdlib + unix only (JSON reader included).
- 2026-11-09 test-engineer: diagnostics are read from `--error-format=json` (TOOL-042, stable schema) instead of
  grepping the human format, which T-0002 is about to change. One JSON object per line is assumed (TOOL-042).
- 2026-11-09 test-engineer: stricter than the seed, on purpose (a typo must not silently weaken a test): the header is
  the leading `#` block; unknown `# key:` directives and runner directives after the header are errors (`# requires:`
  of TOOL-011 is allowed); `*-fail` needs at least one `# diagnostic:`; cited rule ids must exist in `spec/`;
  `*-fail` needs exit status 1 and crashes (exit 70, `ICE`, uncaught exception, signal, timeout) always fail. All
  existing tests still pass (13 passed, 1 skipped, as with the seed).
- 2026-11-09 test-engineer: expected diagnostics are a sub-multiset of the reported ones (seed semantics kept);
  extra diagnostics are allowed. See open question in the PR.
- 2026-11-09 test-engineer: exit statuses 0/1/2/70/101 come from the tooling-engineer role file; 101 is ERR-040.
- 2026-11-09 test-engineer: process pool is a single-threaded `create_process` + `waitpid WNOHANG` loop (no Domains,
  no fork); outputs go to temp files. Timeout kills only the direct child (no process group), enough for the
  in-process compiler; revisit when `run` spawns `go build` (T-0084).
- 2026-11-09 test-engineer: the PR is ~1,180 non-test lines (~230 are `.mli` docs), above the ~400 target; JUnit
  (Goal) and the JSON reader account for ~270. Not split because the Goal lists them; flagged in the PR.
- 2026-11-09 test-engineer: root `.gitattributes` (`eol=lf`) normalises CR bytes in `.egd` files; the CRLF fixture
  uses a nested `.gitattributes` with `-text`. LEX-002 conformance tests (T-0016) will need the same.
- 2026-11-10 test-engineer: follow-ups renumbered T-0025/26/27 -> T-1002/1003/1004 (orchestrator id allocation; the old ids belong to PR #1).
- 2026-11-10 test-engineer: test files are read as bytes (no grep), so tests containing NUL bytes or invalid UTF-8 work;
  covered by the fixture `pass/binary_bytes.egd`.

## Outcome

- `tools/run-conformance.sh` now builds and runs the OCaml runner in `tools/conformance/` (modules `Json`, `Header`,
  `Verdict`, `Exec`, `Junit`, `Suite`, CLI `main.ml`). Supports every docs/testing.md §2 header (`spec`, `expect`
  with all 7 values, repeatable `diagnostic` code+position, `stdout` lines or sibling `.stdout`, `phase`,
  `backends`), phase skipping reported as `SKIP` and as JUnit `<skipped>`, failure on missing `# spec:` (even for
  future-phase tests), parallel runs (`--jobs`, default = cores), per-run `--timeout`, `--junit FILE`.
- Tests added: `tools/conformance/test/test_{json,header,verdict,junit,exec}.ml` (expect tests) and the end-to-end
  test `tools/conformance/test/e2e.expected` over `tools/conformance/test/fixtures/` (25 cases: 9 pass, 14 fail,
  2 skip) with the scripted stand-in compiler `fake_egide.ml`.
- Docs: tests/README.md (options, header rules, judging table).
- Rules covered: none (tooling task; `spec: []`). Exit status 101 for `run-panic` follows ERR-040.
- Follow-ups: T-1002 (CI publishes the JUnit report; protected `.github/`), T-1003 (check-spec --coverage aborts at
  the first uncovered rule), T-1004 (docs/testing.md §2 header rules), T-0084 (go/native backends, differential).
- Limitations: only the `interp` backend is driven; diagnostics must be JSON on stderr, one object per line;
  diagnostic file paths are not compared (only code, line, column); timeouts kill only the direct child.


