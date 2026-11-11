---
id: T-1035
title: Layout: body width after continuation lines, first-line width
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0007]
spec: [LEX-030, LEX-032]
paths: [compiler/lib/syntax/layout.ml, compiler/lib/syntax/layout.mli, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: []
status: done
claimed_by:
claimed_at:
---

## Goal

Implement the Q-0016 decisions in the layout algorithm (ADR-0016): body = last continuation line + 4, a line after a block colon is never a continuation, first logical line width 0, multi-line tokens do not affect layout.

## Context

LEX-032 step 2 uses b = indentation of the last physical line when that line is a LEX-030 (b) continuation line, else t. Dedent to b (not on the stack) is E0022. Existing layout conformance tests must keep passing except those the new rule changes; say which in the PR.

## Acceptance criteria

- [ ] Positive: `server\n    .route("/x") fn(req):\n        ok()` lexes with INDENT at width 8
- [ ] Negative: `if a\n    and b:\n    allow()` is E0021
- [ ] Negative: indented first line is E0020; a `.`-leading line right after a block colon is not a continuation
- [ ] A property test keeps INDENT/DEDENT balanced

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log
- 2026-11-10 language-architect: superseded by ADR-0018 (braces): no indentation stack, so no body-width rule. Closed in PR #20.

## Outcome
Not implemented: superseded by ADR-0018 and T-1104 (line-termination pass). Q-0016 is moot once ADR-0018 is accepted.
