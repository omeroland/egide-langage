---
id: T-1034
title: Per-file diagnostic cap and run collapsing
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006, T-0002]
spec: [LEX-003, TOOL-040]
paths: [compiler/lib/syntax/source_check.ml, compiler/lib/diagnostics/, compiler/test/syntax/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Bound the number of diagnostics per file (for example 100, then a final note "N more errors suppressed") and collapse consecutive identical forbidden characters or lone CRs into one diagnostic with a count.

## Context

Security review F1 of T-0006: 5 MB of NUL bytes gives 5,000,000 E0004 and about 1.8 GB peak memory; a hostile dependency can exhaust memory in `egide build` or the LSP.

## Acceptance criteria

- [ ] The flood reproducer from the T-0006 review stays under 100 MB and 2 s
- [ ] The cap is a documented constant; the suppressed count is reported once
- [ ] A test with 1M forbidden characters passes

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
