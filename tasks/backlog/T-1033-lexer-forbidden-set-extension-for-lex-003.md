---
id: T-1033
title: Lexer forbidden-set extension for LEX-003
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-003, LEX-050]
paths: [compiler/lib/syntax/source_check.ml, compiler/lib/syntax/source_check.mli, compiler/lib/syntax/lexer.ml, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Extend `Source_check.is_forbidden` to the LEX-003 set of ADR-0016: all of category Cf (Unicode 16.0), variation selectors, U+034F, Hangul fillers; allow any scalar value in `\u{…}`.

## Context

Decided in ADR-0016 (Q-0001, security review F2 of T-0006). tests/security/ is append-only: existing cases stay. Names for E0004 messages: use the Unicode names; for `Cf` without a table entry use the generic category name.

## Acceptance criteria

- [ ] Every code point listed in LEX-003 items 1-3 is rejected in comments, strings and code (E0004), with a table-driven test
- [ ] Neighbours of each range (U+00AC, U+00AE, U+2065, U+FE10, U+E01F0 ...) are accepted
- [ ] `"\u{200D}"`, `"\u{E0041}"` are accepted by the lexer (LEX-050); surrogates and values above 10FFFF are E0041
- [ ] Conformance tests cite LEX-003; a generated Cf list check against the Unicode data file used by the build

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
