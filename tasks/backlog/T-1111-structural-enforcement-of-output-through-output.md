---
id: T-1111
title: Structural enforcement of Output-only I/O (replace the text-scan lint)
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-1039]
spec: [LEX-006]
paths: [compiler/bin/, compiler/lib/diagnostics/, compiler/test/diagnostics/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Make "no string reaches stdout/stderr without `Escape`" a compile-time property of `compiler/bin/`, instead of a token scan.

## Context

Security review of T-1039 (F1). The test-side lint of T-1039 tokenizes sources and rejects known I/O paths, aliases and opens, but a new primitive, a function reached through another library, or `Unix.descr_of_out_channel` can still slip through. Suggested design: a module `Egide_diagnostics.Restricted` that shadows `print_*`, `prerr_*`, `stdout`, `stderr`, `Printf`, `Format`, `Fmt`, `Unix` and `Out_channel` with `[@@alert egide_raw_io "use Output"]`; compile `compiler/bin` with `-open Egide_diagnostics.Restricted -alert ++egide_raw_io`. `Output` itself is compiled without it. Keep the text lint as a second layer.

## Acceptance criteria

- [ ] A bin module calling any shadowed primitive fails to build (a dune rule or expect test demonstrates it)
- [ ] The twelve bypass snippets of the T-1039 review (`bypass_snippets` in `test_escape.ml`) fail to build or to lint
- [ ] `egide.syntax` and other libraries that print (e.g. `Span.pp`, `Print.pp_*`) are listed in the Log with a decision: route through `Escape.display`, delete, or document

- [ ] Allow-list instead of deny-list: the allowed modules and functions of `compiler/bin/` are enumerated (or a dune rule / alert forbids everything else); the deny-list of the T-1039 lint is not extended piecemeal
- [ ] The re-verification snippets of the T-1039 security review (R2-R4) are acceptance tests and must be rejected: `external` declarations of `caml_ml_open_descriptor_out` and `caml_ml_output`; `Buffer.output_buffer (open_out "/dev/stderr")`; `Marshal.to_channel`; `Printexc.print_backtrace`; `Sys.command` with a `printf ... 1>&2` payload
- [ ] `Output.block` and `Output.eblock` take an abstract type (`Escaped.t`) that can only be produced by the escaped renderers (`Diagnostic.to_human`, `Print.file` wrapped by an escaping function), so a raw `string` cannot be passed; `Output.line` keeps taking `string` and escapes LF

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 syntax-engineer (T-0029, review of PR #25): ppx_deriving now generates `Ast.show_*` and `Ast.pp_*` for every node type. They are documented in ast.mli as reserved for tests and debugging, but nothing enforces it: extend the lint to reject `Ast.show_*` / `Ast.pp_*` (and `Print.pp_sexp_*` if they are to stay test-only) in compiler/bin and any tool library. `Ast.pp_span` escapes the file name with `Escape.display`; string literal values and identifiers in the derived output are OCaml-escaped, not `Escape.display`-escaped. `Print.pp_*` was renamed `Print.pp_sexp_*` by T-0029.

## Outcome
