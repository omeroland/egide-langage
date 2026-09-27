# ADR-0001: OCaml 5 for the bootstrap compiler

- Status: Accepted
- Date: 2026-09-26
- Deciders: Omeroland

## Context

Égide's frontend must implement bidirectional type inference, trait resolution, exhaustiveness checking, capability
resolution and an interpreter. The implementation language determines how safely the AST and each pass can evolve.

## Decision

`egidec` is written in OCaml 5 with dune, Menhir (parser), sedlex (Unicode lexer), ppx_deriving, ppx_expect, alcotest,
qcheck and linol (LSP). The compiler is rewritten in Égide in phase 8 (self-hosting).

## Alternatives considered

| Option | Why not |
|--------|---------|
| Go | no sum types or exhaustive match: every AST change risks silent bugs in passes |
| Rust | strong candidate; slower iteration on tree-heavy code, borrow checker friction in compiler passes |
| Hybrid OCaml frontend + Go runtime | adopted in effect: the Go runtime lives in `runtime/go` |

## Consequences

- Algebraic data types make "a new AST node was not handled" a compile-time error of the compiler itself.
- Lineage: first Rust compiler, Hack, Flow, Haxe, the WebAssembly reference interpreter.
- Contributors need OCaml; agents get `agents/style-guide-ocaml.md`.
