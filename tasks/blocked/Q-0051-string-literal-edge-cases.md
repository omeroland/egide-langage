---
id: Q-0051
rule: LEX-050, LEX-051, LEX-053, LEX-054
raised_by: syntax-engineer/T-0004
blocking: []
severity: low
status: open
---
## Question

**Executive summary.** T-0004 is implemented and not blocked. LEX-050..054 leave twelve edge cases open, and one acceptance
criterion of T-0004 contradicts the rule it tests. For each, the lexer made the most conservative choice (reject or
follow `textwrap.dedent`); the language-architect should confirm or reverse them. Labels: *established* = spec text,
*extrapolated* = the syntax-engineer's inference.

## Core analysis

| # | Case | Implemented (extrapolated unless noted) | Alternative |
|---|------|------------------------------------------|-------------|
| 1 | T-0004 criterion 3: "`\u{202E}` escape rejected (LEX-003 applies to escapes too)". LEX-050 and ADR-0017 say the opposite (any scalar value is accepted by `\u{…}`) | *Established:* the spec wins; `"\u{202E}"` is accepted, tested. The criterion is stale. Safety rests on LEX-006 (output escaping, T-1039) and on the AST printer, which prints such a value as `\u{202E}` (changed in this PR) | none; fix the criterion text |
| 2 | `"""` followed by spaces then a line break: LEX-051 drops "the first line break after the opening `"""`" | The break is dropped only when it directly follows the quotes. `"""  \nx"""` is the value `"\nx"` (the blank first line stays, as an empty line) | drop it when the rest of the first line is blank (Python-like) |
| 3 | A tab in the leading whitespace of a *blank* line of a triple-quoted string (LEX-051: "A tab in the margin is E0005"; blank lines are "ignored for the margin") | E0005 anyway: a tab that disappears silently from the value is the kind of invisible text LEX-004 exists to exclude | ignore tabs on blank lines |
| 4 | Text on the opening line (`"""  abc`) takes part in the margin | Yes, with its spaces, exactly as `textwrap.dedent` sees the text (`"""  abc"""` is `"abc"`) | exclude the first line from the margin |
| 5 | Closing: `"""a""""` | A triple-quoted string ends at the first unescaped `"""`; the fourth quote opens a new literal (here an unterminated one, E0040). A value ending in `"` is written `\"` | Python also does this; Rust-style raw strings use `#` fences |
| 6 | `b"""…"""` | Not in LEX-053. *Implemented after review:* E0043 on the three quotes; the body is read as a triple-quoted string (value kept as bytes) | allow a triple-quoted byte string (needs a spec sentence) |
| 7 | Which code for a bad escape in a byte string | E0043 for the escapes that exist elsewhere but not here (`\u`, `\{`, `\}`) and for raw characters; E0041 for unknown escapes (`\q`, `\'`) and a malformed `\xHH` (as for `\u{…}` in a string) | E0043 for all |
| 8 | A raw tab inside `'…'` (LEX-054 gives no code) | E0005 (LEX-004: a tab outside a string literal), message says to write `'\t'`; the value is still the tab | E0042 |
| 9 | `\` immediately before a line break in `"…"` | E0041 (backslash at end of line) and, because the line break ends the literal, E0040 | E0040 only |
| 10 | `r"""…"""` is dedented (LEX-051 says "triple-quoted strings", LEX-052 "process no escapes") | Yes, dedent applies to raw triple-quoted strings (extrapolation of LEX-051 + LEX-052; tested: `r"""` expect test and `string_triple.egd`) | raw triple-quoted strings keep their margin |
| 11 | A line holding only a no-break space (U+00A0, `Zs`, allowed in strings by LEX-003) in a triple-quoted string. Security review F3 | It is not blank: LEX-051 blank = spaces (and tabs); the NBSP is text and sets the margin to 0. Two literals that look identical in an editor can therefore have different values (a line with spaces vs. a line with an NBSP). Behaviour unchanged. **To settle before the first release** | treat every `Zs` as blank, or reject a `Zs` other than U+0020 in a margin |
| 12 | `r#"…"#` (Rust-style raw fence). Security review F4 | Not a raw literal: `r` (identifier), then `#` starts a comment to the end of the line, so the rest of the line, including a `"`, is silently a comment. Same for `br"…"`/`rb"…"` (identifier then string). Behaviour unchanged; `b"""` is E0043 explicitly (done, item 6) | reject `r` directly followed by `#` and `"` with an explicit error, or specify `r#"` fences |

**Items 2 and 4 are a non-monotone pair to settle before T-0024 (`egide fmt`) and the stdlib.** Item 2 (a first line holding only spaces stays as an empty line) and item 4 (text on the opening line counts for the margin) are not monotone: moving text after `"""` onto its own line, or the reverse, changes the line count and may change the margin, so a formatter that re-flows a literal could change its value (extrapolated; to be confirmed with a counter-example once T-0024 exists). Tests that pin extrapolated behaviour (items 2, 3, 4, 10): `triple-quoted details`, `a tab in the margin...`, `string_triple_tab_after_margin.egd`, `string_fail_triple_tab_blank_line.egd`, `r"""` cases. They are labelled *extrapolated* in comments.

Also noted: `\xHH` is not an escape of strings or characters (E0041); `r"C:\dir\"` is valid (a raw string ends at the first
`"`); a literal with a bad escape in `'…'` or an unterminated literal has the value U+FFFD and no second diagnostic.

## Recommendation / next steps

- Decide 2 and 4 together (before T-0024 and the stdlib), and 3, 6 (the only ones that could make a valid program invalid later); the others can stay as implemented.
- Amend the T-0004 criterion 3 (case 1) and add one sentence to LEX-051 for cases 2-4 and one to LEX-053 for case 6.
