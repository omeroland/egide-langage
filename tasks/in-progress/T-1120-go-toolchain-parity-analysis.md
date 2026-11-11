---
id: T-1120
title: Go toolchain parity: gap analysis and task plan
kind: task
phase: 6
role: tooling-engineer
depends_on: []
spec: [TOOL-010, TOOL-020, TOOL-030, TOOL-031, TOOL-040, TOOL-042, TOOL-050, PKG-041, PKG-050, PKG-051, PKG-052, PKG-070]
paths: [docs/toolchain-parity.md, docs/adr/0019-toolchain-parity.md, tasks/]
estimate: M
labels: [docs, planning]
status: in-progress
claimed_by: tooling-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

Owner request: "the set of tools to add is the set of tools of the Go language". Interpretation retained: the `egide`
toolchain offers at least functional parity with the standard Go toolchain, so that Go developers are not lost. This
task is an analysis and a plan only: no compiler code. Deliverables: `docs/toolchain-parity.md` (exact inventory,
mapping, counts), backlog tasks T-1121..T-11xx, a Proposed ADR (ADR-0019) for the spec/13 amendments, spec-questions.

## Context

spec/13, spec/10, docs/roadmap.md (phase 6), docs/architecture.md, ADR-0008, ADR-0009, T-0019, T-0090..T-0092.

## Acceptance criteria

- [ ] Inventory taken from `go help`, `go tool`, `go help <cmd>` of the locally installed Go (version recorded)
- [ ] Every entry has: Égide equivalent, spec state, phase, role, dependencies, disposition, evidence level
- [ ] Counts (inventoried / covered / partial / absent / excluded) generated from the table, not typed by hand
- [ ] Backlog tasks in T-1120..T-1159, phase <= 6, no duplicate of existing tasks
- [ ] spec/ and docs/roadmap.md untouched; amendments proposed in ADR-0019 (Proposed) and spec-questions
- [ ] `make ci` green

## Out of scope

Any compiler or tooling code; editing spec/ or the roadmap.

## Log

## Outcome
