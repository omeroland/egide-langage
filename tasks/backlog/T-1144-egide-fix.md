---
id: T-1144
title: `egide fix`: suggested fixes, edition migration, modernisation
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0090, T-1121]
spec: [TOOL-040, PKG-070]
paths: [compiler/bin/, compiler/lib/driver/, compiler/lib/fmt/, compiler/test/driver/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Applies machine-applicable edits of diagnostics (TOOL-040), `--edition` migrations (PKG-070) and deprecation rewrites, then formats. Atomic: all edits or none; never applies an edit that changes a capability signature.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `fix` is idempotent (second run changes nothing)
- [ ] Edit that would overlap another is refused, not merged

## Out of scope

Third-party analyzers.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
