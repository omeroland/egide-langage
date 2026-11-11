---
id: T-1149
title: LSP: manifest, breach and vulnerability diagnostics, test code lenses
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0091, T-1131, T-1122]
spec: [TOOL-050, TOOL-041, PKG-030]
paths: [compiler/lib/lsp/, compiler/test/lsp/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Diagnostics for `egide.toml` (missing allow entry, unknown key), inline display of `unsafe`/Go-impure sites and of vulnerabilities, run-test code lenses. All text escaped (LEX-006).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Manifest error shows at the offending key
- [ ] Code lens runs one test through `egide test --filter`

## Out of scope

Remote features.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
