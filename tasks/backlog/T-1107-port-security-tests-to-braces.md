---
id: T-1107
title: Port tests/security to the brace syntax
kind: task
phase: 0
role: security-reviewer
depends_on: [T-1102]
spec: [ERR-002, SYN-015, SYN-017]
paths: [tests/security/]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Port the 26 files of tests/security/semantics and tests/security/syntax. Follow the rule and mapping table of docs/adr/attachments/0018-security-test-port.md (same diagnostic codes and logical positions, one-to-one mapping, retirements only with the owner's approval). Delivered as a `governance/*` PR merged by the owner: the append-only exception is a proposal (open question 6 of ADR-0018), not granted. Add attack tests: misleading indentation, discard inside a one-line block, whitespace-only edits.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Labels: security.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
