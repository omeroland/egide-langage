# ADR-0003: Object capabilities as the only authority; `using` as the effect system

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 6, 10, 11, 12

## Context

v0.1 had both capabilities and a separate effect system (`with io, net`). They were redundant: if I/O requires a
capability value, the signature already reveals the effect.

## Decision

All authority flows from `main(sys: Sys)` as unforgeable, attenuable capability values. `using` clauses make
capabilities implicit parameters that remain visible in function types; `given` provides them. Pure = no capability.
No mutable globals.

## Consequences

- One mechanism instead of two; the effect system comes for free (as in Effekt and Scala capture checking).
- Supply-chain benefit: dependencies cannot perform I/O they are not handed; the manifest only lists breaches.
- Library security types (`Untrusted`, `Secret`, sinks) become unforgeable.
- Cost: capability threading in deep call chains, mitigated by `using`/`given`.
