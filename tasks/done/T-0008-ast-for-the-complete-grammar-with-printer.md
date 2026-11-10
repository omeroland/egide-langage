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
status: done
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:55Z
---

## Goal

OCaml types covering every production of spec/grammar/egide.ebnf, with spans on every node, plus an S-expression printer used by `egide parse` and snapshot tests.

## Context

Spec rules: SYN-001, SYN-012, SYN-050, SYN-060, SYN-062. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [x] Every EBNF production maps to an AST constructor (a table in the Log maps production → constructor)
- [ ] `[@@deriving show, eq]` available for tests — partial: hand-written `Ast.equal_*` and `Print.pp_*` stand-ins; ppx_deriving not installable in the sandbox (Log), follow-up T-0029
- [x] Printer output is stable and documented as unstable-for-users

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 syntax-engineer/wave1: claimed.
- 2026-11-09 syntax-engineer/wave1: **`[@@deriving show, eq]` not adopted.** ppx_deriving (listed in ADR-0001) is not
  declared in `dune-project` and cannot be installed in the agent sandbox: `opam install ppx_deriving` fails because
  fetching its build dependency `cppo` returns HTTP 403 through the egress proxy (`opam.ocaml.org` is rejected too);
  per the proxy policy this was not retried or worked around. Stand-ins with the same purpose: `Ast.equal_file`,
  `equal_decl`, `equal_stmt`, `equal_block`, `equal_expr`, `equal_pattern`, `equal_ty` (structural, spans included;
  the names ppx_deriving would generate) and `Print.pp_*` / `Print.<category>` for display. Equality ignoring spans:
  compare `Print` renderings. Follow-up T-0029 adopts ppx_deriving once installable.
- 2026-11-09 syntax-engineer/wave1: `Ast.to_sexp` moved to `Print.file` (task path `print.ml`); `print.mli` added
  because every module used outside the library needs an interface. The one caller outside the task paths,
  `compiler/bin/main.ml` (`egide parse`), is updated in one line; output of `egide parse` is unchanged for the seed
  subset (test_parse.ml snapshots unchanged).
- 2026-11-09 syntax-engineer/wave1: seed parser ported to the new AST. Because `file` now has separate `imports`
  and `decls` (EBNF `file`, SYN-002), the seed rule accepts imports then declarations instead of interleaved items.
  This only restricts the seed to what the EBNF says; no new syntax. Menhir `--explain`: no conflicts.
