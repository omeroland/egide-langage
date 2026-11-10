---
id: T-1040
title: Tooling follow-ups from the security review
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-0090]
spec: [LEX-011, TOOL-031, SYN-018]
paths: [compiler/bin/, tools/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Three small tooling items: escape raw HTML in `##` doc comments rendered by `egide doc`; a TR39 mixed-script audit lint for string literals used in comparisons (low priority); never run dependencies' `@integration` tests from the root's `egide test --integration`.

## Context

Review of ADR-0016 (not reviewed part, F5) and of ADR-0015 (attribute table). Split into separate PRs when claimed.

## Acceptance criteria

- [ ] Doc rendering escapes HTML by default
- [ ] `egide audit` reports strings mixing scripts when compared with `==` (warning)
- [ ] `egide test --integration` runs only the root package's `@integration` functions

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
