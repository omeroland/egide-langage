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

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0015/Q-0001 decided: char escapes are LEX-050 minus `\{ \}` plus `\'`, exactly one scalar (E0042), no raw tab; byte strings accept printable ASCII and `\\ \" \n \t \r \0 \xHH` only (E0043), no `rb`; triple-quoted dedent works on raw lines before escapes, whitespace-only lines ignored, closing line break kept, tab in margin is E0005; `\u{…}` accepts any scalar value (T-1033 extends the forbidden set).

## Outcome


