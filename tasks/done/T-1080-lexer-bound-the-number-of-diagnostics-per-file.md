---
id: T-1080
title: Lexer — bound the number of diagnostics per file (E0003/E0004/E0005/E0040..E0043 flood)
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-002, LEX-003, LEX-050, LEX-051, LEX-053, LEX-054]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/, docs/diagnostics.md]
estimate: S
labels: [security, perf]
status: done
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-12
---

## Goal

A hostile source file can no longer make the compiler allocate memory or time linear in the number of forbidden
characters: runs of identical lexical errors are collapsed, or the number of diagnostics per file is capped, so that
`egide lex|check|build` and the language server stay bounded on untrusted input.

## Context

**Added by T-0004 review (PR #26):** E0041, E0043 and E0005 (margin of a triple-quoted string) are also reported once
per occurrence inside literals: 200 k `\q` in one string is about 64 MB of diagnostics, 400 k about 177 MB. The bound
applies to them too.

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

- [x] The three inputs of the table above finish in under 1 s each and under 100 MB peak RSS (measure with
      `/usr/bin/time -v`; record the numbers in the Outcome).
- [x] A file with at least one forbidden character, lone CR or tab-outside-string still exits 1 whatever the cap.
- [x] A unit test (`compiler/test/syntax/`) with 1,000,000 forbidden characters asserts a bounded diagnostic count
      and that the first diagnostic is unchanged.
- [x] `tests/security/` is passing unchanged; no test weakened.
- [x] `make ci` passes.

- [x] (Added by the security review of PR #26, F2.) The bound covers E0040, E0041, E0042, E0043 and E0005 (margin of a
      triple-quoted string) as well: `b"` followed by 1,000,000 `é` is 1,000,000 E0043 (162 MB measured), 200 k `\q` is
      64 MB, 400 k is 177 MB. A unit test with 1,000,000 bad escapes asserts a bounded count and that the first
      diagnostic is unchanged; the file still fails whatever the cap.

## Out of scope

Error recovery after E0001 (lexing stops there), per-package or per-build diagnostic limits, the character set of
Q-0001.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): also collapse consecutive identical forbidden characters or lone CRs into one diagnostic with a count (the E0005 run model), and keep the flood reproducer of the T-0006 review under 100 MB and 2 s. This replaces the duplicate task T-1034, which was removed.

2026-11-12 syntax-engineer: design (Executive summary: a global per-file cap in the sink is the security guarantee;
run collapsing is kept as the usability layer ADR-0016 asks for).

