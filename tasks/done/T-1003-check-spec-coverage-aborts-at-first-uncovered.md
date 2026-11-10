---
id: T-1003
title: check-spec --coverage aborts at the first uncovered rule
kind: task
phase: 0
role: release-manager
depends_on: []
spec: []
paths: [tools/check-spec.sh, tools/tests/check-spec-test.sh, Makefile]
estimate: S
labels: [bug]
status: done
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

- [x] `./tools/check-spec.sh --coverage` prints one line per rule id and `uncovered rules: N / 264` and exits 0
- [x] `./tools/check-spec.sh` without flags is unchanged

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: created from T-0014 (bug found while working on the runner; outside T-0014's paths).

- 2026-11-10 release-manager/wave2: claimed. Added `EGIDE_ROOT` override (fixture root for the tool test), a test script
  `tools/tests/check-spec-test.sh` wired into `make spec-check`, and the same `|| true` guard on the undefined-reference
  scan. Correction after review: that second guard is defensive only; any spec defining a rule id also matches the
  reference regex, so `refs` is never empty when `ids` is not, and no test reaches it. The real remaining pitfall is
  `ids=` exiting 1 silently on a spec with no rule ids (T-1062). T-0020 will
  replace the coverage loop with tools/spec_coverage.py; the regression test stays valid.

## Outcome

`--coverage` no longer aborts: `grep -rlE` no-match is a count of 0. Same defensive guard on the reference scan (not reachable by a test, see Log). On main now:
`uncovered rules: 245 / 264`, exit 0. Plain `check-spec.sh` output is unchanged.
Tests: `tools/tests/check-spec-test.sh` (fixture repo in a temp dir; covers coverage listing, totals, plain run, duplicate ids).
Follow-ups: T-1062.
