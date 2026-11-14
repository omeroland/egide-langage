---
id: T-1163
title: Spike — task context and implicit cancellation in generated Go
kind: task
phase: 0
role: go-backend-engineer
depends_on: []
spec: [CON-010, CON-011, GO-022]
paths: [bench/, runtime/go/]
estimate: S
labels: [perf, spike]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Numbers for Q-0062: the call overhead of a hidden task-context parameter on generated Go functions, in the two variants
A1 (only functions that can reach a blocking operation) and A2 (every function).

## Context

Go has no goroutine-local storage; `runtime/go/rt/scope.go` currently passes the scope explicitly. See Q-0062.

## Acceptance criteria

- [ ] A micro-benchmark in `bench/` of a recursive pure function and of a closure-heavy pipeline, with and without the
      hidden parameter
- [ ] A blocking example (channel receive under a scope timeout) showing cancellation reaching a nested scope through the
      parameter
- [ ] Results in the Outcome and a recommendation appended to Q-0062

## Out of scope

Changing `rt` public API; the M:N scheduler of the native backend.

## Log

## Outcome
