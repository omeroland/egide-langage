---
id: T-0015
title: Extract spec code blocks into parse tests
kind: task
phase: 0
role: test-engineer
depends_on: [T-0014, T-1102]
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
- 2026-11-10 language-architect: dependency on the ADR-0018 migration tasks added in PR #20 so that this task cannot start against the indentation grammar; T-1108 retargets its text.

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0021 decided: `spec/README.md` defines the info strings `egide` (file), `egide decls` (wrap with `module spec.decls`), `egide fragment` (wrap with `module spec.fragment` and `fn fragment():`, indent), `egide invalid` (must fail to parse); dedent list-item blocks; `# error RULE-ID` lines are semantic and still parse. Chapter blocks are tagged. Parse-level only: parse tests become runnable once T-0009..T-0012 land.

## Outcome


