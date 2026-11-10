---
id: T-0017
title: Conformance tests for chapter 3 (syntax)
kind: task
phase: 0
role: test-engineer
depends_on: [T-0014]
spec: [SYN-001, SYN-002, SYN-003, SYN-010, SYN-012, SYN-020, SYN-030, SYN-031, SYN-036, SYN-038, SYN-039, SYN-050, SYN-060, SYN-062, SYN-100, SYN-101]
paths: [tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Parse-pass/parse-fail tests for every EBNF production and every SYN rule checkable at parse time.

## Context

Spec rules: SYN-001, SYN-002, SYN-003, SYN-010, SYN-012, SYN-020, SYN-030, SYN-031, SYN-036, SYN-038, SYN-039, SYN-050, SYN-060, SYN-062, SYN-100, SYN-101. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [ ] Every production of spec/grammar/egide.ebnf is exercised (a checklist in the Log)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0021: spec blocks are tagged; see T-0015. New syntax rules to cover: SYN-005, 015, 016, 017, 024, 042, 043, 044, 053, 065 and the checks of T-1031.

## Outcome


