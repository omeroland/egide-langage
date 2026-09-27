---
id: T-0006
title: Lexer hardening: UTF-8 validation, forbidden code points, tabs
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-001, LEX-002, LEX-003, LEX-004, LEX-020]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Complete the seed's LEX-001..004 checks with exact diagnostics and a property test that the lexer never raises on arbitrary bytes.

## Context

Spec rules: LEX-001, LEX-002, LEX-003, LEX-004, LEX-020. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every code point range of LEX-003 has a test (in code, comment and string)
- [ ] Invalid UTF-8, BOM, lone CR, tab → E0001/E0002/E0003/E0005
- [ ] qcheck: 10 000 random byte strings, lexer returns tokens or diagnostics, never raises

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


