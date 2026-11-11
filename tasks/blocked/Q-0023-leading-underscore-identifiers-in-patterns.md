---
id: Q-0023
rule: SYN-053, LEX-020, ERR-002
raised_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp (T-1030 review)
blocking: []
severity: low
status: answered (ADR-0021 proposed)
---
## Question

**Executive summary.** SYN-053 decides `Pat_bind` versus `Pat_const` by the first character but says nothing about an
identifier that starts with `_` (`_x`, `_`): is `_x` a binding, and is `_` alone the wildcard only?

## Core analysis (established from the text)

SYN-053: "A lone identifier that starts with an uppercase letter … denotes a variant or constant … A lone identifier
that starts with a lowercase letter denotes a binding, and `_` is the wildcard." `_x` is neither, yet LEX-020 allows it
as an IDENT and ADR-0017 (ERR-002: "a never-read `Result` binding (`_x` included) is a discard") treats `_x` as a binding.
`ast.mli` documents `Pat_bind` as "a lone identifier starting with a lowercase letter" and was left unchanged until this
is answered. Related: E0121 suggests "write `Discontinued` or `_`"; whether `_discontinued` is exempt is also open.

## Options

A. A lone identifier that is not uppercase-initial is a binding, so `_x` binds and only the exact name `_` is the wildcard.
B. Same as A, and a binding starting with `_` is exempt from unused-binding diagnostics (E0121, W-unused).
C. `_x` is forbidden in patterns.

## Recommendation

B: it matches ERR-002 and the usual convention. Rewrite SYN-053 as "a lone identifier that does not start with an
uppercase letter is a binding; `_` alone is the wildcard".

## Answer (language-architect, 2026-11-11)

Settled in [ADR-0021](../../docs/adr/0021-attribute-arguments-underscore-bindings-toplevel-let.md) (Proposed; the owner's merge accepts it), spec edits in the same PR: option B: any lone identifier not starting with an uppercase letter is a binding, only `_` is the wildcard, `_`-initial bindings are exempt from unused-binding diagnostics and E0121.
