---
id: T-1133
title: `egide new` and `egide init`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0019, T-1121]
spec: [PKG-001, PKG-010]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/test/pkg/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Creates `egide.toml` with the mandatory keys, `src/main.egd` or `src/lib.egd`, and refuses a name that is not a reverse-DNS namespace.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Generated package passes `egide check`
- [ ] No network access, no prompts
- [ ] Invalid name rejected with exit code 1

## Out of scope

Templates beyond the minimal package.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
