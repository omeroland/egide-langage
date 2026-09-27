---
id: T-0018
title: Fuzzing the lexer and parser
kind: task
phase: 0
role: test-engineer
depends_on: [T-0011]
spec: [LEX-001]
paths: [compiler/test/fuzz/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

qcheck generators for token streams and ASTs; properties: never raises, print/parse round-trip; optional crowbar/AFL target documented.

## Context

Spec rules: LEX-001. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [ ] `dune test compiler/test/fuzz` runs 10 000 cases in < 60 s
- [ ] Round-trip property holds on generated ASTs

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


