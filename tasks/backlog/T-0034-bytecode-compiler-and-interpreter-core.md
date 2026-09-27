---
id: T-0034
title: Bytecode compiler and interpreter core
kind: task
phase: 1
role: comptime-engineer
depends_on: [T-0033]
spec: [CT-005, TOOL-010, MEM-001]
paths: [compiler/lib/comptime/, compiler/test/comptime/, tests/conformance/run/]
estimate: L
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Compile HIR to bytecode and run it: integers with overflow checks, bools, strings, functions, closures, structs, enums, match, loops, value semantics for lists.

## Context

Spec rules: CT-005, TOOL-010, MEM-001. See docs/architecture.md and the role file `.claude/agents/comptime-engineer.md`.

## Acceptance criteria

- [ ] run-pass tests execute through `egide run`
- [ ] Overflow panics (TYP-010) tested
- [ ] Value semantics (MEM-001) tested with list copies

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


