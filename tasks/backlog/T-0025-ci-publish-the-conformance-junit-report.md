---
id: T-0025
title: CI: publish the conformance JUnit report
kind: task
phase: 0
role: release-manager
depends_on: [T-0014]
spec: []
paths: [.github/workflows/ci.yml, Makefile]
estimate: S
labels: [governance]
status: backlog
claimed_by:
claimed_at:
---

## Goal

CI runs the conformance suite with `--junit` and publishes the report (artifact upload, and a test-report step if
the owner wants one), so that failures are visible per test in the PR checks.

## Context

T-0014 added `./tools/run-conformance.sh --junit FILE` (see tests/README.md). `.github/` is a protected path: the
change goes on a `governance/*` branch for the human owner to merge. Suggested shape: `make conformance` accepts
`CONFORMANCE_FLAGS` (e.g. `--junit _build/conformance.xml`), and the `compiler` job uploads that file with
`actions/upload-artifact` (`if: always()`).

## Acceptance criteria

- [ ] A PR run of the `compiler` job exposes the JUnit XML report of the conformance suite
- [ ] `make conformance` without flags behaves as today

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: created from T-0014 (the runner can write JUnit; CI does not ask for it yet).

## Outcome
