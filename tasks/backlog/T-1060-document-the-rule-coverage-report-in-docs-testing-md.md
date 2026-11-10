---
id: T-1060
title: Document the rule coverage report in docs/testing.md
kind: task
phase: 0
role: docs-writer
depends_on: [T-0020]
spec: []
paths: [docs/testing.md]
estimate: S
labels: [docs]
status: backlog
claimed_by:
claimed_at:
---

## Goal

docs/testing.md §3 rule 2 describes `tools/check-spec.sh --coverage` and `--strict` as implemented by T-0020: the
columns (RULE, CH, POS, NEG), the summary lines, what counts as positive (`# expect:` ending in `-pass`) and negative
(`-fail`, `run-panic`), the ignored `tests/quarantine/`, the `--strict` scope per phase (`PHASE_CHAPTERS` in
tools/spec_coverage.py, derived from docs/roadmap.md) and `--phase` / `--chapters`.

## Context

T-0020 left the output documented only in `tools/spec_coverage.py --help` and its module docstring.

## Acceptance criteria

- [ ] docs/testing.md describes the report and both flags, matching `./tools/check-spec.sh --coverage` output

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-10 release-manager: created from T-0020.

## Outcome
