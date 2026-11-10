---
id: T-1062
title: check-spec.sh exits 1 silently on a spec without rule ids
kind: task
phase: 0
role: release-manager
depends_on: [T-1003]
spec: []
paths: [tools/check-spec.sh, tools/tests/check-spec-test.sh]
estimate: S
labels: [bug]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`ids=$(grep -ohE ... | sed ...)` in tools/check-spec.sh exits 1 with no message when no rule id is found (`set -euo
pipefail`). It should print `no rule ids found in spec/` to stderr and exit 1 explicitly.

## Context

Found by the code-reviewer of T-1003 (PR #8), non-blocking point 2.

## Acceptance criteria

- [ ] Empty-spec fixture in tools/tests/check-spec-test.sh: exit 1 and the message above
- [ ] Non-empty specs unchanged

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-10 release-manager: created from the T-1003 review.

## Outcome
