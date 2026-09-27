---
id: T-0004
title: Lexer: string, raw, triple-quoted, byte and char literals
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-050, LEX-051, LEX-052, LEX-053, LEX-054]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

All non-template string forms with escapes and dedenting of triple-quoted strings.

## Context

Spec rules: LEX-050, LEX-051, LEX-052, LEX-053, LEX-054. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every escape of LEX-050 tested; invalid escape → E0041 at the backslash
- [ ] Triple-quoted dedent semantics match Python's textwrap.dedent on 10 table-driven cases
- [ ] `\u{202E}` escape rejected (LEX-003 applies to escapes too)
- [ ] Unterminated literals → E0040 pointing at the opening quote

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


