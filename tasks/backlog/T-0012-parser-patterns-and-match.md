---
id: T-0012
title: Parser: patterns and match
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0011]
spec: [SYN-050, SYN-051, SYN-052]
paths: [compiler/lib/syntax/parser.mly, compiler/test/syntax/, tests/conformance/syntax/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

All pattern forms and `match`/`case` with guards.

## Context

Spec rules: SYN-050, SYN-051, SYN-052. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every pattern form parse-pass tested; or-patterns with `as`; list patterns with rest

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


