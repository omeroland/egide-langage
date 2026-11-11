---
id: T-1112
title: Bound the memory and time of the `lex` output path on large non-ASCII literals
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1039]
spec: [LEX-006]
paths: [compiler/lib/diagnostics/, compiler/bin/, compiler/test/diagnostics/]
estimate: S
labels: [security, perf]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`egide lex` on a source with one very large literal uses memory and time linear in the literal with a small constant.

## Context

Security review of T-0004 (PR #26), F1: a string literal of 4,000,000 `é` makes `egide lex` use 2.9 GB RSS for 11 s, a
triple-quoted literal of 8,000,000 empty lines 1.9 GB, about 100 times the cost of the same bytes in a comment.
Measured by the syntax-engineer on the T-0004 head and on main (2d8d9ff): the same 11.4 s / 11.2 s, so it is not a
regression of T-0004. The tokenizer alone lexes that string in 0.3 s (and 8 M empty lines of a triple-quoted literal in 1.0 s, 372 MB, after T-0004 stores them compactly), so the lexer is not the cause: `egide parse` on the same file takes 1.1 s, and a unit test lexes
3,000,000-character literals quickly. The cost is in the token printer of the `lex` command
(`compiler/bin/main.ml`: `Escape.display (token_to_string ...)`), because `Escape.display` goes through `Text.units`,
which builds one boxed unit per scalar value (a list of 4 M units), and the printed token is the whole literal.
ASCII text is cheaper (5 M `a` take 1.5 s), which is why the comment case is fast.

## Acceptance criteria

- [ ] `Escape.display` and `Escape.neutralize` (also used by `egide parse` output: 8 M empty lines in a triple-quoted literal still take 1.28 GB there) run in one pass over the bytes with a `Buffer`, without an intermediate list
      of units; output unchanged (the existing escape tests pass unchanged)
- [ ] `egide lex` on 4 M `é` in a string: under 1 s and under 200 MB (record the numbers in the Outcome)
- [ ] Decide whether `lex` prints a literal in full or truncated (for example 80 characters and a length), documented

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
