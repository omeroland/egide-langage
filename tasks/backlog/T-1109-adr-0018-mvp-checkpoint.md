---
id: T-1109
title: MVP checkpoint for ADR-0018
kind: task
phase: 0
role: language-architect
depends_on: [T-1104]
spec: [LEX-036]
paths: [docs/adr/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Re-run 0018-check.py, measure the revert triggers of ADR-0018 (W0003 hit rate, review escapes, one-line-block dominance) and report confirm or revert to the owner.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Reversibility conditions are in ADR-0018.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
