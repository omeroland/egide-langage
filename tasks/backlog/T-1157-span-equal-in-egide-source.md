---
id: T-1157
title: Span.equal in egide.source (replace the local equal_span of Ast)
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0029]
spec: []
paths: [compiler/lib/source/, compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`Egide_source.Span` exports `equal : t -> t -> bool`; `Ast.equal_span` becomes an alias of it (or the derivers find it by name) instead of the hand-written structural `( = )` of T-0029.

## Context

T-0029 defines `Ast.pp_span` (file name escaped with `Escape.display`) and `Ast.equal_span` locally because `compiler/lib/source/` was outside its paths. A `Span.equal` next to the type keeps the definition of span equality with the type. `Span.pp` prints the file name raw; T-1111 decides whether it is deleted, routed through `Escape.display` or documented.

## Acceptance criteria

- [ ] `Span.equal` in span.ml(i), with a unit test
- [ ] `Ast.equal_span` uses it; `make ci` unchanged

## Out of scope

Changing `Span.pp` (T-1111).

## Log

## Outcome
