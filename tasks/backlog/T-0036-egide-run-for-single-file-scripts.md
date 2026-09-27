---
id: T-0036
title: `egide run` for single-file scripts
kind: task
phase: 1
role: tooling-engineer
depends_on: [T-0034]
spec: [TOOL-011, TOOL-012, CAP-010, CAP-011]
paths: [compiler/bin/, compiler/lib/driver/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Run a single `.egd` file with shebang support; `main(sys: Sys)` receives a minimal Sys with stdout only (full capabilities arrive in phase 4).

## Context

Spec rules: TOOL-011, TOOL-012, CAP-010, CAP-011. See docs/architecture.md and the role file `.claude/agents/tooling-engineer.md`.

## Acceptance criteria

- [ ] Shebang script test; exit status of `Err` main is 1

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


