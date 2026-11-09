---
id: T-1000
title: CLI: human diagnostics with source excerpts
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-0002, T-0019]
spec: [TOOL-040]
paths: [compiler/bin/, compiler/lib/driver/, tests/conformance/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

`egide lex|parse|check` print human diagnostics with source excerpts, carets and labels by calling
`Diagnostic.render_human ~sources` (added by T-0002) instead of the one-line `Diagnostic.to_human`.

## Context

Follow-up of T-0002. `render_human ~sources` takes a function from file name to contents; the driver already
has the source text in memory. The first line of each diagnostic is unchanged
(`file:line:col: error[CODE]: message (RULE)`), which is what `tools/run-conformance.sh` matches.

## Acceptance criteria

- [ ] Human output of `egide parse` shows the excerpt for a diagnostic (snapshot or conformance test)
- [ ] `tools/run-conformance.sh` still passes (header line unchanged)
- [ ] `--error-format=json` unchanged

## Out of scope

Colour output (separate task if wanted).

## Log

- 2026-11-09 syntax-engineer/wave1: created from T-0002 (CLI is outside T-0002's paths).

## Outcome
