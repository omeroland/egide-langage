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
status: in-progress
claimed_by: test-engineer/wave1
claimed_at: 2026-11-09T09:32:03Z
---

## Goal

Replace the seed shell runner with an OCaml (or Python 3 stdlib-only) runner supporting all headers of docs/testing.md §2, phase skipping, parallel execution, and a JUnit XML report for CI.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [ ] Supports lex-fail, parse-fail, compile-fail, run-pass, run-panic, diagnostic code+position checks, stdout checks
- [ ] Skips tests with `# phase:` above tasks/PHASE and reports them as skipped
- [ ] Fails when a test has no `# spec:` header
- [ ] Runs the whole suite in parallel

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


