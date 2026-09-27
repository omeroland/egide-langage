# ADR-0002: Mutable value semantics instead of borrow checking

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 5, 7

## Context

Rust's ownership model gives memory safety and race freedom but lifetimes are its main adoption barrier. Égide targets
Go/Python use cases where fine layout control matters less than approachability.

## Decision

Variables hold independent values; copies are logical and implemented with copy-on-write; parameters are read,
`inout` (exclusive, checked per call) or `take` (move). References cannot be stored or returned. `Shared[T]` is the only
reference type. See MEM-001..070.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Rust-style ownership with lifetime elision | still requires lifetimes in hard cases; non-local errors |
| Tracing GC with shared mutable references (Go) | data races possible; aliasing bugs |
| Pure immutability (Haskell, Elm) | unfamiliar for imperative code; performance surprises |

## Consequences

- No lifetime annotations; exclusivity diagnostics are local to one call.
- No self-referential structures; graphs use `Arena` + `Id`.
- Data-race freedom follows directly (ch. 7).
- Requires efficient COW and in-place reuse (Perceus) in the native backend.
