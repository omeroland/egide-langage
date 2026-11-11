---
id: T-1143
title: `egide doc`: terminal and static HTML
kind: task
phase: 6
role: tooling-engineer
depends_on: [T-1036, T-0030, T-1039, T-1040, T-1121]
spec: [LEX-011, LEX-006, TOOL-030]
paths: [compiler/bin/, compiler/lib/driver/, compiler/test/driver/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`egide doc [PKG[.SYMBOL]]` prints signatures and `##` comments; `--html -o DIR` writes static pages. HTML is escaped by default (T-1040). No server is part of the toolchain.

## Context

Created by T-1120 (docs/toolchain-parity.md, ADR-0019). Spec: chapters 10 and 13; role file `.claude/agents/tooling-engineer.md`.
Spec rules that do not exist yet are proposed in ADR-0019 and added to the spec by T-1121.

## Acceptance criteria

- [ ] Raw HTML in a doc comment is escaped
- [ ] Doctests shown with their expected output

## Out of scope

A documentation server; registry-hosted docs.

## Log

- 2026-11-10 tooling-engineer: created by T-1120.

## Outcome
