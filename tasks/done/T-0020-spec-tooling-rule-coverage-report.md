---
id: T-0020
title: Spec tooling: rule coverage report
kind: task
phase: 0
role: release-manager
depends_on: [T-0014]
spec: []
paths: [tools/check-spec.sh, tools/spec_coverage.py, tools/tests/, Makefile]
estimate: S
labels: []
status: done
claimed_by: release-manager/wave2
claimed_at: 2026-11-10
---

## Goal

`tools/check-spec.sh --coverage` lists each rule id with the number of tests citing it (positive/negative) and exits non-zero in `--strict` mode for rules of the current phase's chapters without both kinds.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/release-manager.md`.

## Acceptance criteria

- [x] Report output documented in docs/testing.md (via docs-writer follow-up if needed): in the tool docstring and --help now; docs/testing.md in T-1060

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-10 release-manager/wave2: claimed; based on T-1003 (same file). Rule ids are never hardcoded; the
  phase-to-chapter scope table (`PHASE_CHAPTERS`) comes from docs/roadmap.md and is the only phase knowledge in the tool.
  A test counts only through its leading header block (as the runner does), tests/quarantine/ is ignored, tests/security/
  counts. Unknown cited ids are reported (and fail `--strict`) rather than crashing, so spec renames do not break the report.
- 2026-11-10 release-manager/wave2, review round 1 (PR #10): header read LF-only and CR-trimmed like the runner
  (was `splitlines()`); ids split on `,` and space only; malformed header ids reported and fail `--strict`; usage errors
  (bad `--chapters`/`--phase`, missing root or PHASE, spec without rules, empty scope) exit 2 with a message instead of
  passing; phase table now section-granular (`NN.M` entries): 8.1-8.3 in phase 2, 8.4-8.5 in phase 3, 10.1 and 13.1/13.4
  in phase 1, the rest of ch. 10 and 13 in phase 6. Still inferred from the roadmap Scope column: owner to confirm.

## Outcome

Implemented `tools/spec_coverage.py`; `check-spec.sh --coverage|--strict` delegates to it (extra args `--phase N`,
`--chapters 4,9` pass through). Columns RULE CH POS NEG, then `uncovered rules: N / T`, rules with a positive / a negative /
both. `--strict` exits 1 when a rule of the chapters in scope for the current phase (tasks/PHASE) lacks a positive or a
negative test, or when a test cites an unknown id. Currently `--strict` exits 1 on main (phase 0, ch. 2-3), so it is not in
`make ci`.
Tests: `tools/tests/spec_coverage_test.py` (24 cases, fixture repos), `tools/tests/check-spec-test.sh` updated; both run by
`make spec-check`. Rules covered: n/a (tooling).
Follow-ups: T-1060 (docs/testing.md), T-1061 (strict in the gate/CI).
