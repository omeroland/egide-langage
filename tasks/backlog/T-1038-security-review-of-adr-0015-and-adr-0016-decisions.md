---
id: T-1038
title: Security review of ADR-0015 and ADR-0016 decisions
kind: task
phase: 0
role: security-reviewer
depends_on: [T-1033]
spec: [LEX-003, LEX-055, CT-011, GO-032, ERR-012, SYN-017, SYN-053]
paths: [tests/security/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Review the security-relevant decisions taken owner-delegated and add attack tests to tests/security/ (append-only).

## Context

Items: unsafe as a block-ended expression (SYN-017, MEM-070/071); removal of type-returning comptime functions (CT-011/012); `@go_threadsafe` as an attribute (GO-032); sink templates reject `:spec` and raw literal parts (LEX-055, E0601); let-else as pure matching (ERR-012); comptime generic value arguments (SYN-042, CT-001..004, CAP-041); no allowlist in LEX-003.

## Acceptance criteria

- [ ] Written verdict per item in the task Outcome; objections become ADR proposals
- [ ] Attack tests for the forbidden set (TAG, fillers, variation selectors), `:spec` on sinks, `return unsafe` placement

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome
