---
id: T-1100
title: Close the ADR-0018 decision: status, amendments, index
kind: task
phase: 0
role: language-architect
depends_on: []
spec: [SYN-010, LEX-036]
paths: [docs/adr/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

After the owner merges PR #20 (ADR-0018, option B, relayed owner decision of 2026-11-10 with defaults for Q2-Q5 and Q7), on an `adr/*` branch for the owner to merge: set ADR-0018 to `Accepted` ("Decided by: owner (confirmed in chat 2026-11-10); defaults for Q2-Q5 and Q7"), mark ADR-0005 `Superseded by ADR-0018`, add "Amended by ADR-0018" notes to ADR-0013, 0015, 0016, update `docs/adr/README.md`. Keep Q6 (tests/security port) marked open.

## Context

The author of an ADR does not accept it; the owner's merge of #20 is the acceptance. This task is ready as soon as #20 is on `main`. It unblocks T-1101 and T-1102.

## Acceptance criteria

- [ ] ADR-0018 status line matches the owner's decision text; Q6 still marked open
- [ ] ADR-0005 superseded, ADR-0013/0015/0016 carry an amendment note, index updated
- [ ] `make ci` green

## Out of scope

Spec edits (T-1101, T-1102).

## Log

## Outcome
