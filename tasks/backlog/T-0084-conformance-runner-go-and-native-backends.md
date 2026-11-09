---
id: T-0084
title: Conformance runner: go and native backends (differential runs)
kind: task
phase: 5
role: test-engineer
depends_on: [T-0014, T-0081]
spec: [INT-020, TOOL-010]
paths: [tools/conformance/, tests/README.md]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`./tools/run-conformance.sh --backends interp,go` runs every `run-pass`/`run-panic` test on each backend and fails
when a backend's exit status or stdout differs from the expectation (docs/testing.md §1, differential layer).

## Context

T-0014's runner parses `# backends:` and plans one case per backend, but only drives `interp` (`egide run FILE`);
`Suite.supported_backends` and the CLI reject `go`/`native`. Spec 13 gives `egide build [--backend go|native]` but no
output-path flag yet: agree the command with the tooling-engineer, build into a temporary directory, run the binary
with the same timeout. Native follows in phase 7 (T-0100).

## Acceptance criteria

- [ ] `--backends interp,go` is accepted and every run-* test has one case per backend in the report
- [ ] A fixture where the go run prints different output fails (end-to-end test with the fake compiler)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: created from T-0014.

## Outcome
