---
id: T-0030
title: Name resolution and module graph
kind: task
phase: 1
role: type-system-engineer
depends_on: [T-0021]
spec: [SYN-001, SYN-002, SYN-003, SYN-004, PKG-001, PKG-002, PKG-003]
paths: [compiler/lib/resolve/, compiler/test/resolve/, tests/conformance/names/]
estimate: L
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Resolve every identifier to its declaration across modules of a package; detect import cycles and unknown/ambiguous names.

## Context

Spec rules: SYN-001, SYN-002, SYN-003, SYN-004, PKG-001, PKG-002, PKG-003. See docs/architecture.md and the role file `.claude/agents/type-system-engineer.md`.

## Acceptance criteria

- [ ] Import cycle diagnostic lists the cycle
- [ ] Visibility (pub, pub(package)) enforced
- [ ] Shadowing rules documented in the Log and raised as spec-question if unspecified

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


