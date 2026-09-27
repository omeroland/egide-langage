# ADR-0005: Indentation-based syntax and trailing blocks

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 2, 3

## Decision

Blocks are delimited by indentation (4 spaces, tabs forbidden), like Python, converted to INDENT/DEDENT by the lexer so
the grammar stays LR(1). Multi-line lambdas are written as a **trailing block** after the call's closing parenthesis
(`f(a) fn(x):`), as in Kotlin, Swift and Ruby. Short lambdas use `x => e`.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Braces (Go/Rust) | loses Python's readability, which is one of the three pillars |
| Multi-line lambdas inside the argument list | requires closing a parenthesis after an indented block — unreadable; the reason Python never had them |

## Consequences

- One trailing block per call; functions taking two multi-line callbacks receive named functions.
- `scope`, `retry`, route handlers and lock bodies all read naturally.
