# ADR-0007: Structured, uncoloured concurrency

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 7

## Decision

Goroutine-like tasks on an M:N scheduler, no `async`/`await`; every task belongs to a `scope` that waits for it and
cancels siblings on failure (Trio, Kotlin); cancellation and deadlines propagate implicitly; channels are bounded by
default.

## Consequences

No orphan tasks, no split ecosystem between sync and async libraries, direct mapping to goroutines in the Go backend.
