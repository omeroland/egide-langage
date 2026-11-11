---
id: T-1127
title: `egide bench`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0081, T-1122, T-1121]
spec: [TOOL-030]
paths: [compiler/bin/, compiler/lib/driver/, bench/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Benchmarks (`@bench`, subject to Q-0044) are built with the Go backend and run compiled; reports ns/op and allocations; compares against a stored baseline with the 5 % regression rule of docs/testing.md.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `egide bench` refuses to run on the interpreter (numbers would be meaningless)
- [ ] Baseline comparison exits 1 above the threshold
- [ ] Q-0044 decided

## Out of scope

Profiles (T-1128).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
