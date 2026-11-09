---
id: T-0026
title: Conformance tests with invalid UTF-8 and NUL bytes
kind: task
phase: 0
role: test-engineer
depends_on: [T-0006, T-0014]
spec: [LEX-001, LEX-003]
paths: [tests/conformance/lexical/, tools/run-conformance.sh, tools/conformance/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Black-box conformance tests for invalid UTF-8 (E0001) and the NUL character (E0004), which T-0006 could only cover
with unit tests because the seed runner cannot read such files.

## Context

- GNU grep ≥ 3.5 treats a file containing NUL or invalid UTF-8 as binary (in both `C` and `C.UTF-8` locales): it
  prints "binary file matches" on stderr instead of the header lines, so `tools/run-conformance.sh` reports
  "missing '# spec:' header". The runner must read headers in a binary-safe way (`grep -a`, or the T-0014 runner).
- Cases to add: lone continuation byte, overlong form, surrogate, value above U+10FFFF, truncated sequence at end of
  file, NUL in a comment, in a string and in code. Expected positions are in
  `compiler/test/syntax/lexer_hardening/test_lexer_hardening.ml` (one E0001 per run of ill-formed bytes; each
  maximal ill-formed subpart counts as one column).
- Store the files with `-text` in `tests/conformance/lexical/.gitattributes`.

## Acceptance criteria

- [ ] The runner reads headers of files containing NUL and invalid UTF-8
- [ ] At least the cases above are conformance tests and pass

## Out of scope

Changing lexer behaviour.

## Log

- 2026-11-09 syntax-engineer/wave1: created from T-0006.

## Outcome
