---
id: T-1110
title: Audit, SBOM, lockfile, LSP, test and panic output call Escape (LEX-006)
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-1039]
spec: [LEX-006, SYN-018]
paths: [compiler/bin/, compiler/lib/diagnostics/, compiler/test/diagnostics/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

When each tool that prints source text or string values is implemented (`egide audit`, SBOM/CycloneDX, lockfile writer, LSP messages and hover, test and panic output), it must use `Egide_diagnostics.Escape` (`display`, `json_safe`) and write through `Output`. Extend the lint test of T-1039 to cover each new renderer as it lands.

## Context

T-1039 (ADR-0017 S1) adds `Escape`, `Output`, `Forbidden_set` and a lint on `compiler/bin/main.ml` and `diagnostic.ml`. The lint is a source scan; new renderers in other directories (`compiler/lib/pkg/`, `compiler/lib/lsp/`) are not covered until they are added to it. Also pending: `Print.quote` in the AST printer should render the LEX-003 set as `\u{H}` (syntax-engineer, after T-1033).

## Acceptance criteria

- [ ] The lint test lists every renderer source file and fails on raw print primitives or a missing `Escape.` use
- [ ] Each new tool has a test printing a value with `\u{1B}[2K`, RLO and ZWSP, for its human and machine formats

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
