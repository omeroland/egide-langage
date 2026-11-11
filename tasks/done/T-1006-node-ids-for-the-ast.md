---
id: T-1006
title: Node ids for the AST
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008]
spec: []
paths: [compiler/lib/syntax/node_id.ml, compiler/lib/syntax/node_id.mli, compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/parser.mly, compiler/lib/syntax/parse.ml, compiler/lib/syntax/parse.mli, compiler/lib/syntax/print.ml, compiler/lib/syntax/print.mli, compiler/test/syntax/]
estimate: M
labels: []
status: done
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
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

- [x] `Node_id` module with an abstract `t`, `equal`, `compare`, `to_int`; ids unique within a parsed file
- [x] The parser allocates ids from a counter in an explicit context; same input gives the same ids
- [x] `Print` omits ids by default (snapshots unchanged) and shows them with an option
- [x] A test checks uniqueness of ids over a parsed file

## Out of scope

Side tables themselves (resolve/types).

## Log

2026-11-10 syntax-engineer (T-1030): merge after T-1030 (PR #17). New nodes needing ids: `bound`, `arg` / `arg_desc`, `type_def` is not a node. `parser.mly` was touched by T-1030 (three constructor hunks of the seed subset).

2026-11-10 syntax-engineer (T-1006): claimed on top of T-1030 (main 0881324). Read the review of PR #17 (`bound`, `arg`
must get ids), ADR-0018 (the AST does not depend on the surface syntax, so no layout or grammar change here).

Decisions (labels per AGENTS 2b: all *established* by tests unless marked *extrapolated*):

