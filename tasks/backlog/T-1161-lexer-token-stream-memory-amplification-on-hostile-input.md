---
id: T-1161
title: Lexer — token stream memory amplification on hostile input (about 120 bytes per source byte)
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1080]
spec: [LEX-001]
paths: [compiler/lib/syntax/, compiler/test/syntax/]
estimate: S
labels: [security, perf]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Quantify and, if warranted, bound the memory used by the token list itself, which is independent of diagnostics.

## Context

Found while measuring T-1080: `module m` then `a\t` x 2,000,000 (4 MB, tabs outside a comment) now yields 101
diagnostics but `egide lex` still takes 4.4 s and 480 MB peak RSS, because 4,000,000 tokens are materialised as
`located` records with two `Lexing.position` values each and then printed (41 MB of stdout). Before T-1080 the same
file took 18 s and 1.0 GB (*established*, measured). The amplification is linear in the input (no quadratic
behaviour was observed), so this is a resource-limit question rather than a flood of diagnostics.

Options to weigh: a compact token representation (positions as ints), a streaming lexer interface for `layout` and
the parser, or a documented maximum source size per file (spec question: there is no such limit in spec/02 today;
file it as a `spec-question` rather than guessing).

## Acceptance criteria

- [ ] A written measurement (bytes of heap per source byte, per token kind) and a decision recorded in the Log.
- [ ] If a representation change is chosen: peak RSS below 100 MB on the reproducer, token output unchanged.

## Log

## Outcome
