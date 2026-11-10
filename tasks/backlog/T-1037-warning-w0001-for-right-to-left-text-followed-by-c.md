---
id: T-1037
title: Warning W0001 for right-to-left text followed by code on the line
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-005]
paths: [compiler/lib/syntax/, compiler/test/syntax/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Emit W0001 when a string literal or comment contains a strong RTL letter (bidi class R or AL) and a token follows on the same line.

## Context

Security review F3 of T-0006; LEX-005. Low priority: display-order aid only. Needs a bidi-class table for R/AL.

## Acceptance criteria

- [ ] Hebrew and Arabic examples from the review warn; the same string alone on its line does not
- [ ] Tokens are unchanged

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
