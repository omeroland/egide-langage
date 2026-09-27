---
id: T-0035
title: REPL
kind: task
phase: 1
role: comptime-engineer
depends_on: [T-0034]
spec: [TOOL-010]
paths: [compiler/bin/, compiler/lib/comptime/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`egide` without arguments starts a REPL that type-checks and runs each input, prints values with their types, supports multi-line blocks.

## Context

Spec rules: TOOL-010. See docs/architecture.md and the role file `.claude/agents/comptime-engineer.md`.

## Acceptance criteria

- [ ] Scripted REPL sessions tested via stdin

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


