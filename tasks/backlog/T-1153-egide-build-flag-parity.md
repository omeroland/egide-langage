---
id: T-1153
title: `egide build`: output path, emit, verbose, JSON, conditional compilation
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0081, T-1121]
spec: [PKG-050, TOOL-042, GO-050]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`-o`, `--emit=hir|mir|go|c` (debug dumps), `--verbose`, `--dry-run`, build events as JSON, and the build-constraint mechanism once Q-0040 is decided.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] No flag weakens PKG-041 or PKG-050
- [ ] Q-0040 decided before the constraint part starts

## Out of scope

-ldflags, -toolexec, plugins (excluded).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
