---
id: T-1110
title: Audit, SBOM, lockfile, LSP, test and panic output call Escape (LEX-006)
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-1039]
spec: [LEX-006, SYN-018]
paths: [compiler/bin/, compiler/lib/diagnostics/, compiler/test/diagnostics/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

When each tool that prints source text or string values is implemented (`egide audit`, SBOM/CycloneDX, lockfile writer, LSP messages and hover, test and panic output), it must use `Egide_diagnostics.Escape` (`display`, `json_safe`) and write through `Output`. Extend the lint test of T-1039 to cover each new renderer as it lands.

## Context

T-1039 (ADR-0017 S1) adds `Escape`, `Output`, `Forbidden_set` and a lint on `compiler/bin/main.ml` and `diagnostic.ml`. The lint is a source scan; new renderers in other directories (`compiler/lib/pkg/`, `compiler/lib/lsp/`) are not covered until they are added to it. Also pending: `Print.quote` in the AST printer should render the LEX-003 set as `\u{H}` (syntax-engineer, after T-1033).

Also pending (security review of T-1039, F4/F5): new tools must use `Output.line`/`Output.eline` for single-line output (audit rows, LSP messages, SBOM entries) and `Output.block` only for text that is multi-line by construction. `Egide_source.Span.pp` prints the file name raw and `Print.pp_*` use `Format` outside `Output`; they are not reachable from the CLI today, but must be deleted, routed through `Escape.display`, or documented (T-1111 decides). In `--error-format=json` mode the I/O error of `main.ml` is currently a non-schema JSON line `{"kind":"io_error","message":...}`: a catalogued diagnostic code for I/O errors in docs/diagnostics.md (owner) is needed.

## Acceptance criteria

- [ ] The lint test lists every renderer source file and fails on raw print primitives or a missing `Escape.` use
- [ ] Each new tool has a test printing a value with `\u{1B}[2K`, RLO and ZWSP, for its human and machine formats

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-11 syntax-engineer (T-0004, security review F7): diagnostic messages that quote a token or a value are built
with OCaml's `%S` in places (the `lex` command prints `STRING("\195\169")`: `é` as decimal bytes, backslashes doubled), and
then pass through `Escape.display`, which doubles the backslashes again. The output is safe but unreadable and not
injective with respect to the value. Decide, in this task and in the T-1039 follow-ups, one rendering of a string value
for tools (UTF-8 text through `Escape.display`, no `%S`).

## Outcome
