---
id: T-0031
title: Type checker core: primitives, functions, structs, enums
kind: task
phase: 1
role: type-system-engineer
depends_on: [T-0030]
spec: [TYP-001, TYP-002, TYP-003, TYP-004, TYP-005, TYP-010, TYP-020, TYP-021, TYP-022, TYP-070, TYP-071, TYP-072, SYN-013, SYN-014, SYN-031, SYN-032]
paths: [compiler/lib/types/, compiler/test/types/, tests/conformance/types/]
estimate: L
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Bidirectional checking of the non-generic core language.

## Context

Spec rules: TYP-001, TYP-002, TYP-003, TYP-004, TYP-005, TYP-010, TYP-020, TYP-021, TYP-022, TYP-070, TYP-071, TYP-072, SYN-013, SYN-014, SYN-031, SYN-032. See docs/architecture.md and the role file `.claude/agents/type-system-engineer.md`.

## Acceptance criteria

- [ ] Error type prevents cascades (a test with one error yields one diagnostic)
- [ ] 150 conformance tests across the listed rules

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


