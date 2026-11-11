---
id: T-1131
title: `egide audit`: breaches, trust points, overrides, JSON
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1039]
spec: [MEM-071, GO-044, SYN-018, LEX-006, TOOL-041]
paths: [compiler/bin/, compiler/lib/driver/, compiler/lib/pkg/, compiler/test/driver/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

The command of chapter 13 that spec chapters 3, 5, 8, 11 and 12 all refer to had no task. Lists every `unsafe`, `trust`, discard reason, `let ... else`, `@go_threadsafe`, Go override and `allow` entry per package, with reasons escaped (LEX-006); `--error-format=json`; exit code 1 when a breach is not declared in the manifest.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] One conformance test per listed construct
- [ ] Audit output of a reason containing U+001B is escaped
- [ ] Undeclared breach in a dependency fails with the PKG-030 diagnostic

## Out of scope

Vulnerability matching (T-1132).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
