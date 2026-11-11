---
id: T-1125
title: `egide test --cover` and `egide cover` reports
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1122, T-1121]
spec: [TOOL-030]
paths: [compiler/bin/, compiler/lib/driver/, compiler/lib/comptime/, compiler/test/driver/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Statement/branch coverage collected by the bytecode interpreter; reports as text summary, lcov and static HTML (all output escaped, T-1040).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `egide test --cover` prints per-package percentages
- [ ] `egide cover --html -o DIR` writes a self-contained report with escaped source text
- [ ] Coverage of a package with one untested branch is below 100 % in a conformance test

## Out of scope

Coverage of compiled binaries (T-1126).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
