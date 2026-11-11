---
id: T-1140
title: `egide install PKG@VERSION`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-0081, T-1121]
spec: [PKG-041, PKG-042, PKG-050]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/lib/driver/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Builds and installs the binary of a published package into a bin directory chosen by `EGIDE_BIN` or a default. A version is always resolved to an exact one and recorded with signer identity; install runs no code of the package (PKG-042).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Unsigned or mismatched package refused
- [ ] Install record lists the Sigstore identity
- [ ] `@latest` prints the exact version it resolved

## Out of scope

Uninstall (follow-up if wanted).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
