---
id: T-1142
title: `egide clean` and `egide bug`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0019, T-1121]
spec: [TOOL-011]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`clean` removes build, test, fuzz and script caches selectively (`--cache`, `--test`, `--fuzz`, `--scripts`, `--packages`). `bug` prints a bug-report skeleton with versions; no network, no browser.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `clean` never touches files outside Égide cache dirs
- [ ] `bug` output is escaped (LEX-006)

## Out of scope

Module cache removal beyond the lockfile.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
