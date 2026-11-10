---
id: Q-0001
rule: LEX-003
raised_by: syntax-engineer/wave1
blocking: []
status: decided
---
## Question

LEX-003 forbids an explicit, closed list of "zero-width and invisible characters" (`U+200B`–`U+200D`, `U+2060`,
`U+FEFF`). Several other code points are also invisible or zero-width in common editors and review tools, and are
not on that list, so T-0006 accepts them in comments and string literals (identifiers are ASCII-only, LEX-020, so
they cannot appear there). Should LEX-003 forbid any of them?

| Code points | Name / category | Why it matters |
|-------------|-----------------|----------------|
| `U+00AD` | SOFT HYPHEN (Cf) | invisible in most renderers |
| `U+034F` | COMBINING GRAPHEME JOINER (Mn) | invisible |
| `U+115F`, `U+1160`, `U+3164`, `U+FFA0` | Hangul fillers (Lo) | render as blank; used in published "invisible backdoor" demos |
| `U+180E` | MONGOLIAN VOWEL SEPARATOR (Cf) | zero-width in current Unicode |
| `U+2061`–`U+2064` | invisible math operators (Cf) | zero-width |
| `U+206A`–`U+206F` | deprecated format characters (Cf) | invisible |
| `U+FE00`–`U+FE0F`, `U+E0100`–`U+E01EF` | variation selectors (Mn) | invisible; can carry hidden data |
| `U+E0000`–`U+E007F` | TAG characters (Cf) | invisible; used to smuggle hidden ASCII text, e.g. instructions aimed at AI code reviewers, inside comments |
| `U+FFF9`–`U+FFFB` | interlinear annotation (Cf) | invisible |

## Example

```egide
module m

# (Described, not embedded.) After "ok" below, a run of TAG characters U+E0041.. could spell a hidden ASCII
# message that a human reviewer cannot see but a tool or an AI reviewer may read; LEX-003 accepts it today.
let x = 1  # ok
# Likewise, U+2063 between "ad" and "min" would be invisible and make the string compare unequal to "admin".
let key = "admin"
```

## Options

A. Keep LEX-003 as is (closed list). Leave the other characters to a linter or `egide fmt --check` warning.
B. Extend LEX-003 with the table above (or a subset), as compile-time errors (E0004).
C. Forbid **all** characters of general category Cf, plus the specific Lo/Mn code points in the table, everywhere
   except via escapes in string literals. This makes the rule future-proof against new Cf additions.

## Recommendation

C, or at least B for the TAG characters and the Hangul fillers. The rationale of LEX-003 ("invisible-character
confusion") covers them, string literals can still contain them through `\u{…}` escapes (LEX-050), and the cost
is one more range check in `Source_check`. The decision belongs to the language-architect (and an ADR if accepted),
as it changes the spec. T-0006 implements LEX-003 exactly as written and does not depend on the answer.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Option C without an allowlist. LEX-003 forbids every `Cf` character, the variation selectors, U+034F and the Hangul fillers, everywhere, as E0004. Strings write such characters with `\u{…}`, which LEX-050 now accepts for any scalar value. ZWJ/ZWNJ/U+FE0F get no exception (cost and reasons in ADR-0016). RTL letters in strings: explicit non-goal, warning W0001 (LEX-005). Zs spaces stay allowed.

ADR-0016. Rules: LEX-003, LEX-005 (new), LEX-050. Lexer work: T-1033; flood cap T-1080; warning T-1037.
