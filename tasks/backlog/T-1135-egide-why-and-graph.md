---
id: T-1135
title: `egide why` and `egide graph`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1121]
spec: [PKG-020, PKG-031]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/test/pkg/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Explain why a package is in the build (shortest import path) and print the requirement graph, text and JSON, with `allow` breaches on edges.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Output deterministic (sorted)
- [ ] JSON schema documented

## Out of scope

Graph visualisation.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
