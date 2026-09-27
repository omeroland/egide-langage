# Compiler architecture

`egidec` is written in **OCaml 5** (ADR-0001) and built with **dune**. This document is the map every implementation
agent reads before touching `compiler/`. It is descriptive; the language itself is defined only by `spec/`.

## 1. Pipeline

```
 .egd source
    │  compiler/lib/syntax/lexer.ml      sedlex, UTF-8, LEX-001..062, forbidden code points
    ▼
 raw tokens ── layout.ml ──► tokens with NEWLINE / INDENT / DEDENT (LEX-030..035)
    │  compiler/lib/syntax/parser.mly    Menhir LR(1), incremental API for error messages
    ▼
 AST (syntax/ast.ml)                     concrete positions on every node, no semantic info
    │  compiler/lib/resolve/             modules, imports, scopes, name resolution, cycle detection (PKG-002)
    ▼
 Resolved AST
    │  compiler/lib/types/               bidirectional type checking, traits, generics, exhaustiveness,
    │                                    validated types, `using` resolution (CAP-030..034)
    ▼
 HIR (hir/hir.ml)                        fully typed, desugared (pipes, comprehensions, trailing blocks, `?`)
    │  compiler/lib/comptime/            bytecode compiler + interpreter (also REPL, egide run, egide test)
    │                                    evaluates comptime, derive, templates (CT-*)
    │  compiler/lib/check/               exclusivity (MEM-021), moves (MEM-023), resources (ERR-032),
    │                                    purity (CAP-040), Send (CON-021), security lints
    ▼
 MIR (mir/mir.ml)                        control-flow graph, explicit copies/COW points, drops, defers
    ├── compiler/lib/backend_go/         MIR → Go source → `go build` (static binary)
    └── compiler/lib/backend_c/          MIR → C + Perceus RC + ORC cycle collector + M:N scheduler (phase 6)
```

Cross-cutting libraries:

| Library | Path | Role |
|---------|------|------|
| `egide.diagnostics` | `compiler/lib/diagnostics/` | diagnostic type, codes, rendering (human and JSON, TOOL-040..042) |
| `egide.source` | `compiler/lib/source/` | files, spans, line index |
| `egide.driver` | `compiler/lib/driver/` | orchestrates passes, caching, parallel type checking with Domains |
| `egide.pkg` | `compiler/lib/pkg/` | manifest, lockfile, MVS resolution, signatures (PKG-*) |
| `egide.goint` | `compiler/lib/goint/` | Go package import (via `go list -json` + `go/types` export helper), purity analysis (GO-040..044) |
| `egide.fmt` | `compiler/lib/fmt/` | formatter over the lossless CST (trivia kept by the lexer) |
| `egide.lsp` | `compiler/lib/lsp/` | language server on `linol` |

## 2. Invariants every pass keeps

1. **Every node carries a `Span.t`.** Diagnostics always point at source.
2. **Passes never raise on user errors.** They report diagnostics to the `Diagnostics.sink` and return a best-effort
   result (error recovery), so one run reports as many independent errors as possible. `Failure`/`assert false` are for
   compiler bugs only and are reported as `ICE` (internal compiler error) with a request to file a bug.
3. **ASTs are immutable.** Passes produce new trees; side tables are keyed by node ids (`Node_id.t`).
4. **Determinism.** Same input → same output byte for byte (PKG-050). No `Hashtbl` iteration order in output; sort.
5. **No global mutable state** in library code (mirrors CAP-021); state lives in explicit context records.
6. **Exhaustive matches.** Warning 8 (non-exhaustive match) and 9 are errors; no catch-all `_ ->` on AST variants
   unless justified by a comment.

## 3. Module layout conventions

```
compiler/
├── bin/main.ml                 CLI entry point (`egide` executable)
├── lib/<library>/dune          one dune library per directory, name `egide_<library>`
├── lib/<library>/<module>.ml   implementation
├── lib/<library>/<module>.mli  REQUIRED interface for every module exposed outside its library
└── test/<library>/             unit tests (ppx_expect snapshots, alcotest, qcheck)
```

## 4. Runtime (Go backend)

`runtime/go/rt` is a Go package linked into every Go-backend binary. It implements structured scopes (CON-001..004),
cancellation, capability roots (`Sys`), `Result`/`Option` helpers for generated code, copy-on-write collections, and
the capability-checked wrappers over the Go standard library. Generated Go code MUST only call Go standard-library
functions through `rt` wrappers or through functions classified `pure` in the Go purity list.

## 5. Performance targets (phase 5 exit)

- Lexing + parsing: ≥ 1 M lines/s on one core.
- `egide check` of a 50 k-line package: < 2 s cold, < 200 ms incremental (LSP).
- Go-backend binaries within 1.5× of equivalent hand-written Go on the benchmark suite (`bench/`).
