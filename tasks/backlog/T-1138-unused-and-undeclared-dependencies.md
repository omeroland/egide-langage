---
id: T-1138
title: Unused and undeclared dependency diagnostics; lock pruning
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-0030]
spec: [PKG-002, PKG-010, PKG-031]
paths: [compiler/lib/pkg/, compiler/lib/driver/, docs/diagnostics.md]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

What `go mod tidy` does: an import of an undeclared package is an error, a declared dependency that is never imported is a warning, and `egide lock` removes stale lock entries.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] New codes added to docs/diagnostics.md in the same PR
- [ ] Lockfile is minimal after `egide lock`

## Out of scope

Auto-adding dependencies (never automatic).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
