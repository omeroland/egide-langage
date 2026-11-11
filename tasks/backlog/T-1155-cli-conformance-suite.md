---
id: T-1155
title: CLI conformance: help, exit codes, JSON flags
kind: task
phase: 6
role: test-engineer
depends_on: [T-0019, T-1121]
spec: [TOOL-040, TOOL-042]
paths: [tests/conformance/toolchain/, tools/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Black-box tests of every subcommand: `--help` exists, exit codes 0/1/2/70/101, `--error-format=json` accepted wherever diagnostics are emitted, unimplemented commands exit 2.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/test-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] One test per subcommand of spec chapter 13
- [ ] A new command without a test fails CI

## Out of scope

Behaviour tests of each command (owned by its task).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
