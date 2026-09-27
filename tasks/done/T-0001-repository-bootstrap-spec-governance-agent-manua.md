---
id: T-0001
title: Repository bootstrap: spec, governance, agent manual, compiler seed
kind: task
phase: 0
role: release-manager
depends_on: []
spec: []
paths: [.]
estimate: L
labels: []
status: done
claimed_by: bootstrap
claimed_at: 2026-09-26
---

## Goal

The repository exists with the v0.2 specification, ADRs, agent operating manual, task board, CI, and a compiling OCaml seed (source spans, diagnostics, raw lexer, layout pass, minimal parser, `egide lex|parse`).

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/release-manager.md`.

## Acceptance criteria

- [x] `make build` and `dune test` pass
- [x] CI workflow defined
- [x] Task backlog for phases 0–1 written

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome

Seeded by the project owner's bootstrap session (2026-09-26). The seed lexer covers identifiers, keywords, integer literals, simple strings, operators, comments and the LEX-032 layout algorithm; the seed parser only accepts `module`, `import` and top-level `let` with literal or identifier values. Everything else is in T-0002 onwards.