- **Which nodes carry an id.** `ident`, `path`, `expr`, `arg`, `bound`, `block`, `stmt`, `pattern`, `ty`, `decl`,
  `generic`, `param` (so `self`, which has no ident, has a key), `field`, `variant`, `trait_item`, `impl_item`,
  `fn_decl`. Rule: a node has an id if a later pass annotates or scopes it and no child it always contains identifies
  it. No id: `lambda_param`, `typed_ident`, `with_item`, `case_arm`, `if_branch`, `map_entry`, `attribute`, `fn_sig`,
  `import`, `import_item`, `lit_pattern`, `field_pattern`, `list_pattern`, `comp_clause`, `file`; their identity is a
  child's id (the binder `ident`, the `pattern`, the `block`). Alternative considered: an id on every record that has a
  `span` (uniform, trivially checkable by T-0029-style deriving), rejected: 14 more fields that no pass keys on,
  and every hand-built test tree pays for them. If resolve or types needs one of the excluded kinds, adding a field is
  mechanical (ast.mli, the parser site, `ids_of_file` in test_node_ids.ml). Cost asymmetry (review of PR #23): adding an
  id later costs one field plus every parser site and every hand-built tree written by then, so it is cheapest now,
  while the parser builds only the seed subset, and grows with T-0009..T-0012. That argues for generosity now, not for
  the uniform alternative. The kinds most likely to need one later: `import` / `import_item` (T-0030) and the two ends of
  a `lit_pattern` range (type checker, T-0032); the procedure above applies to them. *Extrapolated:* that the list above is what
  T-0030 and the type checker need; the `block` id is for scopes, `generic`/`field`/`variant` for item tables.
- **Allocation.** `Node_id.Gen.t` (counter) passed to the parser as the Menhir `%parameter` `Ids`; `Parse.file ?gen`
  (default: a fresh generator, ids from #0). Ids are numbered in reduction order (children before parents), a function
  of the parse alone. Alternatives rejected: (a) a global or domain-local counter set by `Parse.file`: violates
  invariant 5 and is not reentrant; (b) a numbering pass after parsing: would rebuild an immutable tree and run a second
  full traversal in the lib, for nothing the parser cannot do. Cost: the generated parser is now `Parser.Make (Ids)`,
  and the exception is `P.Error` of the instance. T-0013 (`--compile-errors`, parser.messages) must be run against the
  functor form; I did not test that (no `parser.messages` exists yet).
- **Warning 67.** Menhir's generated `parser.mli` is `module Make (Ids : sig ... end) : sig ... end` and the result does
  not mention `Ids`, so OCaml's dev profile fails with warning 67 (unused functor parameter). I did not silence it
  (rule 4): the start symbol is typed `%start <Ids.file> file` with `type file = Ast.file` in the parameter signature,
  so the signature uses the parameter. Cosmetic, documented in parser.mly. If the owner prefers a warning flag in the
  dune file, that is a one-line change outside this task's paths.
- **Equality.** `Ast.equal_*` stay structural, so they now compare ids as well (like spans). Two parses of one source are
  equal; hand-built trees with fresh ids are not (the one test that relied on this was adjusted and says so). For
  shape-only comparison use `Print` (omits spans and ids). T-0029: `[@@deriving eq]` on the `id` fields calls
  `Node_id.equal`, and `show` needs `Node_id.pp`; both exist, so T-0029 needs no `[@equal]`/`[@printer]` attribute. The
  default `show` output would print `#n` in every node; T-0029 should keep `Print.pp_*` for the S-expression and not
  switch Alcotest testables to the derived `pp_*` without deciding that.
- **Print.** `?ids:bool` (default `false`, so no existing snapshot changed: `dune test` passed with the old
  expectations untouched, apart from the equality test below). Ids print as an `#n` atom after the span atom, `x#n`
  after a span suffix. A node that prints as a bare atom shows its own id (`Pat_bind`, a path, `T`, `_`, `Self`); a
  wrapper that adds no syntax (`Stmt.Expr`, an unlabelled plain argument, the `fn_decl` inside a declaration or item)
  shows its child's. So Print does not list every id; the test oracle `ids_of_file` does.
- **Paths.** The task's `paths` listed ast, parser, print and the tests; the front matter now also lists `node_id.ml(i)`
  (new module, required by the acceptance criteria) and `parse.ml(i)` (the parser became a functor; `Parse.file` gains
  `?gen`). Nothing else outside the original paths changed. `dune` was not touched.
- **Cross-file ids.** The default generator is per file, so ids are unique within a file only, as the acceptance
  criteria say; a driver that wants one table over several files passes one `?gen` to every `Parse.file` (tested:
  disjoint ranges) or keys on (file, id).
- **Rule 3 (tests first).** Done as two commits: 63c42fa holds only the tests and does not compile on its parent (`Unbound
  module Node_id`, verified in a scratch worktree), 772ac55 the implementation. The red commit includes the mechanical
  update of the `test_ast_print.ml` builders (one `id = nid ()` per node) because they cannot compile without the field.
- **Mutation check** (not in CI): `Gen.fresh` not incrementing, and a process-global default generator in `Parse.file`,
  were each caught by `test_node_ids.ml`; both reverted.
- **ocamlformat** 0.28.1 does not build here, so the format check is skipped locally: the code was formatted by hand to the
  profile (margin 100; comments are not wrapped). GitHub CI is the authority.
- **Review of PR #23 (code-reviewer, REQUEST_CHANGES), addressed in new commits.** (1) The assertion `equal_expr (int "1")
  (int "01") = false` is restored, plus a same-id variant (`{ one with expr = Lit (Int "01") }`). (2) Density was
  over-specified: the tests now assert uniqueness, `id < Gen.count` and determinism; `node_id.mli` says ids need not be
  contiguous (failed parse, T-0013 recovery, SYN-065 cover conversions discard nodes after allocating their ids). The
  hand-built tree keeps `nodes = allocated` as the oracle self-check only. (3a) The keying convention is in ast.mli:
  binders by `ident.id`, references by `path.id`, typing results by `expr`/`pattern`/`ty`/`stmt`/`param` id; a pass that
  wants another assignment writes it there first. (3b) `node_id.mli`: a shared `Gen.t` is not domain-safe, ids are not
  stable across builds and must not be persisted. (3c) Logs of T-0009, T-0011, T-0013. Suggestions: boxes ticked; parser.mly
  comment now says the parameter's `type file` is what avoids warning 67; dead `ignore first` and the unexplained `| _ ->
  ()` removed; the earlier-parse test compares against a baseline instead of `List.mem 0`; the qcheck generator varies
  path length and value kind (still the seed subset's four node kinds, so it does not cover nesting). Not done: printing
  both ids of doubled cases in `Print ~ids` (review item 9, a later task if debugging needs it).
- **Order with T-0029.** T-0029 comes after this task (it replaces the hand-written `equal_*` at the end of ast.ml and
  the `Print.pp_*` stand-ins, neither of which this task restructured). The only shared lines are the new `id` fields
  in the record types, which T-0029 annotates, not edits.
- Notes added to the Logs of T-0009..T-0013 and T-0029 (every parser action that builds an id-bearing node writes
  `id = Ids.fresh ()`).

## Outcome

`Node_id` (abstract `t`, `equal`, `compare`, `hash`, `to_int`, `pp`; `Gen` with `create`/`fresh`/`count`) and an
`id : Node_id.t` field on 17 node kinds (list and rule in the Log and in ast.mli). The parser takes its generator as the
Menhir parameter `Ids`; `Parse.file ?gen` supplies it (fresh per file by default), ids are numbered in reduction order,
so the same input gives the same ids. `Print` takes `?ids` (default off; no existing snapshot changed).

Tests: `compiler/test/syntax/test_node_ids.ml` (generator; uniqueness, `id < Gen.count` and determinism on a parsed file; shared
generator across files; `Print ~ids`; a hand-built tree with every id-bearing kind checked against the traversal oracle;
a qcheck property over generated seed-subset programs, with dotted paths and literal and path values); `test_ast_print.ml` builders allocate ids and the equality test
now states that equality compares ids. Rules covered: none (spec-neutral; architecture §2 invariants 3 to 5).

Follow-ups: none created. T-0029 (deriving) comes next and needs nothing from this task beyond what the Log says.
Known limits: the parser still builds only the seed subset, so ids of the other node kinds are exercised through
hand-built trees only until T-0009..T-0012; `ids_of_file` must be kept in step with ast.mli by hand; `parser.messages`
against the functor form is untested (T-0013).
