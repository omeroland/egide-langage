---
id: T-1123
title: `egide test`: fake capabilities and `--integration`
kind: task
phase: 4
role: tooling-engineer
depends_on: [T-1122, T-0070]
spec: [TOOL-031, CAP-060]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/, tests/conformance/toolchain/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Tests receive fake capabilities only; `@integration` functions receive a real `Sys` and run only with `--integration`, and only for the root package (T-1040, third item).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A test that tries to use a real capability without @integration is rejected
- [ ] `--integration` never runs a dependency's @integration functions
- [ ] Negative tests cite TOOL-031

## Out of scope

Selection flags.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
