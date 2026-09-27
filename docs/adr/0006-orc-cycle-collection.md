# ADR-0006: Targeted cycle collection for `Shared`

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 5

## Decision

Reference counting (Perceus) everywhere in the native backend, plus a trial-deletion cycle collector that only tracks
`Shared` types the compiler proves potentially cyclic (Nim 2 ORC model). `Weak[T]` remains available; `@acyclic`
opts out with compiler verification.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Mandatory `Weak` (Swift) | a forgotten `Weak` leaks silently; in long-running services a leak is a delayed denial of service |
| Full tracing GC | pauses, and would make RC's in-place reuse pointless |

## Consequences

Acyclic data pays nothing. The Go backend relies on Go's GC with identical observable behaviour.
