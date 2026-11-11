---
id: T-1039
title: One output-escaping function for every tool output (LEX-006)
kind: task
phase: 0
role: tooling-engineer
depends_on: [T-0002]
spec: [LEX-006, LEX-003, SYN-018]
paths: [compiler/lib/diagnostics/, compiler/bin/, compiler/test/diagnostics/]
estimate: S
labels: [security]
status: done
claimed_by: tooling-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp
claimed_at: 2026-11-10
---

## Goal

Add the single escaping function of LEX-006 and route diagnostics (human and JSON) through it; audit, SBOM, lock and LSP tasks must call it.

## Context

ADR-0017, review S1. Escape: the LEX-003 set, Zs except U+0020, bidi controls, DEL, backslash and line breaks, as `\\u{H}`; JSON uses `\\uXXXX` so that no raw code point of the set appears in output bytes.

## Acceptance criteria

- [x] `Escape.display : string -> string` and `Escape.json_safe`, with a test printing every class (ESC, CSI U+009B, NEL, ZWSP, RLO, TAG, DEL, NBSP, backslash)
- [x] Diagnostics excerpts and messages that echo string values use it
- [x] A lint test fails if a diagnostic renderer prints a source string without it

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 tooling-engineer: Design and decisions.
- `Escape` (new, `egide.diagnostics`) is the only module that escapes: `display` (terminal, `\u{H}`, `\\`, `\n`, `\r`, `\t`, `\xHH` for invalid bytes), `display_quoted`, `json_safe` (returns a quoted JSON literal; `\uXXXX`, surrogate pairs above U+FFFF), `display_unit` (excerpts, with cell widths), `neutralize` (guard). `Text` no longer exports an escaper (a lint enforces it).
- `Forbidden_set` is the narrow interface T-1033 plugs into: `mem : int -> bool` and `provisional : bool`. The provisional set is slightly larger than the minimum asked (Cc, U+2028/2029, known Cf, bidi) because it also covers the reviewer's gap list of ADR-0017 and DICP, VS and noncharacters; over-escaping is safe, under-escaping is not. Test `provisional forbidden set is replaced by T-1033 after phase 0` fails when `provisional` is true and tasks/PHASE >= 1 or a T-1033 file is in tasks/done/. T-1033 must set `provisional = false` and replace `mem`; the member/neighbour test then pins its behaviour.
- `Output` (new): the CLI writes to stdout/stderr only through it; it applies `Escape.neutralize` (escapes the set and invalid bytes, keeps LF and backslash so already escaped text is not escaped twice). A lint test rejects raw print primitives in `compiler/bin/main.ml` and `diagnostic.ml`.
- Behaviour changes (spec-mandated, LEX-006): human output moves from `<U+XXXX>`/`<0xNN>` to `\u{H}`/`\xHH`; a backslash in any echoed text is doubled (compiler-authored messages that quote a backslash will show `\\`); a tab in an excerpt is shown `\t` instead of 4 spaces; the replacement text of a fix is shown through `display_quoted`. Existing expect tests in test_render.ml were updated accordingly (`<U+...>` expectations replaced; no check weakened).
- `egide lex` prints `STRING("...")` using OCaml `%S` then `Escape.display`, so backslashes of the `%S` syntax are doubled. Acceptable for a debug command; revisit when the lexer prints values itself.
- `egide parse` prints the AST via `Print.file` (syntax-engineer path); it only goes through the `Output` guard, not `display`, because the printer already emits source syntax and doubling backslashes would corrupt it. Follow-up note: Print.quote escapes only bytes < 0x20 and 0x7F; U+0080..U+009F, bidi etc. are caught by the guard but the printer should use `\u{..}` for the LEX-003 set (T-1033/syntax-engineer, after T-1033 lands).
- Alternative rejected: making `Escape.display` leave backslash alone in excerpts (source is full of `\`). Rejected because an escaped ESC and the literal source text `\u{1B}` would then be indistinguishable (LEX-006 lists `\` explicitly).
- Not covered (no such code yet, tasks must call `Escape`): audit, SBOM, lockfile, LSP, test and panic output. Follow-up T-1110 records the obligation. ocamlformat 0.28.1 does not build in this environment: formatting not machine-checked locally.

## Outcome

Added `Escape`, `Forbidden_set`, `Output` to `compiler/lib/diagnostics/`; all diagnostic renderers (human, excerpts, JSON) and the CLI (`compiler/bin/main.ml`) route every string through them. `make ci` passes locally except the ocamlformat check, skipped because ocamlformat is not installed here.

Tests: `compiler/test/diagnostics/test_escape.ml` (every class, round-trip and no-leak properties for `display` and `json_safe`, arbitrary bytes, forbidden-set members and neighbours, provisional-set expiry, guard, attack cases ESC[1A / CSI / RLO / ZWSP through human, excerpt and JSON renderers, three lint tests); `test_render.ml` expectations updated to the LEX-006 syntax.

Rules covered: LEX-006, LEX-003 (output side), LEX-050 (value subject to LEX-006), SYN-018 (not enforced here: lexer/parser side).

Follow-ups: T-1110 (audit, SBOM, lock, LSP and test/panic output must use Escape; lint extension). Known limitations: see Log.
