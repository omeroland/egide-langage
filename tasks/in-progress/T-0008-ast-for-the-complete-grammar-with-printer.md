---
id: T-0008
title: AST for the complete grammar, with printer
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [SYN-001, SYN-012, SYN-050, SYN-060, SYN-062]
paths: [compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/print.ml, compiler/test/syntax/]
estimate: M
labels: []
status: in-progress
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:55Z
---

## Goal

OCaml types covering every production of spec/grammar/egide.ebnf, with spans on every node, plus an S-expression printer used by `egide parse` and snapshot tests.

## Context

Spec rules: SYN-001, SYN-012, SYN-050, SYN-060, SYN-062. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every EBNF production maps to an AST constructor (a table in the Log maps production → constructor)
- [ ] `[@@deriving show, eq]` available for tests
- [ ] Printer output is stable and documented as unstable-for-users

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


