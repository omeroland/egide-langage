---
id: T-1103
title: Re-bracket spec code blocks, README, examples and stdlib
kind: task
phase: 0
role: docs-writer
depends_on: [T-1101, T-1102]
spec: [SYN-010]
paths: [spec/, README.md, examples/, stdlib/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Rewrite the `egide` blocks of chapters 4-13 (12 contain block forms), README.md, the 4 files of examples/ and stdlib/std/prelude.egd in the brace syntax. Reference rewrites: docs/adr/attachments/0018-syntax-options.md (d_tenants/b_tenants).

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Spec edits happen on an `adr/*` branch.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
