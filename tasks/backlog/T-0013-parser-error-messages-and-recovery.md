---
id: T-0013
title: Parser: error messages and recovery
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0012, T-0002]
spec: [SYN-001]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Menhir `.messages` file with human messages for every error state reachable by the test corpus; recovery at the next same-indentation NEWLINE or DEDENT.

## Context

Spec rules: SYN-001. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] `menhir --compare-errors` passes in CI (dune rule)
- [ ] A file with 3 independent syntax errors reports exactly 3 diagnostics

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


