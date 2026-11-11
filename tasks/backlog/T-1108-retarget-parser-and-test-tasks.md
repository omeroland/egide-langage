---
id: T-1108
title: Retarget parser and test tasks to the brace grammar
kind: task
phase: 0
role: language-architect
depends_on: [T-1102]
spec: [SYN-010]
paths: [tasks/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Update T-0009..T-0013, T-0015, T-0017, T-1031, T-1032 to the new grammar and rule ids; record T-1035 as superseded (done, outcome: superseded by T-1104).

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. These tasks are held until the owner decides.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
