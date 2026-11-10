---
id: T-0023
title: Security review of the lexer (Trojan Source, homoglyphs)
kind: task
phase: 0
role: security-reviewer
depends_on: [T-0006]
spec: [LEX-003, LEX-004, LEX-020]
paths: [tests/security/lexical/]
estimate: S
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Attack the lexer with the Trojan Source techniques (bidi overrides, homoglyph identifiers, invisible characters in strings and comments) and record each attempt as a test.

## Context

Spec rules: LEX-003, LEX-004, LEX-020. See docs/architecture.md and the role file `.claude/agents/security-reviewer.md`.

## Acceptance criteria

- [ ] ≥ 10 attack tests under tests/security/lexical/, all rejected

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): The LEX-003 set grew (ADR-0016, T-1033): review the extended forbidden set and the Unicode-version pin; F1 (diagnostic flood) is T-1034, F3 (RTL) is LEX-005/T-1037.

## Outcome


