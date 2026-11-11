---
id: T-1124
title: `egide test`: selection flags, JSON events, sound result cache
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1122, T-1121]
spec: [TOOL-030, TOOL-031, TOOL-042, LEX-006]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/, tests/conformance/toolchain/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Parity with `go test -run -skip -list -shuffle -count -short -timeout -failfast -parallel -json` and with the Go test cache, in Égide spelling. The cache is sound because non-@integration tests hold fake capabilities only: key = hash of the HIR of the package and its dependencies plus the seed.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `--filter`, `--skip`, `--list`, `--shuffle SEED`, `--count N`, `--timeout`, `--failfast`, `--json` documented in `--help`
- [ ] JSON event schema in docs/ with a JSON-schema file, every string escaped by the LEX-006 function
- [ ] A cached run is byte-identical to a fresh run; @integration tests are never cached
- [ ] Shuffle with the same seed gives the same order

## Out of scope

Coverage, bench, fuzz, race.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
