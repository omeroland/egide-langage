---
id: Q-0024
rule: SYN-015, CT-002, ADR-0017 (B2)
raised_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp (T-1030 review)
blocking: []
severity: low
status: open
---
## Question

**Executive summary.** For `let X = unsafe(reason: "…"): …` at top level, SYN-015 and ADR-0017 B2 call the restriction
"a grammar restriction" (`const_block` excludes `unsafe`, `given`, `with`), while E0104 is "this block-ended expression
must stand alone". Which diagnostic does the user get?

## Core analysis (established from the text)

The EBNF `const_decl = "let" IDENT [ ":" type ] "=" ( expr NEWLINE | const_block )`: since `unsafe_expr` is a
`block_expr`, a `block_expr` is not an `expr` (ADR-0013), and `const_block` omits it, no derivation exists, so the
natural result of an LR parser is a generic syntax error (E0100). E0104 would need a semantic or error-state message.
The AST (`Const.value : expr`) represents it either way; `ast.mli` currently cites E0104 and T-1031 lists E0104 for every
SYN-015 position. There is no negative PoC under `tests/security/syntax/` for this case.

## Options

A. E0104 with the hint "bind it inside a function"; implemented through a Menhir error message for that state.
B. Generic syntax error E0100 (as the grammar says).
C. New dedicated code in E01xx.

## Recommendation

A, for the message quality and consistency with the other SYN-015 positions; T-1031 adds the negative test.
The architect decides and amends SYN-015 so it does not call this both a grammar restriction and E0104.
