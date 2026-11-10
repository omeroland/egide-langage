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

2026-11-10 language-architect (owner-delegated): spec/grammar/egide.ebnf is v0.3 (ADR-0013, ADR-0014, ADR-0015 accepted). Read `docs/adr/attachments/0013-menhir-check.mly` (0 conflicts) as the starting point for parser.mly, and do T-1030 (AST) first. Here: Q-0013 (SYN-053: uppercase or dotted names are constants/variants, lowercase binds; `PConst` vs `PBind`; literal patterns incl. duration/raw/bytes; closed ranges only).

## Outcome


