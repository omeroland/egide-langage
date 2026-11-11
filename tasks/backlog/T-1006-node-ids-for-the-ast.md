---
id: T-1006
title: Node ids for the AST
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008]
spec: []
paths: [compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/parser.mly, compiler/lib/syntax/print.ml, compiler/test/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Every AST node that later passes annotate (expressions, patterns, types, statements, declarations, identifiers)
carries a unique `Node_id.t`, so that side tables are keyed by ids as docs/architecture.md §2 invariant 3 requires.

## Context

Raised by the code-review of T-0008 (PR #4): spans are not unique keys (an `Expr` statement and its expression share
one span, and so do `Pat_bind` and its ident), so resolve and types must not key side tables on spans. Ids must be
deterministic (architecture §2 invariant 4) and allocated from an explicit counter in the parse context, not global
state (invariant 5). Must land before name resolution (T-0030) starts. Coordinate with T-0029 (both touch ast.ml).

## Acceptance criteria

- [ ] `Node_id` module with an abstract `t`, `equal`, `compare`, `to_int`; ids unique within a parsed file
- [ ] The parser allocates ids from a counter in an explicit context; same input gives the same ids
- [ ] `Print` omits ids by default (snapshots unchanged) and shows them with an option
- [ ] A test checks uniqueness of ids over a parsed file

## Out of scope

Side tables themselves (resolve/types).

## Log

2026-11-10 syntax-engineer (T-1030): merge after T-1030 (PR #17). New nodes needing ids: `bound`, `arg` / `arg_desc`, `type_def` is not a node. `parser.mly` was touched by T-1030 (three constructor hunks of the seed subset).

## Outcome
