# ADR-0020: Lexical edge cases of numeric, string and prefix literals

- Status: Proposed
- Date: 2026-11-11
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. The owner delegated spec decisions to the
  orchestrator ("take the best decisions, review at the MVP"); that delegation covers ADR-0013..0017, not this one, and
  the author does not accept its own ADR. The owner's merge of this PR is the acceptance.
- Spec chapters affected: 2 (LEX-040, 041, 050, 051, 052, 053, 054, 055); `docs/diagnostics.md`
- Answers: Q-0025, Q-0051, Q-0052
- Independent of ADR-0018 (braces): every rule below is about characters inside literals, not about layout.

## Executive Summary

Fifteen small open points of the lexer (Q-0025: 2, Q-0051: 12, Q-0052: 1) are settled by one principle, "restrict
instead of define": where two readings exist and one of them is a silent, invisible or non-monotone behaviour, the
program is rejected with a code. Four decisions carry weight: a triple-quoted string must start on the line after its
opening `"""` (removes the non-monotone pair of Q-0051 items 2 and 4 before `egide fmt` exists); a non-ASCII space in
the margin of such a string is an error (Q-0051 item 11, a security finding); `rb"…"`/`br"…"` are lexical errors
(Q-0052, option B) so that the names stay free for a future raw byte string; `r#"…"#` is an explicit error (item 12).
All other points confirm what the lexer already does. Two choices are the owner's; the defaults are marked.

## Context

Three lexer tasks (T-0003, T-0004, T-0005) are merged and each left questions where the spec text is silent or
contradicts a task's acceptance criterion. The lexer chose the conservative reading each time and pinned it with tests
labelled *extrapolated*. None blocks work, but two of them change what `egide fmt` (T-0090) and the standard library may
rely on, and several could make an accepted program invalid later (which is worse than rejecting now and relaxing
later). Labels used below follow AGENTS.md §2b: *established* = spec text or a reproduction, *emerging* = plausible and
partly evidenced, *extrapolated* = inference.

## Core Analysis

### 1. Q-0025 (numeric literals)

| # | Case | Decision | Basis |
|---|------|----------|-------|
| 1 | `00.5`, `007.25`, `01e3` | **Error E0031**, no octal hint. LEX-041 gets one sentence: the integer part of a float follows the leading-zero rule of LEX-040. | *Established* that LEX-041 is silent; the decision is a restriction. Counter-hypothesis (the rule concerns integers only) was rejected: it makes `00.5` valid while `00` is not, and the text `0755.0` would read as decimal in Égide and be a tempting typo for octal in C-family habits. Relaxing later is compatible; tightening later is not. |
| 2 | `1.` and `_1` | **Keep as implemented.** `1.` lexes as `INT` `.` (LEX-042 needs this for `1.max(2)` and `5.msg`), and the parser rejects a `.` that is not followed by a member name (E0100). `_1` is an identifier (LEX-020) and fails in name resolution if unbound. No lexical rule is added. T-0003 acceptance criterion 2 was wrong and is stale. | *Established* (LEX-041/042, tokens tested). The alternative (a lexical error for a trailing dot) buys an earlier error for one typo at the price of a lexer lookahead rule that the parser already covers with the same span. |

### 2. Q-0051 (strings), twelve items

Decisions in the order of the question. "Confirm" means: keep the implemented behaviour and write it into the spec so
that it is no longer an extrapolation.

