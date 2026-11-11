---
id: T-1106
title: Conformance: replace layout tests, test new lexical rules
kind: task
phase: 0
role: test-engineer
depends_on: [T-1101]
spec: [LEX-036]
paths: [tests/conformance/lexical/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Replace the 13 layout_* tests, edit source_crlf_accepted.egd, add positive and negative tests for line termination (`else` on its own line, `{` on its own line, `a` newline `-b`), W0003 and the open-ended range restriction.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Controls: 0018-check.py.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
