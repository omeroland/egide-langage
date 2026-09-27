---
id: T-0016
title: Conformance tests for chapter 2 (lexical)
kind: task
phase: 0
role: test-engineer
depends_on: [T-0014]
spec: [LEX-001, LEX-002, LEX-003, LEX-004, LEX-010, LEX-011, LEX-012, LEX-020, LEX-021, LEX-022, LEX-030, LEX-031, LEX-032, LEX-033, LEX-034, LEX-035, LEX-040, LEX-041, LEX-042, LEX-050, LEX-051, LEX-052, LEX-053, LEX-054, LEX-055, LEX-060, LEX-061]
paths: [tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

At least one positive and one negative test for every LEX rule, written from the spec (independently of the implementation).

## Context

Spec rules: LEX-001, LEX-002, LEX-003, LEX-004, LEX-010, LEX-011, LEX-012, LEX-020, LEX-021, LEX-022, LEX-030, LEX-031, LEX-032, LEX-033, LEX-034, LEX-035, LEX-040, LEX-041, LEX-042, LEX-050, LEX-051, LEX-052, LEX-053, LEX-054, LEX-055, LEX-060, LEX-061. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [ ] `tools/check-spec.sh --coverage` shows no uncovered LEX rule

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


