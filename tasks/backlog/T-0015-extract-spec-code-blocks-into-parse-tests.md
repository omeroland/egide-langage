---
id: T-0015
title: Extract spec code blocks into parse tests
kind: task
phase: 0
role: test-engineer
depends_on: [T-0014]
spec: []
paths: [tools/extract-spec-examples.py, tests/conformance/spec-examples/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Every ```egide block of spec/*.md becomes a generated parse-pass test (fragments wrapped in a module when needed), regenerated in CI and diffed.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/test-engineer.md`.

## Acceptance criteria

- [ ] Generated tests are committed and CI fails if regeneration changes them
- [ ] Blocks marked `<!-- no-test -->` just before the fence are skipped

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


