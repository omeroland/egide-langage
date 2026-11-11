---
id: T-1139
title: `egide list [--json]`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0030, T-1121]
spec: [PKG-001, PKG-040]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Lists packages, modules, test functions and dependencies with a stable JSON form for tools and agents; fields include capabilities required and `allow` breaches.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] JSON schema documented
- [ ] Deterministic order

## Out of scope

Format templates (go list -f).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
