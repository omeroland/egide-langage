---
id: T-1039
title: One output-escaping function for every tool output (LEX-006)
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-0002]
spec: [LEX-006, LEX-003, SYN-018]
paths: [compiler/lib/diagnostics/, compiler/bin/, compiler/test/diagnostics/]
estimate: S
labels: [security]
status: in-progress
claimed_by: tooling-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

Add the single escaping function of LEX-006 and route diagnostics (human and JSON) through it; audit, SBOM, lock and LSP tasks must call it.

## Context

ADR-0017, review S1. Escape: the LEX-003 set, Zs except U+0020, bidi controls, DEL, backslash and line breaks, as `\\u{H}`; JSON uses `\\uXXXX` so that no raw code point of the set appears in output bytes.

## Acceptance criteria

- [ ] `Escape.display : string -> string` and `Escape.json_safe`, with a test printing every class (ESC, CSI U+009B, NEL, ZWSP, RLO, TAG, DEL, NBSP, backslash)
- [ ] Diagnostics excerpts and messages that echo string values use it
- [ ] A lint test fails if a diagnostic renderer prints a source string without it

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
