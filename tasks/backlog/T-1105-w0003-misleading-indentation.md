---
id: T-1105
title: W0003: indentation does not match the braces
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1104]
spec: [LEX-005]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Implement the W0003 check (ADR-0018 item 10): ASCII spaces only, not suppressed for dependencies, reported to `egide fmt --check`.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Precedent: W0001 (LEX-005).

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
