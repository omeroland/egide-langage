---
id: T-1148
title: LSP: symbols, implementation, call hierarchy, signature help, semantic tokens
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0091]
spec: [TOOL-050]
paths: [compiler/lib/lsp/, compiler/test/lsp/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Features of gopls that TOOL-050 does not list: document and workspace symbols, go to implementation and type definition, call hierarchy, signature help, folding, document highlight, semantic tokens. The gopls feature list is emerging knowledge (not verified here); check against its documentation first.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Each feature has a protocol-level test
- [ ] Incremental re-check stays under 200 ms on the 50 k-line corpus

## Out of scope

Security-aware features (T-1149).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
