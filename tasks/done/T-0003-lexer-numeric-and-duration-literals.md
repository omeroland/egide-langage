---
id: T-0003
title: Lexer: numeric and duration literals
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-040, LEX-041, LEX-042]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M
labels: []
status: done
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

Integer (dec/hex/oct/bin, underscores), float and duration literals are tokenised exactly as specified, with E0030/E0031 diagnostics.

## Context

Spec rules: LEX-040, LEX-041, LEX-042. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] All forms of LEX-040..042 tokenised; `5.s`, `500.ms`, `30.min` are single DURATION tokens
- [ ] `1.` , `1__0`, `0x`, `_1`, `1_` rejected with the right code and span
- [ ] Overflow is **not** checked here (it depends on the type, TYP-070); a note in the Log explains it
- [ ] Conformance tests: ≥ 6 lex-pass, ≥ 6 lex-fail

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0015 decided: no `1__0`, no leading zeros (`0755` is E0030 with octal hint), lowercase `0x 0o 0b e` only, a numeric literal directly followed by an identifier character is an error (E0030/E0031), `.5` is not a float, `_` allowed in fraction/exponent, `1e+9` ok, DURATION needs a decimal integer and a unit not followed by an identifier character (`5.msg` is `INT . IDENT`), no `t.0` (LEX-040..042).

2026-11-10 syntax-engineer (T-0003): decisions and notes.
- **Overflow is not checked in the lexer.** Whether a literal fits depends on its inferred type (TYP-070), which the
  lexer does not know; `INT`/`FLOAT` carry the verbatim source text (underscores included) and the type checker
  validates the value. Unit test: "integer literals are not range-checked in the lexer".
- **Method.** sedlex has no look-ahead, so the lexer matches a generous candidate (a digit followed by identifier
  characters, an optional `.digit...` fraction, an optional signed exponent) and `classify_number` validates it by
  hand: one diagnostic per literal (the first violation), span = the whole literal, and the token is still emitted.
  E0030 = integer-shaped, E0031 = float-shaped (a fraction or exponent is present). `5.msg`: the lexeme `5.msg` is
  given back (`Sedlexing.rollback`) and `5` is re-matched alone, so the output is `INT . IDENT`.
- **New token `DURATION of string * string`** (amount text, unit). It required editing the generator
  `tools/gen/tokens.py` (outside the declared paths, but its outputs `tokens.mly` / `token_table.ml` are inside them
  and `tools/check-generated.sh` forces them to agree) and one literal rule plus a unit-name helper in `parser.mly`
  (without it the token is unused). `layout.ml` was not touched and does not depend on the new token.
- **Spec gaps** raised in Q-0025: leading zero in a float's integer part (implemented as E0031), and `1.` / `_1`
  (T-0003 acceptance criterion 2 lists them as lexical errors, but LEX-041/042 and LEX-020 make them `INT .` and an
  identifier; tested as tokens).
- **Non-ASCII** characters directly after a number (`5é`) are not yet part of the "identifier character" test: the
  lexer's identifier class is ASCII until T-0025 (E0010 / LEX-020).
- **Probable conflicts:** T-0004 (strings), T-0005 (templates), T-1033 and T-1080 edit `lexer.ml` and the generated
  token files (`tools/gen/tokens.py`, `tokens.mly`, `token_table.ml`); T-1104 replaces the layout pass. Expect textual
  conflicts in the `token` match arms and in `VALUED` in the generator; regenerate with `python3 tools/gen/tokens.py`
  after resolving. `parser.mly` `expr_desc` is shared with T-0011.

## Outcome

Done: `INT`, `FLOAT` and `DURATION` lexing per LEX-040..042 and Q-0015/ADR-0016, with E0030/E0031 (rule LEX-040 /
LEX-041 in the diagnostic).

Tests: `compiler/test/syntax/test_lexer_numeric.ml` (9 expect tests, 3 qcheck properties);
`tests/conformance/lexical/numeric_*.egd` (6 lex-pass, 15 lex-fail). Written red first (commit 9aae12f), then made
green.

Rules covered: LEX-040, LEX-041, LEX-042. Follow-ups: none created; Q-0025 (spec question, non-blocking).

Known limitations: see the Log (non-ASCII after a number, `1.` and `_1`, leading zero in floats).
