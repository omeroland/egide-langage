---
id: T-0009
title: Parser: declarations
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008, T-0007]
spec: [SYN-001, SYN-002, SYN-003, SYN-020, SYN-021, SYN-022, SYN-023]
paths: [compiler/lib/syntax/parser.mly, compiler/test/syntax/, tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Menhir rules for module, import (all forms incl. `import go`), fn signatures with modes, generics and `using`, struct, enum, trait, impl, type (alias/new/where), const, attributes.

## Context

Spec rules: SYN-001, SYN-002, SYN-003, SYN-020, SYN-021, SYN-022, SYN-023. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every declaration production has a parse-pass test; malformed forms have parse-fail tests
- [ ] `menhir --explain` reports 0 conflicts

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


