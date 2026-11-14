---
id: T-1162
title: Spike — cost of copy-on-write values on the Go backend
kind: task
phase: 0
role: go-backend-engineer
depends_on: []
spec: [MEM-001, MEM-010, MEM-064]
paths: [bench/, runtime/go/]
estimate: M
labels: [perf, spike]
status: backlog
claimed_by:
claimed_at:
---

## Goal

A measured answer, before the MIR and the Go backend are designed, to: what does MEM-010 cost on a runtime that has no
reference counts? The spike needs no compiler: it hand-writes the Go that the backend would emit.

## Context

MEM-010 requires in-place mutation of a uniquely referenced value and lazy copy otherwise. Go's collector does not expose
uniqueness, so `runtime/go/rt` must keep its own count on each copy-on-write buffer (atomic, since logical copies cross
tasks, CON-021) and generated code must emit retains and releases. `docs/architecture.md` §5 targets 1.5× of hand-written
Go. ADR-0027 (Proposed) makes that target conditional on this measurement.

## Acceptance criteria

- [ ] `runtime/go/rt` prototype (under a `spike` build tag) of a copy-on-write `List[T]` and `Map[K, V]` with an explicit count
- [ ] Three programs in `bench/`, each in two versions (idiomatic Go, and "as generated" Go using the prototype with
      bounds and overflow checks): list append and index in a loop; a struct holding two lists passed `inout` through
      three calls; a map updated from four tasks through `Shared[Mutex[Map]]`
- [ ] `go test -bench` results and allocation counts recorded in the Outcome, with the ratio per program
- [ ] The Outcome states which release points a compiler can omit safely (a missed release costs a copy, never safety)
      and whether a non-atomic fast path for values that never leave a task is worth an escape analysis

## Out of scope

MIR design, code generation, Perceus reuse analysis. The prototype is deleted or rewritten by T-0060.

## Log

## Outcome
