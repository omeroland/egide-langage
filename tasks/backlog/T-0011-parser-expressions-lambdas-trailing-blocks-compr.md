---
id: T-0011
title: Parser: expressions, lambdas, trailing blocks, comprehensions
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0010]
spec: [SYN-030, SYN-033, SYN-034, SYN-035, SYN-036, SYN-037, SYN-038, SYN-039, SYN-040, SYN-041, SYN-060, SYN-062, SYN-064, SYN-100, SYN-101]
paths: [compiler/lib/syntax/parser.mly, compiler/test/syntax/, tests/conformance/syntax/]
estimate: L
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Full expression grammar with the SYN-100 precedence table, chained comparisons, conditional expressions, pipes, short lambdas, trailing blocks, collection literals and comprehensions, slices, `&` inout arguments, `?`.

## Context

Spec rules: SYN-030, SYN-033, SYN-034, SYN-035, SYN-036, SYN-037, SYN-038, SYN-039, SYN-040, SYN-041, SYN-060, SYN-062, SYN-064, SYN-100, SYN-101. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] A precedence test matrix (each pair of levels) in snapshot form
- [ ] SYN-101 mixing bitwise/comparison → E0103
- [ ] Trailing block examples of SYN-062 parse to the documented desugaring shape
- [ ] 0 Menhir conflicts

## Out of scope

Split into two PRs if it exceeds 400 lines (expressions first, then lambdas/comprehensions).

## Log

2026-11-10 language-architect (owner-delegated): spec/grammar/egide.ebnf is v0.3 (ADR-0013, ADR-0014, ADR-0015 accepted). Read `docs/adr/attachments/0013-menhir-check.mly` (0 conflicts) as the starting point for parser.mly, and do T-1030 (AST) first. Here: Q-0009 (no slice production, SYN-043), Q-0010 (cover grammar `paren_form`/`cover_item`/`arg`, SYN-065), Q-0011.1 (`using` argument), Q-0017 (`|>` shape check, E0108), SYN-042 generic arguments `[ ... ]`, block-ended expressions outside `expr`. `..=` needs an upper bound.

## Outcome


