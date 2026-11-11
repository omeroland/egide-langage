---
id: T-0005
title: Lexer: prefixed templates with recursive interpolation
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0004]
spec: [LEX-055]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/, tools/gen/tokens.py, tools/check-generated.sh, CHANGELOG.md]
estimate: M
labels: []
status: in-progress
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-11
---

## Goal

`f"…{expr}…"` and other prefixes produce a TEMPLATE token holding literal parts and the token streams of interpolations, supporting nesting.

## Context

Spec rules: LEX-055. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] `f"a{b}c"`, `sql"… {x} …"`, `f"{f"{x}"}"`, `{{`/`}}` escapes tested
- [ ] Interpolation spans map to exact source positions
- [ ] `r"…"` and `b"…"` are not templates

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): LEX-055 end rule: `#` inside `{…}` is E0044; `\` consumes the next character first, then `{{`/`}}` collapse, lone `}` is E0044; char literals and nested strings tracked in interpolations; empty spec `{x:}` is a spec; literal parts delivered after brace collapse; template nesting limit 8 (E0044). E0601/E0602 live in the template/type phase, not in the lexer.

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0014 decided (LEX-055): literal parts are raw, `{{`/`}}` only lexer escapes, a backslash only protects the next character, interpolation `{expr[:spec]}` ends at the first `:` or `}` outside brackets (strings and templates tracked), spec raw without `{ } "` or line break, line break inside `{}` only in triple-quoted templates, keywords are never prefixes, triple-quoted templates dedented before splitting, E0044 for malformed interpolation. Sink prefixes rejecting `:spec` (E0601) belong to the template functions, not the lexer.

## Outcome


