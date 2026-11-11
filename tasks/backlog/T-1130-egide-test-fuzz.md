---
id: T-1130
title: Coverage-guided `egide test --fuzz`
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1125, T-1122, T-1121]
spec: [TOOL-030]
paths: [compiler/bin/, compiler/lib/driver/, compiler/lib/comptime/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`@property` generators (derive Arbitrary) driven by coverage feedback from T-1125; failing inputs are minimised and stored in a corpus directory inside the package, replayed by plain `egide test`. Relevant to parsers of `Untrusted` input.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] A seeded bug in a parser example is found within a fixed budget in CI
- [ ] Corpus entries replay deterministically
- [ ] Q-0044 decided (attribute `@fuzz` or reuse of `@property`)

## Out of scope

Fuzzing the compiler itself (T-0018).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
