---
id: T-0040
title: Go purity list: complete go1.25.lst
kind: task
phase: 5
role: go-interop-engineer
depends_on: [T-0082]
spec: [GO-041, GOP-001, GOP-002, GOP-003, GOP-004]
paths: [spec/appendix/go-purity/go1.25.lst]
estimate: L
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Generate the full per-function classification of the Go 1.25 standard library with the call-graph tool, then review every non-pure entry by hand.

## Context

Spec rules: GO-041, GOP-001, GOP-002, GOP-003, GOP-004. See docs/architecture.md and the role file `.claude/agents/go-interop-engineer.md`.

## Acceptance criteria

- [ ] Every exported function of the Go 1.25 std is matched by a line
- [ ] security-reviewer approval; merged by the owner (protected path)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