| # | Case | Decision |
|---|------|----------|
| 1 | `"\u{202E}"` accepted (T-0004 criterion 3 says rejected) | **Confirm acceptance.** The spec wins (LEX-050, ADR-0017: the escape makes the character visible in the source). Safety rests on LEX-006 (output escaping) and SYN-018. Criterion 3 is stale: no spec change. |
| 2, 4 | Text or spaces after the opening `"""` | **Decided together, see 2.1.** The opening `"""` of a triple-quoted string MUST be followed immediately by a line break (new code **E0045**). |
| 3 | A tab on a blank line of a triple-quoted string | **Confirm E0005.** A tab that vanishes from the value is invisible text (LEX-004). Rejecting is the safe direction: it can be relaxed later without breaking a valid program. |
| 5 | `"""a""""` | **Confirm**: the literal ends at the first closing `"""`; the fourth quote opens a new literal (E0040 if unterminated). A value ending in `"` is written `\"`. Stated in LEX-051. |
| 6 | `b"""…"""` | **Confirm E0043** on the three quotes (no triple-quoted byte string). Rejecting is the safe direction. |
| 7 | Code for a bad escape in a byte string | **Confirm the split**: E0043 for what exists elsewhere but not here (`\u`, `\{`, `\}`) and for raw characters outside printable ASCII; E0041 for escapes that exist nowhere (`\q`, `\'`) and a malformed `\xHH`. Stated in LEX-053. |
| 8 | Raw tab inside `'…'` | **Confirm E0005** (hint "write `'\t'`"). Already in the catalogue; LEX-054 now names the code. |
| 9 | `\` directly before a line break in `"…"` | **Confirm** E0041 then E0040: two distinct causes (an escape that does not exist, a literal that ends at the break). Stated in LEX-050. |
| 10 | `r"""…"""` is dedented | **Confirm.** LEX-051 dedents on raw source lines before escape processing, so raw and plain triple-quoted strings are treated alike. Stated in LEX-052. |
| 11 | A line holding only U+00A0 (security review F3) | **Reject**: in a triple-quoted string, a blank-rendering character (`Zs` other than U+0020, or U+2800) that is the first non-space character of a content line **or of the closing-delimiter line** is **E0046**. Details in 2.2. |
| 12 | `r#"…"#` (security review F4) | **Reject explicitly**: any identifier token immediately followed by `#"` is **E0047** (hint: "Égide has no `#`-fenced raw strings; use `r"…"` or a triple-quoted string"). Details in 2.3. |

#### 2.1 Items 2 and 4: one rule that removes the pair

*Established* from the question: today a first line holding only spaces stays as an empty line (item 2) and text on the
opening line takes part in the margin (item 4). Moving text between the opening line and the next line changes the line
count and possibly the margin, so a formatter that re-flows a literal could change its value (the question calls this
*extrapolated* and asks for a counter-example once T-0024 exists). Here is a hand counter-example, *established* by
applying LEX-051 as implemented: `"""  abc⏎    def⏎    """` has a margin of 2 (opening line `  abc` counts), value
`abc⏎  def⏎`; the same text with `abc` moved to its own line, `"""⏎    abc⏎    def⏎    """`, has margin 4 and value
`abc⏎def⏎`. Same words, different values, differing only by a line break after `"""`.

Options considered:

| Option | Rule | Assessment |
|--------|------|------------|
| **X (recommended)** | The opening `"""` is followed immediately by a line break (E0045). Content starts on the next line. | One form only, so a formatter has nothing to choose. Matches Java text blocks (JEP 378) and Swift multi-line string literals (SE-0168), which both require a line terminator after the opening delimiter (*emerging*: recalled from the proposals, not re-fetched in this session). A restriction, so it can be relaxed later. Costs: no one-line `"""say "hi" """` (use `"say \"hi\""`, `'` is not a string quote), and the T-0004 positive tests that put text on the opening line must change. |
| Y | Python-like: the break is dropped when the rest of the opening line is blank; text on the opening line is excluded from the margin | Monotone only if a formatter indents consistently; two ways to write the same string stay legal, which spec/01 §1.3 ("one obvious way") argues against. |
| Z | Keep the lexer as is and forbid the formatter to re-flow triple-quoted strings | Defers the problem; the stdlib would still contain both forms. |

**Rule (LEX-051, new text).** The opening `"""` MUST be followed immediately by a line break (E0045); there are no
characters, not even spaces, between them. That line break is dropped. Consequently `""""""` and `"""abc"""` are E0045
(the empty string is `""`). The margin is computed over the content lines only. **Re-indentation invariance (testable
property):** adding or removing the same number of leading U+0020 on every content line and on the line of the closing
`"""` does not change the value of the literal, provided the new margin is not negative. A formatter therefore may
re-indent a triple-quoted string freely. The rule applies to `r"""` and to `"""` templates (LEX-055 already
dedents them as LEX-051).

Counter-hypothesis considered and kept open for the owner: some users will want Python's `"""Summary…` start. The
restriction costs one line break per literal; the benefit is that `egide fmt` is a function of the token stream.

#### 2.2 Item 11: lookalike whitespace in the margin

