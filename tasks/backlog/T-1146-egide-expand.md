---
id: T-1146
title: `egide expand`
kind: task
phase: 2
role: comptime-engineer
depends_on: [T-0019, T-0054]
spec: [CT-060, CT-030, CT-040]
paths: [compiler/bin/, compiler/lib/comptime/, compiler/test/comptime/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Prints the code produced by derivations and templates (replacement of `go generate` output files). No task implemented CT-060 before this plan.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/comptime-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Output is valid Égide and re-parses
- [ ] Output is deterministic

## Out of scope

Writing the expansion to disk.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
