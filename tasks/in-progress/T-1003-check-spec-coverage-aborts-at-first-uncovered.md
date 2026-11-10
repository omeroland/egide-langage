---
id: T-1003
title: check-spec --coverage aborts at the first uncovered rule
kind: task
phase: 0
role: release-manager
depends_on: []
spec: []
paths: [tools/check-spec.sh]
estimate: S
labels: [bug]
status: in-progress
claimed_by: release-manager/wave2
claimed_at: 2026-11-10
---

## Goal

`./tools/check-spec.sh --coverage` lists every rule with its test count and the uncovered total, instead of exiting
with status 1 right after the `RULE TESTS` heading.

## Context

Reproduced on main (a8ab071) during T-0014: the script runs under `set -euo pipefail`; for the first rule without
tests (CAP-001), `grep -rlE "^# spec:.*\bCAP-001\b" tests` matches nothing and exits 1, the pipeline fails and
`set -e` aborts the script. Fix e.g. with `{ grep ... || true; } | wc -l`. T-0020 rewrites coverage reporting in the
same file; this task can be absorbed by T-0020 if it is claimed first (record it in both logs).

## Acceptance criteria

- [ ] `./tools/check-spec.sh --coverage` prints one line per rule id and `uncovered rules: N / 264` and exits 0
- [ ] `./tools/check-spec.sh` without flags is unchanged

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: created from T-0014 (bug found while working on the runner; outside T-0014's paths).

## Outcome
