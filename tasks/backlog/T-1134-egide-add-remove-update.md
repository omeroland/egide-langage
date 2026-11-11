---
id: T-1134
title: `egide add`, `egide remove`, `egide update`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0092, T-1121]
spec: [PKG-011, PKG-020, PKG-030, PKG-031, PKG-040]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/test/pkg/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Replaces `go get` and `go mod edit` for humans and agents. `add` edits the manifest, resolves with MVS, verifies, updates the lockfile and prints new `allow` breaches that the update introduced (they fail the build until accepted, PKG-030).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `update` never silently adds an allow entry
- [ ] Manifest comments and ordering are preserved
- [ ] Every download verified (PKG-041)

## Out of scope

Registry protocol (T-1151).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
