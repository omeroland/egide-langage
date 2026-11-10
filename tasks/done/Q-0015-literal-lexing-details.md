---
id: Q-0015
rule: LEX-040, LEX-041, LEX-042, LEX-050, LEX-051, LEX-053, LEX-054
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0003, T-0004]
severity: medium
status: decided
---
## Question

Each point below lets two reasonable lexers give different tokens for the same source.

1. **Consecutive underscores.** T-0003 requires `1__0` to be rejected, but LEX-040 only forbids `_` at the start, at
   the end and after a prefix. The task is stricter than the spec.
2. **Leading zeros.** `0755` is accepted as decimal 755 by LEX-040 as written. C, and Python 2, read it as octal 493.
3. **Prefix and exponent case.** `0X1F`, `0B1`, `0O7`, `1E9`: allowed?
4. **Float edges.** `.5` (no leading digit), `1.5_0` or `1e1_0` (underscores in the fraction or exponent),
   `1e+9`.
5. **Duration boundaries.** Is `5.msg` `DURATION(5.ms)` followed by `IDENT(g)`, or `INT . IDENT(msg)`? What about
   `5.s2` and `5.min_value`? Are hexadecimal and binary durations allowed (`0x10.s`, `0b1.ms`)? LEX-042 says
   "an integer literal", which includes them.
6. **Tuple element access.** No syntax exists for reading element *i* of a tuple (`SYN-038` creates tuples, ch. 3
   never reads them). If `t.0` is intended, then `t.0.1` lexes as `t` `.` `FLOAT(0.1)` under maximal munch.
7. **Character literals (LEX-054).** The escape set is not given. `'\''` needs `\'`, which LEX-050 does not have.
   `''`, `'ab'` and a raw tab `'	'` (LEX-003 allows HT "inside string literals only") are unspecified.
8. **Byte strings (LEX-053).** "Only ASCII characters and `\xHH` escapes" makes `b"\""`, `b"\\"` and `b"\n"`
   impossible to write. `rb"…"` is unspecified.
9. **Triple-quoted dedent (LEX-051).** Python's `textwrap.dedent` runs on the *escaped* string at run time, so `\t`
   escapes count as indentation. Does Égide dedent the raw source text before or after escape processing? Are tabs
   allowed in the margin? Is the line break before the closing `"""` kept?

## Recommendation

1. Add to LEX-040: "`_` may not be doubled" (agrees with T-0003).
2. A decimal literal with a leading `0` followed by a digit is error E0030, with the hint "write 0o755 for octal".
3. Prefixes and the exponent letter are lowercase only (`0x`, `0o`, `0b`, `e`). Hexadecimal digits may use either
   case.
4. `.5` is not a float (it lexes as `.` `INT`, which is a syntax error). `_` is allowed between digits of the fraction
   and the exponent with the LEX-040 restrictions. `e+9` is allowed.
5. A DURATION requires a **decimal** integer, and the unit name must not be followed by an identifier character.
   Otherwise the lexer produces `INT . IDENT`. So `5.msg` is a method call and `0x10.s` is `INT . IDENT`.
6. **Restrict**: tuples are read only by destructuring (`let (a, b) = t`, patterns). There is no `t.0`. Named data
   uses structs. If the owner prefers `t.0`, add a lexer rule: "after a `.` token, a digit sequence is an INT with no
   fraction or exponent".
7. Character escapes are the LEX-050 escapes plus `\'`. The literal contains exactly one scalar value (otherwise a new
   error in the E004x range). HT must be written `\t`.
8. Byte strings: printable ASCII and space, plus the escapes `\\ \" \n \t \r \0 \xHH`. No `\u{…}`. `rb"…"` is not
   allowed.
9. Dedent operates on the **raw source lines before escape processing**. Whitespace-only lines are ignored for the
   margin and become empty. The line break before the closing `"""` is kept (as Python does). A tab in the margin is
   error E0005 (LEX-004 extended to the indentation of triple-quoted strings).

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

1 no `__`; 2 leading zeros are E0030 with an octal hint; 3 lowercase prefixes/exponent (hex digits either case), and a literal followed by an identifier character is an error; 4 `.5` is not a float, `_` allowed in fraction/exponent, `e+9` allowed; 5 durations need a decimal integer and a unit not followed by an identifier character, else `INT . IDENT`; 6 no `t.0`; 7 char escapes = LEX-050 minus `\{ \}` plus `\'`, exactly one scalar (E0042), no raw tab; 8 byte strings: printable ASCII plus `\\ \" \n \t \r \0 \xHH` (E0043), no `rb`; 9 triple-quoted dedent on raw lines, whitespace-only lines ignored, closing line break kept, tab in margin is E0005.

ADR-0016. Rules: LEX-040, LEX-041, LEX-042, LEX-050, LEX-051, LEX-053, LEX-054, SYN-038. Tasks T-0003, T-0004 updated.