*Established* (security review F3, reproduced in the question): the lexer treats U+00A0 as text, so a line
`␠␠␠␠⍽` (spaces then NBSP) sets the margin to 0, while a line of four spaces is blank. In an editor the two lines look
identical and give different values. LEX-004 and E0051 already exclude invisible whitespace outside strings; this
closes the same class inside the one place where whitespace is semantic. Alternatives: treat every `Zs` as blank
(rejected: then an NBSP-only line silently disappears from the value, which is the same invisibility in another form);
leave as is (rejected: *established* hazard, cheap fix). The rule is mechanical: after the run of U+0020 at the start of
a line, the next character is not blank-rendering (E0046). Mid-line NBSP stays legal text (LEX-003); an NBSP written as
`\u{A0}` is a visible escape and stays legal.

*Revised after the security review of this PR (two blockers):*

- **Closing-delimiter line (established, reproduced by the reviewer on `main`).** A literal whose last content line is
  four spaces then U+00A0 before the closing quotes yields `secret` + LF + U+00A0, visually identical to the same
  literal without the NBSP. LEX-051 now says E0046 also applies to the characters before the closing `"""` on its line,
  which removes the question whether that line is a "content line".
- **U+2800 (emerging: a blank cell in the fonts the reviewer knows).** Category `So`, so neither LEX-003 nor `Zs`
  reaches it. E0046 is extended to "`Zs` other than U+0020, or U+2800", both read from the Unicode 16.0.0 table that
  LEX-003 already embeds, so no second table exists. Still *extrapolated*: I know of no other blank-rendering character
  outside the sets LEX-003 covers (`Cc`, Default_Ignorable such as U+3164 and U+FFA0, U+2028/2029); a pinned
  visual-blank property is the robust form if more are found.
- **The remedy `\u{A0}` does not exist in every form.** `r"""` and the templates other than `f` process no escapes
  (LEX-052, LEX-055; `f` unescapes, so `\u{A0}` works in `f"""`). LEX-051 now gives a remedy per form: plain and `f`
  strings write `\u{A0}`; raw and other templates cannot start a line with such a character and must put text before it
  or use a plain string. This is a deliberate, accepted restriction of those forms, and the E0046 message names the
  remedy that applies.
- Ordering (reviewer N1/N2): "line break" is the LF of the normalised stream (LEX-002); diagnostics are in source order
  and E0045 is primary (the literal is still scanned to its closing `"""`, so E0040 appears only if there is none). The
  first draft's example `"""a""""` was contradictory and is replaced by a content line ending in four quotes.

#### 2.3 Item 12 and `#`-fenced raw strings

*Established* (reproduced by the question's authors): `r#"a" # b"#` lexes as identifier `r`, then a comment to the end of
the line, so the rest of the line, including a `"`, is silently a comment. With `let p = r#"…"#` and a bound variable
`r`, this even type-checks. The narrowest fix that fails closed is a lexical error on the exact shape; supporting
Rust's fences (`r#"…"#`) is rejected because a second raw form would violate "one obvious way" while `"""` and `r"""`
already cover text with quotes. The hazard is not specific to `r`: it exists for any identifier glued to `#"` (`re#"…"#`, `f#"…"#`), so E0047 covers every
identifier token immediately followed by `#"` (security review N3). The first draft's `##` clause is dropped (`b## note`
is a false positive with no security value). A comment starting with `"` and glued to an identifier has no legitimate
use, so the false-positive cost is nil.

### 3. Q-0052 (`rb"x"`)

*Established*: LEX-053 says "There is no `rb"…"`" and LEX-055 (a template prefix is any `lower_snake_case` identifier
other than `r` and `b`) makes `rb"x"` the template prefix `rb`. T-0005 implements the literal reading (option A).

