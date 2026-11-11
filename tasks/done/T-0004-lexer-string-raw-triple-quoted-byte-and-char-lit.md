---
id: T-0004
title: Lexer: string, raw, triple-quoted, byte and char literals
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-050, LEX-051, LEX-052, LEX-053, LEX-054]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/, tools/gen/tokens.py, CHANGELOG.md]
estimate: M
labels: []
status: done
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

All non-template string forms with escapes and dedenting of triple-quoted strings.

## Context

Spec rules: LEX-050, LEX-051, LEX-052, LEX-053, LEX-054. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [x] Every escape of LEX-050 tested; invalid escape → E0041 at the backslash
- [x] Triple-quoted dedent semantics match Python's textwrap.dedent on 10 table-driven cases (14 cases, expected values produced with Python's `textwrap.dedent`; plus a qcheck property against an OCaml model)
- [x] ~~`\u{202E}` escape rejected~~ **Rewritten by the syntax-engineer** (Q-0051.1): LEX-050 and ADR-0017 say `\u{…}` accepts any scalar value, so `"\u{202E}"` is accepted (the criterion contradicts the rule, which prevails; AGENTS.md rule 1). A *raw* U+202E in a literal is E0004. Tested both ways; the AST printer escapes such values
- [x] Unterminated literals → E0040 pointing at the opening quote

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0015/Q-0001 decided: char escapes are LEX-050 minus `\{ \}` plus `\'`, exactly one scalar (E0042), no raw tab; byte strings accept printable ASCII and `\\ \" \n \t \r \0 \xHH` only (E0043), no `rb`; triple-quoted dedent works on raw lines before escapes, whitespace-only lines ignored, closing line break kept, tab in margin is E0005; `\u{…}` accepts any scalar value (T-1033 extends the forbidden set).

2026-11-10 syntax-engineer (T-0004): decisions and notes.
- **Method.** Two steps per literal: a scanner finds the end of the literal and collects the raw text (a backslash
  protects `\\` and the quote in cooked forms; raw forms have no protection), then `decode_escapes` produces the value
  and reports each bad escape on its own span (backslash to the last consumed character). Triple-quoted literals are
  split into raw lines, dedented (LEX-051), then each line is decoded; positions of diagnostics inside a triple-quoted
  literal are exact because a chunk records the position of its first scalar. All scanners are tail-recursive: a
  3 M-character literal and a 300 k-line literal are tested (no stack growth).
- **Tokens.** `STRING` (plain and triple-quoted), `RAW_STRING` (`r"…"`, `r"""…"""`; the EBNF lists it and the AST
  has `Raw_string`), `BYTES`, `CHAR of Uchar.t`. `tools/gen/tokens.py` (outside the declared paths, like T-0003) and its
  outputs, `parser.mly` (three literal rules) and `print.ml` were edited; `layout.ml` was not touched.
- **Security.** LEX-003 stays a raw-input check (`Source_check`): a forbidden character written in a literal is E0004,
  also in `'…'` and `b"…"`. `\u{…}` is the only way to put one in a value (LEX-050, ADR-0017); the lexer does not
  filter it. Consequences handled here: (a) the AST printer (`Print.quote`) now prints every `Escape.is_dangerous`
  scalar as `\u{H}`, so a printed literal lexes back to the same value (property test) and cannot carry a raw bidi
  control; (b) diagnostics never carry the offending character raw: an invalid escape such as backslash + U+202E is
  reported with `Escape.display` (test). Sizes: no limit is imposed on a literal here; SYN-006 bounds nesting and
  T-1080 the number of diagnostics (a literal of N bad escapes yields N diagnostics until T-1080).
- **NUL and line ends.** A raw NUL is E0004 (Source_check). `\0` and `\u{0}` are values. CR LF inside a
  triple-quoted literal is one LF in the value; a lone CR is E0003 and stays in the value as before (the existing
  hardening test expects it). A line break ends `"…"`, `'…'`, `b"…"`, `r"…"` with E0040 (the break is given back, so
  the next line is lexed normally).
- **Spec gaps** are in Q-0051 (nine edge cases, one stale acceptance criterion); none blocks.
- **Behaviour change** from the seed: `\{` and `\}` are now valid escapes of strings (LEX-050); the seed reported
  them as E0041. The seed also swallowed a line break after a backslash into the string; it is now E0041 + E0040.
- **Benchmark (hot path changed).** `egide lex FILE > /dev/null`, whole pipeline (lexer, layout, token printing), one
  run each, noisy; base = main 2d8d9ff, after = this branch. 900 k lines of strings with and without escapes: 9.29 s /
  7.90 s (the base reports E0041 for `\u{41}`, so the two runs do different work); one 900 k-line triple-quoted
  string: 22.7 s / 10.9 s (the base ends the literal at the first line break and reports 900 k diagnostics: not
  comparable); one 5 M-character string: 1.50 s / 1.60 s (same work, within noise). No regression is evidenced; these
  numbers do not isolate the lexer and the 1 M lines/s target of docs/architecture.md §5 is not assessed (the
  pipeline is below it, as noted in T-0003).

## Outcome

Done: `STRING`, `RAW_STRING`, `BYTES` and `CHAR` lexing per LEX-050..054 and Q-0015 / ADR-0016 / ADR-0017, with E0040,
E0041, E0042, E0043 and E0005 (margin of a triple-quoted string, raw tab in a character literal).

Tests (red first, commit 6fedbc4, then green): `compiler/test/syntax/test_lexer_strings.ml` (16 expect tests, 7 qcheck
properties: never raises and ordered tokens, string / char / bytes / raw round trips, dedent against a model, printed
literal lexes back), one parse test in `test_parse.ml`; `tests/conformance/lexical/{string,bytes,char}_*.egd` (6 lex-pass,
13 lex-fail).

Rules covered: LEX-050, LEX-051, LEX-052, LEX-053, LEX-054 (LEX-003/004/006 interplay as above).

Follow-ups: none created; Q-0051 (spec question, non-blocking). T-0005 (templates) will reuse the scanners'
conventions; `W0001` (LEX-005) for right-to-left text in literals is T-1037.

Known limitations: see Log and Q-0051 (`b"""`, tab on blank lines, first-line margin). `\u{…}` of a forbidden
code point is accepted by design. The extended LEX-003 set (T-1033) will extend `Source_check`, not this code.
