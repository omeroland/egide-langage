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

2026-11-10 language-architect (owner-delegated): spec/grammar/egide.ebnf is v0.3 (ADR-0013, ADR-0014, ADR-0015 accepted). Read `docs/adr/attachments/0013-menhir-check.mly` (0 conflicts) as the starting point for parser.mly, and do T-1030 (AST) first. Here: Q-0002 and Q-0008 are decided (ADR-0013): terminator layout model, `place` replaced by a postfix expression checked as a place (E0106). Statements: `single_stmt` vs `simple_stmt` vs `block_stmt` (SYN-015, SYN-061; E0109 for bindings in one-line blocks), `loop` values (SYN-016). Post-parse checks are T-1031.

2026-11-10 syntax-engineer (T-1006): every production that builds an id-bearing node (ident, path, expr, arg, bound, block, stmt, pattern, ty, decl, generic, param, field, variant, trait_item, impl_item, fn_decl; see ast.mli) writes `id = Ids.fresh ()`; the parser is the functor `Parser.Make (Ids)` and `Parse.file ?gen` instantiates it. Wrappers without an id (lambda_param, with_item, case_arm, ...) take none.

## Outcome


