---
id: T-0013
title: Parser: error messages and recovery
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0012, T-0002]
spec: [SYN-001]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Menhir `.messages` file with human messages for every error state reachable by the test corpus; recovery at the next same-indentation NEWLINE or DEDENT.

## Context

Spec rules: SYN-001. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] `menhir --compare-errors` passes in CI (dune rule)
- [ ] A file with 3 independent syntax errors reports exactly 3 diagnostics

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated): spec/grammar/egide.ebnf is v0.3 (ADR-0013, ADR-0014, ADR-0015 accepted). Read `docs/adr/attachments/0013-menhir-check.mly` (0 conflicts) as the starting point for parser.mly, and do T-1030 (AST) first. Here: with the terminator model recover at `NEWLINE` or `DEDENT`; E0100 must cite the right rule (SYN-002 for import order, noted by the T-0008 review); give tailored messages for `let` in one-line blocks, `1 + match`, `xs |> len == 0`.

## Outcome


