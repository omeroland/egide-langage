---
id: T-0029
title: Adopt ppx_deriving show, eq for the AST
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008]
spec: []
paths: [dune-project, egide.opam, compiler/lib/syntax/dune, compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/print.mli, compiler/test/syntax/, CHANGELOG.md]
estimate: S
labels: []
status: done
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

`compiler/lib/syntax/ast.ml(i)` use `[@@deriving show, eq]` (ppx_deriving, listed in ADR-0001) instead of the
hand-written `equal_*` functions and the `Print.pp_*` stand-ins added by T-0008.

## Context

T-0008 could not add the dependency: in the agent sandbox `opam install ppx_deriving` fails because fetching its
build dependency `cppo` returns HTTP 403 through the egress proxy (and `opam.ocaml.org` is rejected), so `make ci`
could not have run locally. ppx_deriving is not yet declared in `dune-project`, so CI does not install it either.
T-0008 kept the names ppx_deriving generates (`Ast.equal_file`, `Ast.equal_expr`, …) so that callers do not change.
Needs an environment where `opam install ppx_deriving` works (or the owner/release-manager adding it to the CI
image).

## Acceptance criteria

- [x] `ppx_deriving` declared in `dune-project` (and the regenerated `egide.opam`); CI installs it
- [x] `[@@deriving show, eq]` on the AST types; the hand-written `equal_*` in ast.ml removed; existing tests unchanged
- [x] `Print.pp_*` kept as the S-expression formatters (or renamed, with callers updated) and documented

## Out of scope

Changing the S-expression format of `Print`.

## Log

2026-11-10 syntax-engineer: claimed, main 499766f (T-1030 and T-1006 merged). Read the Logs of T-1006 and T-1030, the
reviews of PRs #17 and #23, ast.ml(i), node_id.ml(i), print.ml(i).

Environment (established): `opam install ppx_deriving` in the sandbox first failed on `cppo.1.8.0` (github archive
tarball, HTTP 403 through the proxy). The sanctioned workaround `/home/claude/scripts/gitify.py cppo.1.8.0` (rewrites
the opam source to `git+https://github.com/ocaml-community/cppo#v1.8.0`) then installed `cppo 1.8.0` and
`ppx_deriving 6.0.3` (the solver picks 6.0.3 because the switch has ppxlib 0.35.0; 6.2.0 needs ppxlib >= 0.36). That
edit is to the sandbox's local opam repository only, not to the repo. CI: `.github/workflows` runs
`opam install . --deps-only --with-test --with-dev-setup`, so declaring `ppx_deriving` in `dune-project` (and the
regenerated `egide.opam`) is all it needs. *Not verified:* CI resolves the newest ppx_deriving its ppxlib allows (likely
6.2.0, which I could not build here); the generated function names and the attributes used are the documented stable
ones.

Decisions:

- **Dependency and flags.** `(ppx_deriving (>= 6.0))` in dune-project; library `egide.syntax` gets
  `ppx_deriving.show ppx_deriving.eq` in `pps` and `ppx_deriving.runtime` in `libraries`.
- **Which types.** `[@@deriving show, eq]` once per recursive group (on its last declaration), in ast.ml and
  ast.mli (the .mli needs it to export `pp_x`, `show_x`, `equal_x`). 12 groups, so every node type, not only the seven
  of T-0008, now has `equal_*` and `pp_*`/`show_*`. The seven hand-written `equal_*` and their `.mli` section are gone.
- **`Node_id`.** No attribute: the derivers find `Node_id.equal` and `Node_id.pp` by name, as the T-1006 Log said.
  Equality still compares ids and spans (the derived functions are structural like the old `( = )`); a test checks
  agreement with `( = )` on equal and different trees.
- **`span`.** `Egide_source.Span` has `pp` but no `equal`, and `compiler/lib/source` is outside this task's paths. So
  ast.ml defines `pp_span = Span.pp` and `equal_span = ( = )` (Span is strings and ints) and does not derive for `span`.
  Alternative: add `Span.equal` in source/. Rejected here only for path ownership; it is a one-line follow-up if the
  owner prefers (then `equal_span` becomes `Egide_source.Span.equal`).
- **`Uchar.t`.** `Uchar.pp` does not exist in OCaml 5.2, so `Char of (Uchar.t [@printer pp_uchar])` prints `U+XXXX`.
  `Uchar.equal` exists.
- **`Print.pp_*` kept** as the S-expression formatters (task criterion 3, and the T-1006 Log: the derived `show` prints
  `#n` and spans on every node, which is wrong for snapshots). They shadow `Ast.pp_*` only inside print.ml, which opens
  Ast; elsewhere the qualified names differ. print.mli documents the split, ast.mli has a new "Derived functions"
  section. No S-expression output changed (all existing snapshots pass untouched). Alternative: rename the Print
  formatters (e.g. `pp_sexp_*`); rejected, it changes callers for no gain and the criterion allows keeping the names.
- **Paths.** Added `compiler/lib/syntax/print.mli` (documentation only) and `CHANGELOG.md` to the front matter. `layout.ml`
  and `print.ml` untouched.
- **Rule 3.** Red commit: `test_ast_deriving.ml` alone, does not compile on main (`Unbound value "show_ident"`). Green
  commit: the implementation. One expectation was written from the documented ppx_deriving output format and passed
  unchanged: `{ Ast.id = #0; name = "x"; span = f.egd:3:4 }`.
- **ocamlformat** is not installed here (`make ci` prints the skip warning), so the formatting of the new lines is by
  hand; GitHub CI is the authority.

## Outcome

ppx_deriving declared (`dune-project`, regenerated `egide.opam`) and wired into `egide.syntax`. `Ast` derives `show` and
`eq` for all node types; the hand-written `equal_*` are removed; `Print.pp_*` stay the S-expression formatters and are
documented as such. `make ci` passes locally (build, unit tests, conformance 93 passed / 0 failed / 46 skipped by phase,
Go tests); the OCaml format check was skipped (not installed).

Tests: `compiler/test/syntax/test_ast_deriving.ml` (derived `show` record syntax with id and span; `Uchar`; `Print.pp_expr`
still S-expression without ids while `Ast.pp_expr` shows them; `equal_*` on ident, path, bound, arg, literal, span compare
ids and spans; derived equal agrees with `( = )`). Existing tests unchanged. Rules covered: none (infrastructure).

Follow-ups: none created (optional: `Span.equal` in `egide.source`). Limits: verified against ppx_deriving 6.0.3 only;
ids in `show` output depend on the grammar (not stable, see node_id.mli), so do not snapshot derived `show` output of
parsed trees.
