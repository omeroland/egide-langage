---
id: T-1151
title: `egide publish` and `egide yank`
kind: epic
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1121]
spec: [PKG-040, PKG-060, PKG-061]
paths: [(to be defined when split)]
estimate: L
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Go has no publish command (the proxy reads version-control tags); Égide's registry (PKG-060) needs one: deterministic source archive, Sigstore keyless signing, upload, yank. Needs a registry design and an owner for the registry service, see open question 4.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Registry protocol written (ADR)
- [ ] Split into S/M tasks

## Out of scope

Running the registry.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
