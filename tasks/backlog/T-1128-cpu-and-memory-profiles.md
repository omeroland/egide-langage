---
id: T-1128
title: `--cpuprofile` / `--memprofile` in test and bench
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1127, T-1152]
spec: [TOOL-030]
paths: [compiler/bin/, compiler/lib/driver/, runtime/go/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Write pprof-format profiles from compiled test and bench runs so that the existing pprof viewer is reused; positions map back to .egd through the //line directives of T-1152.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A profile of a benchmark opens in `go tool pprof` and shows .egd file names
- [ ] Profile files are written only to the path given on the command line

## Out of scope

A profile viewer; block, mutex and trace profiles.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
