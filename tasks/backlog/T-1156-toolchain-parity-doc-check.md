---
id: T-1156
title: CI check that the parity table matches the task board
kind: task
phase: 6
role: release-manager
depends_on: [T-1121]
spec: []
paths: [tools/, Makefile]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Script that fails when docs/toolchain-parity.md cites a task id that does not exist, or a `Provide` entry has no task; run by `make lint`.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/release-manager.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Check wired into `make ci`
- [ ] Negative test with a fixture

## Out of scope

Editing the parity document.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
