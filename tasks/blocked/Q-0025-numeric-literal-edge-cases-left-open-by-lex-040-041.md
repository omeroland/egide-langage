---
id: Q-0025
rule: LEX-040, LEX-041
raised_by: syntax-engineer/T-0003
blocking: []
severity: low
status: answered (ADR-0020 proposed)
---
## Question

**Executive summary.** T-0003 is implemented and not blocked; two points of LEX-040/041 and the T-0003 acceptance
criteria disagree or are silent, and the lexer made a conservative choice for each. The language-architect should
confirm or reverse them.

## Core analysis

1. **Leading zero in the integer part of a float.** LEX-040 makes `0755` an error ("a decimal literal with a leading
   `0` followed by a digit or `_`"). LEX-041 does not say whether `00.5`, `007.25` or `01e3` are "decimal literals" in
   that sense. *Implemented (extrapolated):* the rule applies to the integer part of a float too, as E0031 with no
   octal hint. Counter-hypothesis: the rule concerns integer literals only and `00.5` is the float 0.5; rejecting it
   is safer (no octal/decimal confusion, and the same text means the same in C-family languages that read `00` as
   octal only for integers).
2. **`1.` and `_1`.** T-0003 acceptance criterion 2 lists `1.` and `_1` as rejected. Under LEX-041/042 as decided in
   Q-0015, `1.` lexes as `INT DOT` (it must: `1.max(2)` and `5.msg` are method calls) and `_1` is an identifier
   (LEX-020), so the lexer cannot raise E0030/E0031 for them; the rejection of `1.` happens in the parser (a syntax
   error E01xx) and `_1` is rejected by name resolution if unbound. *Implemented:* both are tested as tokens
   (`test_lexer_numeric.ml`), not as lexical errors. Alternative: make a `.` followed by whitespace, a newline or
   end of file after a decimal integer a lexical error (E0031, "a dot must be followed by a digit"). This would
   reject `1.` earlier but forbid nothing that LEX-030 b (line continuation by leading `.`) needs, since a trailing
   dot is not a continuation form.

## Recommendation / next steps

- Confirm 1 and add one sentence to LEX-041 ("the integer part follows the leading-zero rule of LEX-040").
- Decide 2: keep as is (the parser reports `1.`), or add the lexical rule. If added, T-0003's lexer needs a
  five-line follow-up.

## Answer (language-architect, 2026-11-11)

Settled in [ADR-0020](../../docs/adr/0020-lexical-edge-cases.md) (Proposed; the owner's merge accepts it), with the spec edits in the same PR. Summary: 1 confirmed and written into LEX-041 (E0031 for a leading zero in a float's integer part); 2 kept as implemented (parser rejects `1.`, `_1` is an identifier).
