---
id: T-1154
title: `egide fmt`: --diff, stdin, error reporting
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-0090, T-1121]
spec: [TOOL-020]
paths: [compiler/lib/fmt/, compiler/bin/, compiler/test/fmt/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

gofmt `-d` and stdin usage (editors, hooks); formatting options stay forbidden. Properties: `fmt (fmt x) = fmt x`, `parse (fmt x) = parse x`.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] `--diff` prints a unified diff and exits 1 when unformatted
- [ ] Stdin to stdout with `-`

## Out of scope

Style options (TOOL-020).

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
