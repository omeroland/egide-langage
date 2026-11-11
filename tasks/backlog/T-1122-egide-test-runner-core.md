---
id: T-1122
title: `egide test`: @test functions, doctests, @property
kind: task
phase: 2
role: tooling-engineer
depends_on: [T-0019, T-0031, T-0034]
spec: [TOOL-030, SYN-023, LEX-011]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/, tests/conformance/toolchain/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`egide test` discovers `@test` functions (both signatures), `##` doctests and `@property` functions, runs them on the interpreter and reports pass/fail with exit code 1 on failure. No task implemented TOOL-030 before this plan.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A conformance test per signature of @test, one doctest, one property test (derived generator)
- [ ] Failure output goes through the single escaping function (LEX-006)
- [ ] Exit codes 0 / 1 / 2 as in the role rules

## Out of scope

Capabilities in tests (T-1123), filters and JSON (T-1124).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
