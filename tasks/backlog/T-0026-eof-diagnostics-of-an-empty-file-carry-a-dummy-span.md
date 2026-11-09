---
id: T-0026
title: EOF diagnostics of an empty file carry a dummy span
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0002, T-0007]
spec: [TOOL-040, TOOL-042]
paths: [compiler/lib/syntax/, compiler/test/syntax/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Every diagnostic produced on an empty (or comment-only) file has a real primary span in that file.

## Context

Found in T-0002. On `main` at a8ab071, `egide --error-format=json parse empty.egd` prints
`"span":{"file":"","start":{"line":0,"col":0},"end":{"line":0,"col":0}}`: the EOF token of an empty file gets
`Lexing.dummy_pos` (`layout.ml`, end position of the last token when there is none) and `parse.ml` falls back to
`Span.dummy`. This violates TOOL-040 (a primary source span) and `docs/diagnostics.schema.json` (line and col ≥ 1,
real file name).

## Acceptance criteria

- [ ] An empty file and a comment-only file report their diagnostic at `FILE:1:1` (unit test, cites TOOL-040)
- [ ] No `Span.dummy` / `Lexing.dummy_pos` reaches a diagnostic from the lexer, layout or parser

## Out of scope

Parser error messages (T-0013).

## Log

- 2026-11-09 syntax-engineer/wave1: created from T-0002.

## Outcome
