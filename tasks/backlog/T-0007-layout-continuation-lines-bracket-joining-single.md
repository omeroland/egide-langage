---
id: T-0007
title: Layout: continuation lines, bracket joining, single-line blocks
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-030, LEX-031, LEX-033, LEX-035]
paths: [compiler/lib/syntax/layout.ml, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

The seed layout pass implements LEX-032/034; add LEX-030 (b) continuation lines starting with `|>`, `.`, `and`, `or`, and the E0023 check of LEX-033.

## Context

Spec rules: LEX-030, LEX-031, LEX-033, LEX-035. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Pipelines and method chains over several lines produce no NEWLINE between continuation lines
- [ ] `:` at end of line without INDENT → E0023
- [ ] Property test: layout tokens are balanced (INDENT count = DEDENT count) on generated programs

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


