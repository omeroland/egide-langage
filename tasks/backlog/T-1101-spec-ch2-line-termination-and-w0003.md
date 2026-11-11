---
id: T-1101
title: Spec ch. 2: line termination, brace placement, W0003
kind: task
phase: 0
role: language-architect
depends_on: [T-1100]
spec: [LEX-021, LEX-030, LEX-032, LEX-033, LEX-035, LEX-036]
paths: [spec/02-lexical-structure.md, docs/diagnostics.md]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Apply ADR-0018 section 5 to chapter 2 (on an `adr/*` branch): LEX-021 without `elif`, LEX-030/035 and LEX-032..034 replaced, LEX-036 rewritten, new rules for brace placement and W0003, diagnostics E0020-E0023 retired, new codes allocated.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Exact rule table in ADR-0018 section 5. New rule ids are allocated here.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
