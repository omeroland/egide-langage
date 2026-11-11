---
id: T-1126
title: Coverage of compiled binaries and `egide cover merge`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1125, T-0081]
spec: [TOOL-030, PKG-050]
paths: [compiler/bin/, compiler/lib/driver/, runtime/go/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Equivalent of `go build -cover` plus `go tool covdata`: a binary built with `--cover` writes counter files to a directory chosen by an explicit argument; `egide cover merge` combines them. Runtime writes only where the program was given a capability.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Integration-test run of a built binary produces a mergeable profile
- [ ] The coverage runtime performs no file access unless `--cover-dir` was passed at build time
- [ ] Reproducibility: a build without `--cover` is unchanged (PKG-050)

## Out of scope

Native backend instrumentation.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
