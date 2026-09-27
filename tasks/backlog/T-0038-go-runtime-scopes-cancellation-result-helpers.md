---
id: T-0038
title: Go runtime: scopes, cancellation, Result helpers
kind: task
phase: 1
role: go-backend-engineer
depends_on: [T-0001]
spec: [CON-001, CON-002, CON-003, CON-004, CON-010, CON-011]
paths: [runtime/go/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Harden the seed `rt.Scope`: timeouts, first-error cancellation, panic propagation, goleak-verified tests.

## Context

Spec rules: CON-001, CON-002, CON-003, CON-004, CON-010, CON-011. See docs/architecture.md and the role file `.claude/agents/go-backend-engineer.md`.

## Acceptance criteria

- [ ] `go test -race ./...` green with goleak
- [ ] Benchmarks for spawn/join

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


