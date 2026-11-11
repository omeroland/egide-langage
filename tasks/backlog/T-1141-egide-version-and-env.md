---
id: T-1141
title: `egide version [-m]` and `egide env`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0019, T-0081, T-1121]
spec: [PKG-051, LEX-006]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`version` prints compiler version; `-m FILE` prints the SBOM data embedded in an Égide binary (modules, hashes, allow breaches). `env` prints read-only configuration (cache dirs, backend, Go toolchain version) as text or JSON and never prints secrets.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `env` has no write mode
- [ ] Embedded data read without executing the binary

## Out of scope

`env -w`.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
