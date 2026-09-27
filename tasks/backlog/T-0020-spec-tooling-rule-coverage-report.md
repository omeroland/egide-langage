---
id: T-0020
title: Spec tooling: rule coverage report
kind: task
phase: 0
role: release-manager
depends_on: [T-0014]
spec: []
paths: [tools/check-spec.sh, tools/spec_coverage.py]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`tools/check-spec.sh --coverage` lists each rule id with the number of tests citing it (positive/negative) and exits non-zero in `--strict` mode for rules of the current phase's chapters without both kinds.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/release-manager.md`.

## Acceptance criteria

- [ ] Report output documented in docs/testing.md (via docs-writer follow-up if needed)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


