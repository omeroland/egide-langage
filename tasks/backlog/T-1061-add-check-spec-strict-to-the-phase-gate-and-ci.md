---
id: T-1061
title: Run check-spec --strict at phase gates and in CI when a phase closes
kind: task
phase: 0
role: release-manager
depends_on: [T-0020]
spec: []
paths: [tools/, Makefile]
estimate: S
labels: [ci]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`./tools/check-spec.sh --strict` is part of the phase-gate evidence (docs/phase-reports/phase-N.md) and, once the
test-engineer has filled the gaps of the current phase's chapters, of `make ci`. Today it exits 1 on main (many phase 0
rules in ch. 2 and 3 have no positive and negative test), so it is deliberately not in `make ci` yet.

## Context

T-0020 added `--strict`. The `.github/` workflow is owned by the owner (governance branch); a `make` target is enough
for CI to pick it up.

## Acceptance criteria

- [ ] `make spec-strict` target running `./tools/check-spec.sh --strict`
- [ ] Wired into `make ci` once it passes on main (otherwise only used by the phase gate)

## Out of scope

Writing the missing tests (test-engineer tasks).

## Log

- 2026-11-10 release-manager: created from T-0020.

## Outcome
