---
id: T-1160
title: Layout and parser — bound the number of diagnostics per file (E0020/E0021/E0022/E0023 flood)
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1080]
spec: [LEX-032, LEX-033, TOOL-040]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/, docs/diagnostics.md]
estimate: S
labels: [security, perf]
status: backlog
claimed_by:
claimed_at:
---

## Goal

T-1080 bounds the diagnostics of the raw-text checks and of the lexer (shared `Diagnostic.Sink` with a limit, E0006
summary). The layout pass is not covered: `Parse.tokens` appends `Layout.run`'s list to the lexer's, unbounded.

## Context

Measured on the T-1080 head with `egide lex`: `module m` followed by 500,000 times `x\n  y\n` gives 500,000 E0020 in
6.2 s and about 400 MB peak RSS (*established*, reproduced). Packages are compiled from untrusted dependencies, so
this is the same denial-of-service vector as T-1080.

Design: make `Layout.run` report into a bounded sink that continues the lexer's budget (the file has one limit, not
one per pass), so that the E0006 summary stays the single last diagnostic of the file and its count includes the
layout diagnostics. `Parse.tokens` must not append anything after the summary. The same applies to the parser's
syntax errors once error recovery (several E0100 per file) exists.

## Acceptance criteria

- [ ] The reproducer above ends with exactly 100 kept diagnostics plus one E0006, in under 1 s and 100 MB.
- [ ] The file still fails. Existing tests unchanged.
- [ ] Unit test with 500,000 E0020/E0021 asserting a bounded count and an unchanged first diagnostic.

## Log

## Outcome
