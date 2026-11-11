---
id: T-1145
title: Workspaces: local multi-package development
kind: epic
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1121]
spec: [PKG-031, PKG-052]
paths: [(to be defined when split)]
estimate: L
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Equivalent of `go work`: several local packages developed together, path overrides marked in the lockfile and listed by `egide audit`, never inherited by dependents (same principle as GO-044). Blocked by Q-0043.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Q-0043 decided
- [ ] Split into S/M tasks

## Out of scope

Registry replacement of released versions.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