| Option | Bounds memory? | Bounds alternating input (`a\r`, `<U+200B>a`, `a\t`)? | Cost | Verdict |
|--------|----------------|------------------------------------------------------|------|---------|
| Collapse runs only | only for adjacent repeats | no (n/2 diagnostics remain; the T-0006 review's own table has two such rows) | small | insufficient alone |
| Cap only | yes | yes | small | sufficient for safety; a single 5,000,000-NUL run would burn the budget with 100 copies of one fact |
| Both (chosen) | yes | yes | ~40 lines in `Source_check` | cap = guarantee, collapse = signal quality (a run is one diagnostic, the budget is left for distinct problems) |

Decisions (all *established* by the tests listed in the Outcome unless marked otherwise):

1. **Where the cap lives.** `Diagnostic.Sink.create ?limit`: `report` keeps the first `limit` diagnostics and, past
   it, only increments a counter and remembers the span of the first dropped one (O(1) time and memory per report).
   Bounding at the producer, not at print time, is what bounds RSS. `Sink.has_errors` is now a flag (it was O(n)) set
   by every error, kept or dropped, so suppression cannot turn an error into acceptance. Because the first `limit >= 1`
   diagnostics are always kept and the first error is among kept ones unless warnings fill the budget, the flag is
   the authoritative exit-status input; a test covers kept-warning/dropped-error.
2. **One budget per file, shared.** `Lexer.tokenize` creates one sink (limit 100, the figure suggested by the task) and
   passes it to `Source_check.check_into` and to the lexer state. The previous code had two accumulators
   (`Source_check.check` list, lexer sink); two budgets would allow 200 and, more importantly, make the summary
   ambiguous. Uniform application to E0003, E0004, E0005 (also margins), E0040..E0044 follows from every report going
   through `Sink.report`. E0001 stops lexing, and "has ill-formed UTF-8" is now returned as a boolean by
   `check_into` instead of being re-derived with `List.exists` over the diagnostics (which would have been wrong
   once E0001 could be dropped; *established* by reading the old code path).
3. **Order.** Unchanged: raw-text diagnostics first (they run first), then the lexer's. This is not strict source
   order across the two producers; it is the pre-existing behaviour, kept so that no expectation changes. Within one
   producer order is source order. Same input gives the same list: no hash tables, no time, no addresses.
4. **Summary diagnostic E0006**, rule TOOL-040 (the rule that governs diagnostics and their catalogue; there is no LEX
   rule about limits and the spec is not edited here), error severity, message
   `N further diagnostics suppressed (limit L per file)`: fixed text, two integers, no source echo, so the
   Escape/Output rules (LEX-006) have nothing to escape beyond the file name that every diagnostic already carries.
   Span: that of the first suppressed diagnostic (position data only). It is last in `Sink.to_list`.
   Code choice: E0006 is the first free code in E0001-E0005 (source-text group), unused on `main` and in the diffs of
   open PRs #29-#35 (checked on their `docs/diagnostics.md` patches): #29 reserves E0043, E0045-E0047, #30 E0122, #32
   E0422-E0424/E0610, #33 E0611/E0707, #34 E0705-E0710, #35 E0703-E0704.
5. **Language server stability.** The kept list is a prefix of the unbounded list, so the first 100 diagnostics of a
   file do not change when more errors are appended later in the file; only the count in the summary does (test
   "prefix stable and deterministic"). A client that diffs diagnostics by (code, span, message) therefore sees at most
   the summary change. *Extrapolated:* nothing in the repository's LSP exists yet to confirm client behaviour.
6. **Run collapsing (ADR-0016).** Adjacent identical forbidden characters (E0004) and adjacent lone CRs (E0003) on a
   line are one diagnostic with a span over the run and `repeated N times` appended to the character description.
   A single character keeps its exact old text (the conformance expectations only pin code and position). The E0005
   run model already existed. Docs updated (E0003, E0004 rows).
7. **Linear time.** Source_check keeps O(1) state per run; the sink is O(1) per report. 5 MB of NUL went from 10.7 s to
   0.24 s (measured, Outcome).
8. **Not covered (follow-ups).** Layout diagnostics (E0020..E0023: 500,000 E0020 still cost 6.2 s / 400 MB, reproduced)
   -> T-1160. Token-list memory amplification (4 MB of `a<TAB>` outside a comment: 480 MB although only 101 diagnostics)
   -> T-1161. Ids T-1160/T-1161 were the next free on `origin/main` at 2026-11-12; renumber if another branch took them.

Existing tests whose expectation changed (rule 4: justified, property unchanged):
- `compiler/test/diagnostics/test_forbidden_set.ml` "the lexer reports E0004 for exactly the oracle set": it put every
  scalar value (about 8,000 forbidden ones) in one file and expected one E0004 each. That is incompatible with any cap
  by construction. It now lexes batches of 64 scalars per file (below the limit, so nothing is suppressed) and checks
  the identical property (set equality with the oracle, span columns, `Escape.is_dangerous`) over all scalars.
- Same file, "a long line of forbidden code points is linear": 1,000,000 identical U+202E used to expect 1,000,000
  E0004; by ADR-0016 it is now one E0004 with span cols 3..1,000,003. Still runs the 1,000,000-character input.
- `test_lexer_hardening.ml` property "arbitrary bytes": the count of E0004/E0003 diagnostics became the count of
  characters covered by E0004/E0003 spans (sum of widths) when no E0006 is present, and `<=` plus an exact length of
  101 when E0006 is present. QCheck found the collapse case itself (two adjacent U+000B), which confirms the property
  has teeth.
- `tests/security/` and existing `tests/conformance/` files are untouched; two conformance files were added.

9. **Comment lexeme chunking (needed for the 100 MB criterion).** With the cap alone, `#` + 5,000,000 NUL still peaked at
   110 MB, and so does a *valid* 5 MB comment with no diagnostic at all (control, measured on main and on the head):
   the greedy `Plus (Compl ('\n' | '\t'))` makes Sedlex hold the whole comment as one lexeme (an int array, 8 bytes
   per code point). `comment` now matches `Rep (_, 1 .. 256)` and loops; the token stream and diagnostics are
   unchanged (all tests pass), peak RSS fell to 13 MB. Alternative rejected: a one-character-per-iteration loop
   (slower per comment byte, no benefit over 256).

## Outcome

Implemented: a bounded `Diagnostic.Sink` (limit 100, O(1) per dropped report, `has_errors` flag), E0006 summary
(docs/diagnostics.md), one shared sink for `Source_check.check_into` and the lexer, run collapsing for E0003/E0004,
comment lexemes chunked at 256 code points. Design and alternatives: Log above.

Measured on the head with `egide lex` (Python `resource`/`subprocess`, since `/usr/bin/time` is absent here; one
process per input; exit status 1 for every flood):

| input | before (T-0006 review) | after |
|-------|------------------------|-------|
| `#` + 5,000,000 NUL (5 MB) | 5,000,000 E0004, 10.7 s, ~1.8 GB | 1 E0004 (run), 0.22 s, 13.6 MB |
| `# ` + `a\r` x 2,000,000 + `a` (4 MB) | ~2,000,000 E0003, 3.5 s, ~550 MB | 100 E0003 + E0006, 0.33 s, 13.7 MB |
| `# ` + `a<TAB>` x 2,000,000 (4 MB) | 2,000,000 E0005, 3.7 s, ~440 MB | 100 E0005 + E0006, 0.39 s, 13.7 MB |
| `b"` + 1,000,000 `é` | 1,000,000 E0043, 162 MB | 100 E0043 + E0006, 0.41 s, 35 MB |
| `"` + 400,000 `\q` | 177 MB | 100 E0041 + E0006, 0.16 s, 13.7 MB |

All table rows meet the criteria (under 1 s, under 100 MB, exit 1). Two measurements outside the table are above the bar and are recorded as
follow-ups: layout flood (T-1160, 6.2 s / 400 MB) and token-list memory (T-1161, 4 MB of `a<TAB>` outside a comment:
4.4 s / 480 MB, down from 18 s / 1.0 GB). `make ci`: exit 0 locally; the ocamlformat check is skipped locally
(0.28.1 unavailable), CI will report format diffs.

Tests: `compiler/test/syntax/lexer_hardening/test_diag_cap.ml` (E0003, E0004, E0005 incl. triple-quoted margin,
E0041, E0043, E0044 floods of 1,000,000 / 200,000 items: count, first, last, still fails; run collapse; boundary 100/101;
prefix stability; shared budget; `Parse.tokens`), `compiler/test/diagnostics/test_sink_limit.ml` (limit, order,
has_errors, `Obj.reachable_words` of the sink after 1,000,000 reports below 10,000 words), conformance
`diag_cap_summary.egd`, `diag_cap_lone_cr.egd`. Rules: LEX-002, LEX-003, LEX-004, LEX-051, LEX-053, LEX-055, TOOL-040.
Follow-ups: T-1160, T-1161.
