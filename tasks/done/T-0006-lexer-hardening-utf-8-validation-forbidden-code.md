---
id: T-0006
title: Lexer hardening: UTF-8 validation, forbidden code points, tabs
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-001, LEX-002, LEX-003, LEX-004, LEX-020]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: S
labels: [security]
status: done
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:18Z
---

## Goal

Complete the seed's LEX-001..004 checks with exact diagnostics and a property test that the lexer never raises on arbitrary bytes.

## Context

Spec rules: LEX-001, LEX-002, LEX-003, LEX-004, LEX-020. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [x] Every code point range of LEX-003 has a test (in code, comment and string)
- [x] Invalid UTF-8, BOM, lone CR, tab → E0001/E0002/E0003/E0005
- [x] qcheck: 10 000 random byte strings, lexer returns tokens or diagnostics, never raises

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 syntax-engineer/wave1: UTF-8 decoding now follows Unicode §3.9 Table 3-7 (maximal subparts). A run of
  ill-formed bytes yields **one** E0001 spanning the run (previously one per byte, so a binary file produced one
  diagnostic per byte); each maximal subpart counts as one column, as if replaced by U+FFFD.
- E0004 messages now include the character name, as in the docs/diagnostics.md template `U+{cp} ({name})`. The one
  existing snapshot in `compiler/test/syntax/test_layout.ml` was updated for this (message text only).
- A forbidden character or BOM between tokens no longer also produces E0051 "unexpected character" (it was
  reported twice). Lone CR was already silent in the lexer.
- Spec gap fixed: a tab inside a comment, doc comment or shebang was accepted. LEX-003/004 allow HT only inside
  string literals, so it is now E0005. A run of tabs is one E0005 spanning the run.
- LEX-020: E0010 "non-ASCII character in identifier" is allocated but not emitted. Emitting it would break the
  append-only `tests/security/lexical/homoglyph_identifier.egd` (pins E0051), so this task keeps E0051 and creates T-0025.
- The seed conformance runner cannot read files containing NUL or invalid UTF-8 (grep ≥ 3.5 treats them as binary
  in every locale), so those cases are unit tests only; follow-up T-0026. CR-sensitive conformance files are stored
  with `-text` (new `tests/conformance/lexical/.gitattributes`); verified with `git ls-files --eol`.
- LEX-003's invisible-character list is closed and misses e.g. TAG characters (U+E0000–E007F), Hangul fillers,
  U+2061–2064: spec-question Q-0001 (not blocking this task, which implements the rule as written).
- Perf (local, 1 M lines of 75 bytes): `Source_check` went from 0.65 to 1.14 M lines/s. End-to-end `tokenize` is
  about 0.14 M lines/s both before and after this change. That is well below the 1 M lines/s target of
  docs/architecture.md §5, but the gap was already there, not a regression. Not addressed here.
- Unit tests live in a separate library `compiler/test/syntax/lexer_hardening/` so that `qcheck-core` is not added
  to the shared `test_syntax` library edited by parallel tasks.

## Outcome

**Done.** `Source_check` (LEX-001..003) rewritten with a Table 3-7 UTF-8 decoder, run-coalesced E0001, named
E0004. The lexer reports tabs in comments (E0005) and no longer double-reports forbidden characters as E0051.
`Lexer.tokenize` is property-tested never to raise.

Tests added:
- `compiler/test/syntax/lexer_hardening/test_lexer_hardening.ml` (+ `dune`): invalid UTF-8 table (16 cases) and
  boundary values; BOM; CR LF and lone CR in code/comment/string/EOF; **all 81 forbidden code points × code,
  comment, string** (exact code, rule and span); E0004 names; allowed neighbours; tabs in strings, indentation,
  runs, comments, doc comments, shebang; LEX-020 non-ASCII identifier rejection; 1 M-character inputs; three qcheck
  properties of 10 000 cases each (arbitrary bytes, lexer fragments, arbitrary scalar values) checking no
  exception, E0001 ⇔ not valid UTF-8, one E0004 per forbidden code point and one E0003 per lone CR against oracles
  written from the spec, and well-formed spans. Mutation-checked: accepting surrogates makes sedlex raise
  `MalFormed` and the properties fail; dropping U+000C from the forbidden set fails the table test and the properties.
- `tests/conformance/lexical/`: `forbidden_cp_in_{code,comment,string}.egd` (18 code points, one per range),
  `source_bom_rejected`, `source_crlf_accepted`, `source_lone_cr_rejected`, `tab_in_comment`,
  `tab_in_string_accepted`, `unicode_text_accepted`, `identifier_ascii_accepted`, plus `.gitattributes`.
- `compiler/test/syntax/test_layout.ml`: E0004 snapshot message updated (name added).

Rules covered: LEX-001, LEX-002, LEX-003, LEX-004, LEX-020 (ASCII-only; E0010 deferred), LEX-010/011/012 (tabs in
comments).

Follow-ups: T-0025 (E0010, needs the owner to amend a security test), T-0026 (binary-safe conformance runner +
invalid UTF-8/NUL conformance tests), Q-0001 (spec-question: other invisible characters).

Known limitations: an adversarial file alternating valid and invalid bytes still produces one E0001 per run (no cap).


