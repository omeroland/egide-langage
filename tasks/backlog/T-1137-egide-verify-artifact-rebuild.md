---
id: T-1137
title: `egide verify --artifact`: rebuild and compare
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1136, T-0081]
spec: [PKG-050, PKG-051]
paths: [compiler/bin/, compiler/lib/driver/, compiler/lib/pkg/, tools/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Rebuilds an artefact from sources, lockfile and compiler version in a different directory and compares hashes; same check CI runs twice (roadmap phase 6 exit). Exceeds Go, whose toolchain has no built-in reproducibility check.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Two builds in different directories compare equal on `examples/`
- [ ] A deliberately non-deterministic input (timestamp) is detected

## Out of scope

Signing artefacts.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
