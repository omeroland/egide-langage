---
id: T-1033
title: Lexer forbidden-set extension for LEX-003
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0006]
spec: [LEX-003, LEX-050]
paths: [compiler/lib/syntax/source_check.ml, compiler/lib/syntax/source_check.mli, compiler/lib/syntax/lexer.ml, compiler/lib/source/, compiler/lib/diagnostics/forbidden_set.ml, compiler/lib/diagnostics/forbidden_set.mli, compiler/test/syntax/, compiler/test/diagnostics/, tools/gen/, tests/conformance/lexical/]
estimate: S
labels: []
status: in-progress
claimed_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-11
---

## Goal

Implement LEX-003 as a **property-defined** set from a pinned, embedded Unicode 16.0.0 table, and allow any scalar value in `\u{…}`.

## Context

ADR-0016 and ADR-0017 (security review S2). The set is: Cf ∪ Default_Ignorable_Code_Point (assigned or unassigned) ∪ Variation_Selector ∪ noncharacters (U+FDD0-FDEF, U+xFFFE/xFFFF) ∪ U+2028/2029 ∪ Cc (minus LF, minus HT in strings). Not all of Cn. The reviewer's computed gaps that MUST be covered: U+17B4/17B5, U+2065, U+FFF0-FFF8, U+E0080-E00FF, U+E01F0-E0FFF (about 3,700 unassigned DICP). The table is embedded in the compiler; no use of the host's libc/ICU/Unicode data. `tests/security/` is append-only and owned by the security-reviewer; PoC files for the gaps are in the review.

## Acceptance criteria

- [ ] `tools/gen/unicode_forbidden.py` reads `DerivedCoreProperties.txt`, `UnicodeData.txt`, `PropList.txt` of Unicode 16.0.0 (digests recorded in the generated header) and writes `compiler/lib/source/forbidden_table.ml` (neutral package: `egide.syntax` depends on `egide.diagnostics`, so a table in `compiler/lib/syntax/` would be unreachable from `Forbidden_set` without a dependency cycle); `tools/check-generated.sh` fails when stale
- [ ] Every code point of the reviewer's gap list, TAG, Hangul fillers, CGJ, variation selectors, all 170 Cf, noncharacters: rejected in comments, strings and code (E0004), table-driven test against an independently written oracle
- [ ] Neighbours accepted (U+00AC, U+00AE, U+2060 is Cf so rejected; U+FE10, U+E1000 accepted unless DICP)
- [ ] `Zs` other than U+0020 accepted in comments and strings, E0051 elsewhere
- [ ] `"\u{200D}"`, `"\u{E0041}"`, `"\u{1B}"` accepted by the lexer (LEX-050); surrogates and values above 10FFFF are E0041
- [ ] `Egide_diagnostics.Forbidden_set.mem` is a lookup in that table (the hand-written ranges are deleted; there is no `provisional` flag); a differential test compares the generated table with `Forbidden_set.mem` over 0..0x10FFFF, and a cross test checks `lexer rejects cp => Escape.is_dangerous cp` over all scalars (T-1039 / LEX-006)
- [ ] The test `forbidden set is backed by the generated table from phase 1` in `compiler/test/diagnostics/test_escape.ml` passes (it requires `compiler/lib/source/forbidden_table.ml` and a use of it in `forbidden_set.ml` from phase 1)
- [ ] The oracle of the differential and neutralisation tests is written independently of the generator (separate code path, not importing the generator's parsing), and the upstream Unicode 16.0.0 file digests are pinned in the repository, so a regenerated table cannot silently change the expected set
- [ ] The table is never read from the host at run time; a test pins the table's digest

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 tooling-engineer (T-1039 security review F2): paths extended and the table moved to `compiler/lib/source/` (dune graph: `egide.source` <- `egide.diagnostics` <- `egide.syntax`). Do this before claiming T-1033: it must replace `Forbidden_set.mem` of T-1039 (hand-written approximation, no flag) instead of keeping a second copy of the set.

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): Rewritten: property-defined set, pinned table, generator script. The proxy of the authoring session could not download the Unicode files, so the generator is unwritten and the digests are to be recorded by the implementer.

## Outcome
