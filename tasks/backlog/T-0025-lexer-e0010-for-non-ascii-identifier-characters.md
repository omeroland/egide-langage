---
id: T-0025
title: Lexer: E0010 for non-ASCII identifier characters
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-020]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

A non-ASCII letter adjacent to identifier characters (`café`, Cyrillic `аdmin`) is reported with the catalogue's
dedicated diagnostic E0010 "non-ASCII character in identifier" (LEX-020, docs/diagnostics.md) instead of the generic
E0051 "unexpected character", with one diagnostic per identifier.

## Context

- The seed lexer (and T-0006) splits `café` into `IDENT("caf")` + E0051 at `é`. E0010 is allocated but never emitted.
- Suggested implementation: an extra sedlex rule `(ident_start | xid_start), Star (ident_char | xid_continue)` that
  matches when the ASCII rule does not, reports E0010 at the first non-ASCII code point and returns `IDENT` for
  recovery.
- **Blocker to resolve first:** `tests/security/lexical/homoglyph_identifier.egd` (append-only) pins `E0051 at 6:5`
  for the Cyrillic homoglyph. Switching to E0010 makes it fail. Options: (a) the owner amends that security test
  through an ADR/governance branch to expect E0010; (b) emit E0010 only for non-homoglyph letters (not
  recommended: inconsistent). Ask the orchestrator/owner before starting.

## Acceptance criteria

- [ ] `let café = 1` → one E0010 at the `é`, no E0051
- [ ] Homoglyph identifier → E0010 (after the security test is amended by the owner)
- [ ] Non-letter non-ASCII characters (`€`) still E0051

## Out of scope

Confusable/homoglyph detection in strings or comments (T-0023, Q-0001).

## Log

- 2026-11-09 syntax-engineer/wave1: created from T-0006 (conflict with the append-only security test found there).

## Outcome
