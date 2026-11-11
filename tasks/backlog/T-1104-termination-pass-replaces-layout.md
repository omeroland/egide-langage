---
id: T-1104
title: Lexer: line-termination pass replaces the layout pass
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1101]
spec: [LEX-036]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tools/gen/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Replace layout.ml by the termination pass of ADR-0018 item 2; remove INDENT, DEDENT and ELIF from the token table and tokens.mly generator; replace test_layout*.ml. Supersedes T-1035 (cancel it).

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Old layout is about 106 lines plus 300 lines of tests; recoverable from git history.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
