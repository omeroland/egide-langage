---
id: T-0026
title: Conformance tests with invalid UTF-8 and NUL bytes
kind: task
phase: 0
role: test-engineer
depends_on: [T-0006, T-0014]
spec: [LEX-001, LEX-003]
paths: [tests/conformance/lexical/, tools/run-conformance.sh, tools/conformance/]
estimate: S
labels: [security]
status: done
claimed_by: test-engineer/wave2
claimed_at: 2026-11-10
---

## Goal

Black-box conformance tests for invalid UTF-8 (E0001) and the NUL character (E0004), which T-0006 could only cover
with unit tests because the seed runner cannot read such files.

## Context

- GNU grep ≥ 3.5 treats a file containing NUL or invalid UTF-8 as binary (in both `C` and `C.UTF-8` locales): it
  prints "binary file matches" on stderr instead of the header lines, so `tools/run-conformance.sh` reports
  "missing '# spec:' header". The runner must read headers in a binary-safe way (`grep -a`, or the T-0014 runner).
- Cases to add: lone continuation byte, overlong form, surrogate, value above U+10FFFF, truncated sequence at end of
  file, NUL in a comment, in a string and in code. Expected positions are in
  `compiler/test/syntax/lexer_hardening/test_lexer_hardening.ml` (one E0001 per run of ill-formed bytes; each
  maximal ill-formed subpart counts as one column).
- Store the files with `-text` in `tests/conformance/lexical/.gitattributes`.

## Acceptance criteria

- [x] The runner reads headers of files containing NUL and invalid UTF-8
- [x] At least the cases above are conformance tests and pass

## Out of scope

Changing lexer behaviour.

## Log

- 2026-11-09 syntax-engineer/wave1: created from T-0006.

## Outcome
- 2026-11-10 test-engineer/wave2: no runner change needed. The runner reads files as bytes (T-0014) and the header is the
  leading ASCII `#` block, so binary content simply goes after it; a `# diagnostic:` line count shifts the line numbers.
  Beware: a comment line in the header block that contains `word:` with a lowercase key is parsed as a directive.

Outcome:
Added 20 binary fixtures `tests/conformance/lexical/bytes_*.egd` (header text first, bytes after) and a
`bytes_*.egd binary` rule in `tests/conformance/lexical/.gitattributes` (`-text -diff -merge`: byte-exact, verified with
`git ls-files --eol` and a blob-vs-worktree compare).
Rules covered: LEX-001 (E0001: lone continuation, overlong 2/3/4-byte, surrogate, above U+10FFFF, truncated mid-file and
at EOF, run of bad bytes = one diagnostic, separate runs in comment/string/code; boundary values accepted), LEX-003
(E0004: NUL in comment, string, code, at EOF; U+FEFF mid-file in comment, string, code), LEX-002 (E0003 lone CR at EOF).
Leading BOM (E0002) and lone CR in code/comment/string were already covered by `source_bom_rejected` and
`source_lone_cr_rejected`.
Positions are derived from the spec and the T-0006 unit tests (one E0001 per ill-formed run, one column per maximal
ill-formed subpart), not from compiler output; one initial miscount was mine, not the compiler's.
Follow-ups: none. Limitation: the forbidden set may grow (Q-0001); these tests only use U+0000 and U+FEFF.
