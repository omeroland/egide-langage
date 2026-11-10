---
id: T-1032
title: Conformance tests for the layout token contract (LEX-036)
kind: task
phase: 0
role: test-engineer
depends_on: [T-0007]
spec: [LEX-033, LEX-036]
paths: [tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Add `egide lex` conformance tests that pin the token stream of LEX-036: the §2.4 example, `NEWLINE DEDENT DEDENT` for nested closes, single-line blocks, end of file.

## Context

ADR-0013 fixed the contract to the existing LEX-032 behaviour; no lexer change is expected, only tests.

## Acceptance criteria

- [ ] Tests cite LEX-036 and LEX-033 in their `# spec:` header
- [ ] A negative test: a `DEDENT` is never followed by `NEWLINE`

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
