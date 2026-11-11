---
id: Q-0052
rule: LEX-053, LEX-055
raised_by: syntax-engineer/T-0005
blocking: []
severity: low
status: open
---
## Question

**Executive summary.** LEX-053 says "there is no `rb"…"`" while LEX-055 makes every `lower_snake_case` identifier other
than `r` and `b` (and not a keyword) a template prefix, which includes `rb`. T-0005 implements the literal reading of
LEX-055 (`rb"x"` is a template); T-0004 had pinned `IDENT STRING`. The language-architect should decide.

## Core analysis

*Established* (spec text, reproduced by `compiler/test/syntax/test_lexer_strings.ml`): LEX-055 excludes exactly `r`
and `b`; `rb` is neither, so by its letter `rb"x"` is a `TEMPLATE` with prefix `rb`. LEX-053 only says that no raw byte
string exists; it does not say what `rb"…"` lexes as.

Options:

| Option | Behaviour of `rb"x"` | For | Against |
|--------|----------------------|-----|---------|
| A (implemented) | template with prefix `rb`; meaning is given by a `comptime` template function (CT-040), unregistered prefix is a later error | no special case in the lexer; matches LEX-055 literally | a user who expects a raw byte string gets a template error far from the typo (extrapolated) |
| B | lexical error (E0043 or E0044) on `rb"` | the typo is caught at once, LEX-053 is honoured as "no `rb`" | a user-defined `rb` template function is impossible; a special case in the lexer |
| C | reserve `r`, `b` and `rb` (and `br`) as non-prefixes: `rb"x"` is `IDENT STRING` | keeps the T-0004 behaviour | `rb "x"` and `rb"x"` mean the same thing, which contradicts "immediately followed" being significant for other prefixes |

## Recommendation / next steps

*Extrapolated:* option B for `rb` and `br` only, with a one-sentence addition to LEX-053 ("`rb"…"` and `br"…"` are
E0043"), because the likely intent of LEX-053 is to stop a Rust/Python habit, and an early error is the safe failure.
Option A is acceptable if the owner prefers the uniform rule. Until decided the lexer implements A; changing to B or C
is a three-line change in `Lexer.template` plus two expectations in `test_lexer_strings.ml`.
