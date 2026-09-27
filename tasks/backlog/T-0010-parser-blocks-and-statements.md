---
id: T-0010
title: Parser: blocks and statements
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0009]
spec: [SYN-010, SYN-011, SYN-012, SYN-061]
paths: [compiler/lib/syntax/parser.mly, compiler/test/syntax/, tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Indented and single-line blocks; let/var/let-else, assignment, if/elif/else, for/while/loop, with, given, defer, yield, return/break/continue.

## Context

Spec rules: SYN-010, SYN-011, SYN-012, SYN-061. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Each statement form: parse-pass and parse-fail tests
- [ ] 0 Menhir conflicts

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


