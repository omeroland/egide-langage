---
id: T-0002
title: Diagnostics: codes, spans, human and JSON rendering
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [TOOL-040, TOOL-041, TOOL-042]
paths: [compiler/lib/diagnostics/, compiler/test/diagnostics/]
estimate: M
labels: []
status: done
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:36Z
---

## Goal

A complete diagnostics library: severity, code, rule id, primary and secondary labelled spans, notes, machine-applicable fixes; a human renderer with source excerpts and carets, and the JSON renderer of docs/diagnostics.md.

## Context

Spec rules: TOOL-040, TOOL-041, TOOL-042. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [x] `Diagnostic.t` has all fields of docs/diagnostics.md JSON format
- [x] Human rendering snapshot tests for single-line, multi-line and multi-label diagnostics
- [x] JSON output validated against a JSON schema checked into `docs/diagnostics.schema.json`
- [x] Columns count Unicode scalar values (test with é and emoji in strings)

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 syntax-engineer/wave1: claimed.
- Interface: `error`/`warning` now take `~rule` as a **required** label (was `?rule`), enforcing TOOL-040 ("the spec
  rule it enforces"). Every existing caller already passes `~rule`, so call sites are source-compatible. New
  optional `?labels ?notes ?fixes`; new record fields `labels`, `fixes`; new types `label`, `edit`, `fix` (defined
  before `t` so unannotated `d.span`/`d.message` still resolve to `t`). The `rule` field stays `string option`
  (`None` reserved for ICE, JSON `null`).
- Constructors raise `Invalid_argument` on malformed code (`[EW]NNNN` or `ICE`, E for errors, W for warnings), rule id
  (`[A-Z]+-NNN`, the shape of all 220 ids in spec/), empty message/note/fix message or fix without edits: these are
  compiler bugs, and it guarantees every emitted diagnostic satisfies the schema. There is no `Ice` module yet.
- `to_human` output is byte-identical to the seed for diagnostics without labels/fixes (existing syntax snapshots and
  the conformance runner's `file:line:col: error[CODE]` match are untouched). The rich renderer is a new function
  `render_human ~sources` because excerpts need the source text; wiring it into the CLI is T-1000 (compiler/bin is
  outside this task's paths).
- Span `stop` is exclusive (consistent with `Span.of_lexing` and with the docs/diagnostics.md example, where `&cart`
  is 9..14). Documented in docs/diagnostics.md and the schema.
- Security (LEX-003 spirit): human output escapes bidi controls, zero-width characters, U+2028/9, all Cc (tab and LF
  included in free text) as `<U+XXXX>` and invalid bytes as `<0xNN>`, so a diagnostic cannot replay a Trojan Source
  attack in the terminal. JSON escapes the same set as `\uXXXX` and maps invalid bytes to U+FFFD, so it is always
  valid UTF-8. The unsafe-set predicate (`Text.is_unsafe`) duplicates part of `Source_check.is_forbidden` because
  diagnostics cannot depend on syntax; a shared UTF-8 module in `compiler/lib/source/` could factor both later.
- Display width of emoji/CJK (2 cells) and combining marks (0) is an approximation of wcwidth; it only affects caret
  alignment, never column numbers.
- Paths outside `paths`: `docs/diagnostics.schema.json` (named by the acceptance criteria), `docs/diagnostics.md`
  (JSON section: schema link, exclusive end, real edit span in the example; DoD allows it), `compiler/test/dune`
  (`(dirs syntax diagnostics)`, otherwise the new test directory is not built), `CHANGELOG.md` (DoD: user-visible JSON
  change), follow-up task files.
- Schema validation in CI uses a test-only validator (`compiler/test/diagnostics/json_check.ml`) supporting exactly the
  keywords the schema uses; any other keyword makes the test fail, so the schema cannot silently outgrow the check.
  Cross-checked locally (not in CI) with Python `jsonschema` 4.26: schema valid against the 2020-12 metaschema, the
  snapshot outputs and the docs example validate, and mutations are rejected identically.
- Found: an empty file yields E0100 with `Span.dummy` (file "", line 0), which violates TOOL-040 and the schema →
  T-1001.

## Outcome

Done. `egide.diagnostics` now has labelled secondary spans, notes, machine-applicable fixes (TOOL-040), a human
renderer with source excerpts (single-line, multi-line with elision, stacked multi-label, cross-file, fallback
locations, Unicode-aware caret alignment, terminal-safe escaping), and a JSON renderer (TOOL-042) emitting every field
of docs/diagnostics.md, validated against the new `docs/diagnostics.schema.json`.

- Tests: `compiler/test/diagnostics/test_render.ml` (16 snapshot tests), `compiler/test/diagnostics/test_json.ml`
  (5 expect tests: docs example, minimal warning, escaping, an end-to-end lexer column check with é and an emoji,
  and 10 schema mutations rejected; plus 2 qcheck
  properties × 500 cases: arbitrary-bytes diagnostics give one valid JSON line; UTF-8 messages round-trip),
  `compiler/test/diagnostics/test_api.ml` (constructor validation, fields, sink), helper
  `compiler/test/diagnostics/json_check.ml`.
- Rules covered: TOOL-040, TOOL-041 (risk text preserved, security fix rendering), TOOL-042; LEX-003 escaping in
  excerpts.
- Follow-ups: T-1000 (CLI uses `render_human`), T-1001 (dummy span on empty file).
- Limitations: no colour; wcwidth approximation; TOOL-041's "state the risk" is a message-content convention checked
  by review, not enforced by the type (a `risk` field would need a spec/format change).
