---
id: T-0019
title: CLI: cmdliner-based `egide` with lex, parse, check stubs
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-0002]
spec: [TOOL-040, TOOL-042]
paths: [compiler/bin/, compiler/lib/driver/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Replace the seed argv parsing with cmdliner: `egide lex|parse|check [--error-format=human|json] FILE…`, `--version`, exit codes per tooling-engineer rules.

## Context

Spec rules: TOOL-040, TOOL-042. See docs/architecture.md and the role file `.claude/agents/tooling-engineer.md`.

## Acceptance criteria

- [ ] `egide --help` lists subcommands of spec/13 (unimplemented ones print 'not implemented yet' and exit 2)
- [ ] Exit codes tested

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

## Outcome


