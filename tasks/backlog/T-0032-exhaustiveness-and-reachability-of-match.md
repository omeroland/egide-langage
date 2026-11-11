---
id: T-0032
title: Exhaustiveness and reachability of match
kind: task
phase: 1
role: type-system-engineer
depends_on: [T-0031]
spec: [TYP-060, TYP-061, TYP-062, SYN-051, SYN-052]
paths: [compiler/lib/types/, tests/conformance/types/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Maranget usefulness algorithm; missing-pattern diagnostics show an example value.

## Context

Spec rules: TYP-060, TYP-061, TYP-062, SYN-051, SYN-052. See docs/architecture.md and the role file `.claude/agents/type-system-engineer.md`.

## Acceptance criteria

- [ ] Nested enums, tuples, literals, ranges, guards (guards never count as exhaustive) tested

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 syntax-engineer (T-1030 review): E0121 (SYN-053, ADR-0017: unused lowercase binding equal to a variant or constant of the scrutinee type ignoring case) is reported here, not by the parser; T-1031's list had it by mistake.

## Outcome


