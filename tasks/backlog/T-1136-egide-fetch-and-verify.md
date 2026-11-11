---
id: T-1136
title: `egide fetch` and `egide verify`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1121]
spec: [PKG-040, PKG-041, PKG-052]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/test/pkg/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`fetch` fills the cache from the lockfile (the only command besides add/update/install that uses the network); `verify` re-checks every cached archive against the lockfile hashes and Sigstore bundles. No flag skips a check.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Tampered cache entry is a fatal error with exit code 1
- [ ] `egide build` after `fetch` makes no network access (tested with network denied)

## Out of scope

Artifact rebuild (T-1137).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
