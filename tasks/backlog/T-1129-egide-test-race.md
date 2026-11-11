---
id: T-1129
title: `egide test --race` for Go-backend programs with Go interop or unsafe
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0081, T-1122, T-1121]
spec: [INT-002, GO-032, MEM-070]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Data races cannot be written in safe Égide (INT-002); they remain possible through `@go_threadsafe` GoRef values and `unsafe`. `--race` builds the tests with the Go backend and Go's race detector, and `egide audit` recommends it when either breach is present.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A conformance program with a deliberate `@go_threadsafe` race is reported
- [ ] The flag is rejected with a clear message on the interpreter
- [ ] Documentation states that safe code needs no -race

## Out of scope

Sanitizers for the native backend.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
