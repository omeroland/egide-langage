---
id: T-1080
title: Lexer — bound the number of diagnostics per file (E0003/E0004 flood)
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-002, LEX-003]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/, docs/diagnostics.md]
estimate: S
labels: [security, perf]
status: backlog
claimed_by:
claimed_at:
---

## Goal

A hostile source file can no longer make the compiler allocate memory or time linear in the number of forbidden
characters: runs of identical lexical errors are collapsed, or the number of diagnostics per file is capped, so that
`egide lex|check|build` and the language server stay bounded on untrusted input.

## Context

Finding F1 of the security review of T-0006 (PR #1). T-0006 collapsed E0001 and E0005 into one diagnostic per run, but
E0004 (forbidden character, LEX-003) and E0003 (lone CR, LEX-002) are still reported once per character. Measured on
the T-0006 head with `egide lex`, one comment per file:

| input | size | diagnostics | time | peak RSS |
|-------|------|-------------|------|----------|
| `#` then 5,000,000 NUL bytes | 5 MB | 5,000,000 E0004 | 10.7 s | ~1.8 GB |
| `a\r` x 2,000,000 | 4 MB | ~2,000,000 E0003 | 3.5 s | ~550 MB |
| `a\t` x 2,000,000 | 4 MB | 2,000,000 E0005 (alternating, so runs do not collapse) | 3.7 s | ~440 MB |

Reproducer: `python3 -c "import sys; sys.stdout.buffer.write(b'module m\n\n# '+b'\x00'*5_000_000+b'\n')" > flood.egd`
then `egide lex flood.egd 2>&1 >/dev/null | wc -l`.

Packages are compiled from untrusted dependencies (spec/09, PKG), so this is a denial-of-service vector on the build
and on the LSP. It does not break INT-001..005. Also see non-blocking suggestion 5 of the code review: alternating valid
and invalid bytes still give about n/2 E0001.

Design freedom (pick one, document it in the Log):
- collapse a run of the *same* forbidden code point into one diagnostic with a count and a span over the run (the
  E0005 model); and/or
- cap the diagnostics per file (for example 100) and end with one note "N more errors suppressed". The cap must be
  applied where diagnostics are produced (not only when printing), so that memory is bounded too. Every forbidden
  character must still make the file fail: suppression never turns an error into acceptance.

Any change to the E0003/E0004 text or to the reported spans needs the `docs/diagnostics.md` catalogue updated; the
existing tests in `tests/security/lexical/` and `tests/conformance/lexical/` pin the first diagnostic of each file and
must keep passing unchanged (they are append-only or must not be weakened).

## Acceptance criteria

- [ ] The three inputs of the table above finish in under 1 s each and under 100 MB peak RSS (measure with
      `/usr/bin/time -v`; record the numbers in the Outcome).
- [ ] A file with at least one forbidden character, lone CR or tab-outside-string still exits 1 whatever the cap.
- [ ] A unit test (`compiler/test/syntax/`) with 1,000,000 forbidden characters asserts a bounded diagnostic count
      and that the first diagnostic is unchanged.
- [ ] `tests/security/` is passing unchanged; no test weakened.
- [ ] `make ci` passes.

## Out of scope

Error recovery after E0001 (lexing stops there), per-package or per-build diagnostic limits, the character set of
Q-0001.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): also collapse consecutive identical forbidden characters or lone CRs into one diagnostic with a count (the E0005 run model), and keep the flood reproducer of the T-0006 review under 100 MB and 2 s. This replaces the duplicate task T-1034, which was removed.

## Outcome
