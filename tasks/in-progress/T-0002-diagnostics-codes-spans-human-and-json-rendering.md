---
id: T-0002
title: Diagnostics: codes, spans, human and JSON rendering
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [TOOL-040, TOOL-041, TOOL-042]
paths: [compiler/lib/diagnostics/, compiler/test/diagnostics/]
estimate: M
labels: []
status: in-progress
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:36Z
---

## Goal

A complete diagnostics library: severity, code, rule id, primary and secondary labelled spans, notes, machine-applicable fixes; a human renderer with source excerpts and carets, and the JSON renderer of docs/diagnostics.md.

## Context

Spec rules: TOOL-040, TOOL-041, TOOL-042. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] `Diagnostic.t` has all fields of docs/diagnostics.md JSON format
- [ ] Human rendering snapshot tests for single-line, multi-line and multi-label diagnostics
- [ ] JSON output validated against a JSON schema checked into `docs/diagnostics.schema.json`
- [ ] Columns count Unicode scalar values (test with é and emoji in strings)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


