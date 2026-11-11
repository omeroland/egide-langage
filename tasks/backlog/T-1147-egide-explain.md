---
id: T-1147
title: `egide explain E0123`
kind: task
phase: 1
role: tooling-engineer
depends_on: [T-0019]
spec: [TOOL-040]
paths: [compiler/bin/, compiler/lib/driver/, docs/diagnostics.md]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Long explanations for every allocated code of docs/diagnostics.md; unknown code is exit 1; text is static and embedded in the binary.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Every allocated code has an explanation (checked by a test)
- [ ] Output passes the escaping function

## Out of scope

Authoring explanations (docs-writer).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