- 2026-11-09 syntax-engineer/wave1: design decisions a reviewer should check:
  - Not represented (layout only, kept by the future CST): single-line vs indented block, `fn:` vs `fn():`,
    `x => e` vs `(x) => e`, trailing commas. `(e)` *is* kept (`Paren`) so SYN-101 can be checked.
  - `if_stmt` and `if_expr` share `If` with an optional `else_`; `if_stmt`, `match_expr` and
    `call_with_trailing_block` as statements are `Expr` statements (SYN-011: everything that can produce a value is
    an expression).
  - Slices: `Index` with a `Range` index represents both alternatives of `slice_or_index`. Correction (code-review
    of PR #4): the slice alternative is derivable from `expr` via `range_expr` only when both bounds are
    `bitor_expr`s. With `xs[a < b .. c]` or `xs[a or b .. c]` the two alternatives give different trees, so the EBNF
    is ambiguous (despite its LR(1) claim) and T-0011 does have to choose. Raised as **Q-0009** (blocks T-0011). No
    AST change needed.
  - `type_arg = type | expr` overlaps for paths; both constructors exist, the parser (T-0009/T-0011) decides.
  - Doc comments (LEX-011) are an optional field on file, top-level decls, fields, variants, trait and impl items.
    The lexer does not produce them yet (always `None` from the seed parser).
  - Spec-question **Q-0008**: `place = IDENT {…}` excludes `self`, contradicting SYN-012/MEM-024 (`inout self`).
    The AST follows the grammar as written; option A of Q-0008 would add one constructor. Blocks T-0010 only.
  - Bare-path patterns (`case State.Available:` is not derivable, `simple_pattern` has no bare `path`): spec gap
    already raised as **Q-0013** (T-0022 spec audit, PR #6); not duplicated here. Blocks T-0012.
- 2026-11-10 syntax-engineer/wave1: review follow-ups. (1) Added `import after a declaration is rejected` in
  test_parse.ml (SYN-002). Today's diagnostic is the generic `E0100 ... (SYN-001)`; **T-0013** should make it cite
  SYN-002 with an import-specific message. (2) Slice reasoning corrected (above), Q-0009 raised. (3) Node ids:
  follow-up **T-1006**; the earlier "side tables can key on spans" advice was wrong (an `Expr` statement and its
  expression share a span) and is dropped. Operator spans (`op_span` on `Binary`/`Compare`/`Assign`) suggested by
  the reviewer for T-0011.
- 2026-11-09 syntax-engineer/wave1: PR size. ~1130 non-test lines vs the ~400 target (AGENTS.md rule 9). The AST is
  one mutually recursive type group (expr ↔ block ↔ stmt ↔ pattern ↔ ty ↔ literal) and the printer must be
  exhaustive over it (warning 8 is an error), so neither can land in halves. About 310 lines of ast.ml are the
  type definitions repeated from ast.mli without comments, and ~240 lines of ast.mli/print.mli are documentation.

### Production → constructor table (spec/grammar/egide.ebnf → compiler/lib/syntax/ast.mli)

| EBNF production / alternative | AST |
|---|---|
| `file` | `file` record (`doc`, `module_path`, `imports`, `decls`) |
| `doc_comment` (LEX-011) | `doc : string option` on `file`, `decl`, `field`, `variant`, `trait_item`, `impl_item` |
| `module_decl` | `file.module_path : path` |
| `path` | `path` record (`segments : ident list`) |
| `IDENT` | `ident` record |
| `import_decl` = `"import" path [ ".{" … "}" ] [ "as" IDENT ]` | `Import { path; items; alias }` |
| `import_decl` = `"import" "go" STRING "as" IDENT` | `Import_go { package; alias }` |
| `import_item` | `import_item` record |
| `top_decl` | `decl` record (`attrs`, `pub`, `decl : decl_desc`) |
| `attribute` | `attribute` record (`args = None` without parentheses) |
| `fn_decl` | `fn_decl` record; top level: `Fn` |
| `fn_sig` | `fn_sig` record |
| `params`, `param` | `fn_sig.params : param list`; `param` record, `Param_self`, `Param_named` |
| `"inout" \| "take" \| "comptime"` | `mode` = `Inout`, `Take`, `Comptime` (absent: `By_read`) |
| `using_clause`, `cap_param` | `fn_sig.using : typed_ident list` |
| `generics`, `generic`, `bound` | `generic list`; `generic` record; `bound` = `ty` |
| `struct_decl` | `Struct` |
| `field` | `field` record |
| `enum_decl` | `Enum` |
| `variant` | `variant` record (`Vf_none` without parentheses) |
| `variant_fields` positional / named | `Vf_positional` / `Vf_named` |
| `trait_decl` | `Trait` |
| `trait_item` = `fn_sig` / `fn_decl` / `"type" IDENT [ ":" bound ]` | `Ti_sig` / `Ti_fn` / `Ti_type` |
| `impl_decl` | `Impl` (`trait_` = type before `for`) |
| `impl_item` = attrs `pub` `fn_decl` / `"type" IDENT "=" type` | `Ii_fn` / `Ii_type` |
| `type_decl` | `Type` (`newtype`, `where_`) |
| `const_decl` | `Const` |
| `type` = `base_type "?"` | `Ty_optional` |
| `base_type` = `path [ "[" type_args "]" ]` | `Ty_path { path; args }` |
| `base_type` = `"(" … ")"` (unit, tuples) | `Ty_tuple` (`[]` = unit) |
| `base_type` = `"fn" "(" … ")" [ "->" type ] [ "using" … ]` | `Ty_fn` |
| `base_type` = `"dyn" bound` | `Ty_dyn` |
| `base_type` = `"Self"` | `Ty_self` |
| `type_args`, `type_arg` = `type` / `expr` | `type_arg list`; `Ta_type` / `Ta_expr` |
| `block` (indented / `simple_stmt`) | `block` record (`stmts`) |
| `stmt`, `simple_stmt` = `expr` | `stmt` record; `Expr` |
| `simple_stmt` = `"let" pattern … [ "else" ":" block ]` | `Let { pat; ty; value; else_ }` |
| `simple_stmt` = `"var" …` | `Var` |
| `simple_stmt` = `"comptime" "let" …` | `Comptime_let` |
| `simple_stmt` = `place assign_op expr` | `Assign { place; op; value }` |
| `assign_op` | `assign_op` (`Simple_assign`, `Add_assign`, … `Shr_assign`) |
| `place` | `place` record, `Place_field`, `Place_index` |
| `"return" [ expr ]`, `"break" [ expr ]`, `"continue"` | `Return`, `Break`, `Continue` |
| `"defer" expr`, `"yield" expr` | `Defer`, `Yield` |
| `compound_stmt` | the constructors below |
| `if_stmt` | `Expr` of `If` (`else_` optional) |
| `for_stmt`, `while_stmt`, `loop_stmt` | `For`, `While`, `Loop` |
| `with_stmt`, `with_item` | `With`; `with_item` record |
| `given_stmt` | `Given` |
| `match_expr` | `Match` |
| `case_arm` | `case_arm` record (`guard`) |
| `call_with_trailing_block` | `Trailing { callee; params; body }` |
| `expr` | `expr` record |
| `lambda` = `lambda_head "=>" expr` | `Lambda` |
| `lambda` = `"fn" "(" … ")" [ "->" type ] ":" block` | `Fn_lit` |
| `lambda_head`, `lambda_params`, `lambda_param` | `lambda_param list`; `lambda_param` record |
| `pipe_expr` | `Binary { op = Pipe }` |
| `cond_expr` | `Cond` |
| `or_expr`, `and_expr` | `Binary { op = Or \| And }` |
| `not_expr` | `Unary { op = Not }` |
| `cmp_expr`, `cmp_op` | `Compare { first; rest }` (one node per chain, SYN-036); `cmp_op` |
| `range_expr` (all forms) | `Range { lo; hi; inclusive }` |
| `bitor_expr`, `bitxor_expr`, `bitand_expr` | `Binary { op = Bit_or \| Bit_xor \| Bit_and }` |
| `shift_expr`, `add_expr`, `mul_expr` | `Binary { op = Shl \| Shr \| Add \| Sub \| Mul \| Div \| Rem }` |
| `unary_expr` | `Unary { op = Neg \| Bit_not }` |
| `pow_expr` | `Binary { op = Pow }` |
| `postfix_expr` call / index / field / `?` | `Call` / `Index` / `Field` / `Try` |
| `args`, `arg` | `arg list`; `arg` record (`label`, `inout`) |
| `slice_or_index` = `expr` / slice | `Index` (slice: `Index` with a `Range` index) |
| `primary` = `literal` | `Lit` |
| `primary` = `path` / `"self"` / `"Self"` | `Path` / `Self` / `Self_type` |
| `primary` = `"(" ")"` / `"(" expr "," … ")"` | `Tuple` |
| `primary` = `"(" expr ")"` | `Paren` |
| `primary` = `"(" expr comp_clauses ")"` | `Comprehension { kind = Comp_iter }` |
| `primary` = `"[" [ expr_list ] "]"` / `"[" expr comp_clauses "]"` | `List` / `Comprehension { kind = Comp_list }` |
| `primary` = `"{" [ map_entries ] "}"` / `"{" expr_list "}"` | `Map` / `Set` |
| `primary` = `"{" map_entry comp_clauses "}"` / `"{" expr comp_clauses "}"` | `Comprehension { kind = Comp_map \| Comp_set }` |
| `primary` = `if_expr` / `match_expr` | `If` (`else_ = Some`) / `Match` |
| `primary` = `"unsafe" "(" "reason" ":" STRING ")" ":" block` | `Unsafe` |
| `expr_list`, `map_entries`, `map_entry` | `expr list`, `map_entry list`; `map_entry` record |
| `comp_clauses`, `comp_for`, `"if" or_expr` | `comp_clause list`; `Comp_for`, `Comp_if` |
| `literal` INT FLOAT DURATION STRING RAW_STRING BYTES CHAR TEMPLATE true/false | `Int` `Float` `Duration` `String` `Raw_string` `Bytes` `Char` `Template` (`Text`, `Interp`) `Bool` |
| `pattern` = `or_pattern "as" IDENT` | `Pat_as` |
| `or_pattern` | `Pat_or` (≥ 2 alternatives) |
| `simple_pattern` = `"_"` / `IDENT` | `Pat_wild` / `Pat_bind` |
| `literal_pattern` | `Pat_lit` of `lit_pattern` record (`negated`) |
| `range_pattern` | `Pat_range` |
| `path "(" [ field_patterns ] ")"` | `Pat_ctor` |
| `"(" pattern "," … ")"` | `Pat_tuple` |
| `"[" [ list_patterns ] "]"` | `Pat_list` |
| `field_patterns`, `field_pattern` | `field_pattern list`; `Fp_field`, `Fp_rest` |
| `list_patterns`, `list_pattern` | `list_pattern list`; `Lp_elem`, `Lp_rest` |

## Outcome

- **Done.** `compiler/lib/syntax/ast.mli` defines the AST for every production of spec/grammar/egide.ebnf (table
  above), with a `span` on every node and identifier. `compiler/lib/syntax/print.ml(i)` renders it as
  S-expressions (optionally with spans), with deterministic line breaking at 100 bytes; `print.mli` documents the
  format and states it is unstable for users. `egide parse` and the seed parser use the new AST.
- **Acceptance criteria.** (1) Production → constructor table: in the Log. (2) `[@@deriving show, eq]`: **partly**;
  ppx_deriving could not be installed in the sandbox (Log), so hand-written `Ast.equal_*` and `Print.pp_*` with the
  same roles are available to tests; T-0029 adopts ppx_deriving. (3) Printer stable and documented as
  unstable-for-users: `print.mli` header; determinism tested.
- **Tests added.** `compiler/test/syntax/test_ast_print.ml` (16 expect tests: every declaration, type, statement,
  expression, literal and pattern form, built by hand since the parser is still the seed; span mode on a parsed
  file and on hand-built nodes; line breaking; `pp_*`; equality positive and negative cases).
  `compiler/test/syntax/test_parse.ml`: existing snapshots unchanged; one negative test added (SYN-002).
- **Rules covered.** SYN-001, SYN-002, SYN-003, SYN-012, SYN-013, SYN-020..023, SYN-030, SYN-033..041, SYN-050,
  SYN-051, SYN-060, SYN-062, SYN-064, SYN-100 (representation and printing only; parsing them is T-0009..T-0012).
- **Follow-ups.** T-0029 (ppx_deriving show, eq), T-1006 (node ids). Spec-questions Q-0008 (`self` as an assignment
  place, blocks T-0010) and Q-0009 (slice ambiguity, blocks T-0011); Q-0013 (bare-path patterns) is from PR #6.
- **Limitations.** Doc comments are representable but not produced by the lexer yet. The AST has no node ids
  (architecture §2 invariant 3); spans are not unique keys, so T-1006 must add ids before resolve/types start.


