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
status: in-progress
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

- [ ] `ppx_deriving` declared in `dune-project` (and the regenerated `egide.opam`); CI installs it
- [ ] `[@@deriving show, eq]` on the AST types; the hand-written `equal_*` in ast.ml removed; existing tests unchanged
- [ ] `Print.pp_*` kept as the S-expression formatters (or renamed, with callers updated) and documented

## Out of scope

Changing the S-expression format of `Print`.

## Log

2026-11-10 syntax-engineer (T-1006): T-1006 (node ids) lands first. `Ast` records now have `id : Node_id.t`; `Node_id.equal` and `Node_id.pp` exist, so derived eq/show need no attribute on them. Derived `equal_*` will compare ids, like the hand-written ones. Keep `Print.pp_*` as the S-expression formatter (the derived show would print `#n`).

## Outcome
