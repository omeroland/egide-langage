---
id: T-0027
title: docs/testing.md: header rules enforced by the runner
kind: task
phase: 0
role: test-engineer
depends_on: [T-0014]
spec: []
paths: [docs/testing.md]
estimate: S
labels: [docs]
status: backlog
claimed_by:
claimed_at:
---

## Goal

docs/testing.md §2 states the header rules that the T-0014 runner enforces, so that test authors learn them from
the testing guide and not from a failing run.

## Context

tests/README.md ("How a header is read", "How a run is judged") documents them. To add to docs/testing.md §2: at
least one `# diagnostic:` for `*-fail`; unknown `# key:` directives and runner directives after the header block
are errors; cited rule ids must exist in `spec/`; `# stdout:` keeps the text verbatim; expected exit statuses (0, 1,
101) and crash detection; diagnostics are read from `--error-format=json`; `--junit` and `--jobs`.

## Acceptance criteria

- [ ] docs/testing.md §2 lists the rules above and links tests/README.md for runner options

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 test-engineer: created from T-0014 (docs/testing.md is outside T-0014's paths).

## Outcome