| Option | `rb"x"` | Assessment |
|--------|---------|------------|
| A | template with prefix `rb` | Uniform; an unregistered prefix is an error at the literal (CT-040), not "far from the typo" as the question fears (*established* by CT-040: the error is reported on the literal's span). But `rb` then has a user-chosen meaning where Python and Rust readers expect "raw bytes". |
| **B (recommended)** | lexical error E0043 on `rb"` and `br"` | Catches the habit at once. Stronger reason, *extrapolated*: a later minor version may want `rb"…"` (a raw byte string, the only missing combination of the built-in prefixes `r` and `b`). If `rb` is a legal user template prefix today, adding the feature then breaks every package that registered it. Reserving the two combinations now makes the addition compatible. |
| C | `rb` `IDENT`, then `STRING` | Rejected as in the question: `rb"x"` and `rb "x"` would mean the same, contradicting the significance of "immediately followed" for every other prefix. |

B is a special case in the lexer (two names), which is the cost against A. The cost is one comparison in
`Lexer.template` and two test expectations (T-0005 tests the A behaviour). CT-040 carries the reservation: `@template("rb")`, `"br"`, `"r"` and `"b"` are E0602 (security review N4), otherwise a
package could register a prefix the language has reserved. The reservation covers exactly the
concatenations of the built-in prefixes, so it is a principle, not a list: other names remain free. The owner may
prefer A; then only the sentence in LEX-053 and the exclusion list of LEX-055 change back, and item 12 keeps `rb` and
`br` out of its list.

## Decision

Apply the decisions of the tables above. The spec edits are in this PR (ch. 2) and
`docs/diagnostics.md`; the exact texts are in the diff of `spec/02-lexical-structure.md`. New diagnostics:

| Code | Rule | Message |
|------|------|---------|
| E0045 | LEX-051 | the opening `"""` of a triple-quoted string must be followed by a line break; content starts on the next line |
| E0046 | LEX-051 | a blank-rendering character (`Zs` other than U+0020, U+2800) at the start of a content line or of the closing-delimiter line; remedy per literal form |
| E0047 | LEX-052 | Égide has no `#`-fenced raw strings (an identifier directly followed by `#"`); use `r"…"` or a triple-quoted string |

Extended: E0043 (LEX-053) also covers `rb"` and `br"`; E0031 (LEX-041) also covers a leading zero in the integer part.
No existing rule id is removed or renumbered; no new rule id is created (the new text sits in existing rules).

## Alternatives considered

See the tables in sections 1, 2.1 and 3. Not adopted anywhere: a lexical error for a trailing dot (section 1), `Zs` as
blank (2.2), Rust-style fences (2.3).

## Consequences

- Complexity budget: net neutral. One form of multi-line string instead of two; five restrictions that replace
  extrapolated behaviour with an error; no new feature. Three diagnostics added.
- Security: strengthens the invisible-text discipline of LEX-003/004/E0051 inside triple-quoted strings (INT-005 is not
  concerned). No relaxation. `security-reviewer` reviewed this PR: E0046 as first drafted was not sufficient for F3 and is
  extended (section 2.2). It still does not cover a blank-rendering character after the first non-space character, which
  does not affect the margin or the visible shape of the line.
- Implementation (follow-up tasks proposed for the orchestrator, none created by this PR): `syntax-engineer`: lexer
  changes for E0045, E0046, E0047, the leading-zero float rule and `rb`/`br`, about 40 lines (*extrapolated*);
  `test-engineer`: rewrite the T-0004 tests and `string_triple*.egd` files that put text on the opening line (the
  reviewer found `string_triple.egd` lines 5, 10, 11, `string_raw.egd` line 8 and probably
  `template_fail_multiline_string_in_single_line.egd` line 7; none is in ADR-0018's migration count of 3.5, which task
  T-1108 should extend), add
  negative tests for each new code and a property test for re-indentation invariance. Items confirmed by this ADR need
  tests only if none exists.
- Migration: pre-1.0, no released code. The stdlib is 11 lines; no triple-quoted string exists outside tests.
- Reversibility: every decision is a restriction; relaxing any of them later is source compatible.

## Recommendations / Next Steps

1. Owner: merge this PR to accept, or reject items individually. **Owner's choices with defaults:** 2.1 (X, else Y),
   section 3 (B, else A). Everything else I consider mechanical.
2. After acceptance: orchestrator creates the syntax-engineer and test-engineer tasks above, and moves Q-0025, Q-0051
   and Q-0052 out of `tasks/blocked/` (their status is set to `answered` in this PR).
3. Before T-0090 (`egide fmt`): the re-indentation invariance property of 2.1 must have a test.
4. Not verified here: I did not run the lexer against the new rules; Java/Swift precedent in 2.1 is from memory.
