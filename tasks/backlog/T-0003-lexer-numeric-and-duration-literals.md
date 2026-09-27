---
id: T-0003
title: Lexer: numeric and duration literals
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-040, LEX-041, LEX-042]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Integer (dec/hex/oct/bin, underscores), float and duration literals are tokenised exactly as specified, with E0030/E0031 diagnostics.

## Context

Spec rules: LEX-040, LEX-041, LEX-042. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] All forms of LEX-040..042 tokenised; `5.s`, `500.ms`, `30.min` are single DURATION tokens
- [ ] `1.` , `1__0`, `0x`, `_1`, `1_` rejected with the right code and span
- [ ] Overflow is **not** checked here (it depends on the type, TYP-070); a note in the Log explains it
- [ ] Conformance tests: ≥ 6 lex-pass, ≥ 6 lex-fail

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


