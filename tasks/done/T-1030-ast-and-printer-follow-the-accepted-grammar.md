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
status: done
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

2026-11-10 syntax-engineer: claimed. Read ADR-0013..0017 and the EBNF as amended by ADR-0017 (`const_block`, E0610).
T-1006 (node ids) and T-0029 (ppx_deriving) were both in the backlog and unclaimed, so there was no conflict to
merge. Whoever lands second rebases: T-1006 adds an id to the nodes below; T-0029 replaces the hand-written `equal_*`
at the end of ast.ml and the `Print.pp_*` stand-ins, which are untouched here.

Decisions (each an interpretation of the accepted grammar, not a spec change):

- Constructor names keep the category prefixes of T-0008. The task's `Inout of expr` / `Using of ident * expr` are
  `Arg_inout` / `Arg_using` (a bare `Inout` already names `mode`); `Arg_inout` keeps an optional label because the
  EBNF allows `name: &place`. `gen_arg` is `Ga_expr | Ga_type_only`, `Trailing` is `Trailing_call`.
- `Trailing_call` now carries the call's own `args` and an optional `ret` (EBNF `trailing_call = postfix_expr "(" [ args ]
  ")" fn_head ":" suite`); before it held the whole call as `callee`.
- Tuple1: a singleton `Ty_tuple [t]` (and `Tuple [e]`) is the one-element tuple. With no parenthesised type node
  (`(T)` is `T`, TYP-006) the list form cannot be ambiguous, so no separate constructor. Alternative considered:
  a dedicated `Ty_tuple1`; rejected as redundant. A test shows `T` and `(T,)` print differently.
- `Ty_fn.using` and `Ty_dyn` hold `bound list`; `bound = { path; args : gen_arg list; span }` also replaces the
  `ty` in `generic.bounds`, `trait` supertraits and associated-type bounds (EBNF `bound = path [ "[" gen_args "]" ]`).
- `Range` / `Range_incl`: the `inclusive` flag is gone, so `a..=` (SYN-040, Q-0020.8) cannot be built.
- `Type` carries `def = Alias ty | Newtype { ty; where_ }` (`where` only under `new`), `Import` carries
  `form = Whole | Alias_as | Items` (alias xor items), `Const` lost its `comptime` flag (a top-level `let` is
  implicitly comptime, `comptime let` is a syntax error). `visibility` replaces `pub : bool` on declarations, fields
  and impl items; an `Impl` always has `Private`.
- `Pat_lit` still holds a `literal` (it would be a second literal type to restrict it); the invariant (no `Template`,
  `negated` only on numbers and durations) is documented and belongs to the parser (T-0012).
- Doc comments: all `doc` fields and `file.doc` are removed (not left `None`): ADR-0016 puts comments in a side table
  (T-1036), so a field would only invite a second source of truth.
- `Index` `args` hold expressions, and a type written as a path is an expression until resolution (SYN-042), so
  `Ty_path.args` of `Map[str, int]` print as `(apply Map (path str) (path int))`.
- parser.mly was touched outside the declared paths, only to construct the new record shapes of the seed subset
  (`file`, `import`, top-level `let`): no grammar change. T-1006 also lists parser.mly in its paths, so expect a
  trivial textual conflict there.
- `make ci`: ocamlformat 0.28.1 does not build here, so the format check is skipped locally; code was formatted by
  hand to the repository profile (margin 100). The GitHub CI is the authority.

Not changed, on purpose (follow-ups): the template interpolation spec and the shape of `self` parameters, see T-1041;
`attribute.args` cannot hold `reason: "…"`, see tasks/blocked/Q-0022.

## Outcome

AST, printer and tests follow the grammar as accepted by ADR-0013..0017 (see the Log for each shape). Block-ended
constructs (`if`, `match`, `loop`, `with`, `given`, `unsafe`, `fn` lambda, trailing call) are expressions and
statements wrap them; assignment targets are postfix expressions; `Index` takes `gen_arg list`; types are paren-free
with `bound`s; `Pat_const` is distinct from `Pat_bind`; visibility, import form and type-declaration form are
closed variants; doc fields are gone. The S-expression output changed where the shapes changed (`trailing-call`,
`(const …)`, `(using …)`, assignment targets and type arguments as expressions); snapshots were reviewed one by one.

Tests: `compiler/test/syntax/test_ast_print.ml` (existing snapshots updated, 11 new tests at the end citing SYN-002,
SYN-003, SYN-012, SYN-015, SYN-024, SYN-030, SYN-033, SYN-040, SYN-041, SYN-042, SYN-043, SYN-050, SYN-053, SYN-062,
TYP-006, CAP-032).

Follow-ups: T-1041, Q-0022 (blocking T-0009). Known limitation: invariants that the types do not encode (SYN-012
place check, SYN-065, SYN-017/018, SYN-053 case rules, const-block restriction, `self` position) are parser checks
(T-1031).
