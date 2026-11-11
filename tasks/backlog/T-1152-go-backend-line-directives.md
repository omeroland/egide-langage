---
id: T-1152
title: Go backend emits //line directives and debug mapping
kind: task
phase: 6
role: go-backend-engineer
depends_on: [T-0081]
spec: [INT-020]
paths: [compiler/lib/backend_go/, compiler/test/backend_go/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Generated Go carries `//line file.egd:N` directives so that panics, debuggers, pprof, nm and objdump show Égide positions. Deterministic (PKG-050) and path-normalised.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/go-backend-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A panic in a conformance program reports the .egd line
- [ ] Output identical across two build directories

## Out of scope

A debug adapter.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
