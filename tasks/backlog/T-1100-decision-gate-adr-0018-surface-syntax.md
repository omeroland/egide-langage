---
id: T-1100
title: Decision gate: ADR-0018 surface syntax
kind: task
phase: 0
role: language-architect
depends_on: []
spec: [SYN-010, LEX-036]
paths: [docs/adr/]
estimate: S
labels: [blocked-on-owner]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Record the owner's decision on ADR-0018. DO NOT CLAIM until ADR-0018 is `Accepted` on `main`; if it is `Rejected`, move every T-1101..T-1109 to done as not applicable and keep T-1035 and T-0009 as they are. If accepted, mark ADR-0005 superseded, ADR-0013/0015/0016 amended, update the index.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Proposed in PR `adr/syntax-familiarity`. Owner confirmation is required (the delegated MVP-review regime does not cover reversing ADR-0005). Labels: blocked-on-owner.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
