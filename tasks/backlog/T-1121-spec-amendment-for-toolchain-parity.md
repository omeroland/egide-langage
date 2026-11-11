---
id: T-1121
title: Spec 13 and 10 amendment for toolchain parity (ADR-0019)
kind: task
phase: 6
role: language-architect
depends_on: []
spec: [TOOL-010, TOOL-020, PKG-052, PKG-070]
paths: [spec/13-toolchain.md, spec/10-modules-and-packages.md, docs/roadmap.md, docs/adr/]
estimate: M
labels: [governance]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Turn ADR-0019 (Proposed) into spec text once the owner accepts it: new commands and flags in the table of chapter 13, the rules that govern them, and the roadmap lines for `egide test`, `egide audit` and the new commands. Owner merges (protected paths).

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/language-architect.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] ADR-0019 Accepted by the owner
- [ ] Chapter 13 table lists every command of docs/toolchain-parity.md marked Provide/Exceed, with new rule ids
- [ ] `./tools/check-spec.sh` passes
- [ ] Tasks that depend on this one cite the new rule ids in their `spec` field

## Out of scope

Implementation of any command.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
