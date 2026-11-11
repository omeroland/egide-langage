---
id: T-1030
title: AST and printer follow the accepted grammar
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008]
spec: [SYN-005, SYN-015, SYN-042, SYN-053, SYN-065]
paths: [compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/print.ml, compiler/test/syntax/]
estimate: M
labels: []
status: in-progress
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

Bring the AST (T-0008) in line with spec/grammar/egide.ebnf v0.3 so that T-0009..T-0012 can start.

## Context

Decided by owner-delegated architect in ADR-0013, ADR-0014 and ADR-0015. Must land before T-0009. Coordinate with T-1006 and T-0029 (all touch ast.ml).

## Acceptance criteria

- [ ] One `If` node (no `if_stmt`/`if_expr` split); `Match`, `Loop`, `With`, `Given`, `Lambda`, `Trailing_call`, `Unsafe` are expressions; statements wrap them (`Stmt.Expr`)
- [ ] `place` is replaced by a postfix expression as assignment target (Q-0008); `Arg` has `Inout of expr`, `Using of ident * expr`
- [ ] `Index of expr * gen_arg list` with `gen_arg = Expr | Type_only of ty`; `slice_or_index` and `type_arg` are gone (ADR-0014)
- [ ] Types: `Paren`-free, `Tuple1`, `Fn_type` with `using` bounds list, `Dyn of bound list`
- [ ] Patterns: `Pat_const of path` distinct from `Pat_bind of ident` (SYN-053); literal patterns gain duration, raw string, bytes
- [ ] `visibility = Private | Pub | Pub_package`; `struct`/`impl` bodies may be empty; `Import` alias xor items; `Type_decl` where only under `new`
- [ ] `file.doc` and per-node `doc` are removed or left `None` until ADR-0016 (Q-0012) is implemented
- [ ] Printer snapshots updated and reviewed; `make ci` green

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
