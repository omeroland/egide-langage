---
id: T-1132
title: `egide audit`: known vulnerabilities with reachability
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1131, T-0083, T-1121]
spec: [GO-042, GO-043, PKG-040, PKG-041]
paths: [compiler/bin/, compiler/lib/pkg/, compiler/lib/goint/, compiler/test/pkg/]
estimate: L
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Matches the lockfile against a vulnerability database in OSV format, with a signed offline snapshot (same trust rules as packages: hash and Sigstore bundle verified, no bypass). For Go modules, reports only findings whose vulnerable symbols are reachable in the call graph of T-0083 (the idea of govulncheck). Epic-sized: split before claiming.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Database snapshot verified before use; unsigned snapshot is a fatal error
- [ ] A vulnerable but unreachable Go symbol is reported as 'present, not reachable'
- [ ] No network access when the snapshot is in the cache

## Out of scope

Operating the database: Q-0041 and open question 4 of docs/toolchain-parity.md.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
