---
id: T-0007
title: Layout: continuation lines, bracket joining, single-line blocks
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-030, LEX-031, LEX-033, LEX-035]
paths: [compiler/lib/syntax/layout.ml, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M
labels: []
status: done
claimed_by: syntax-engineer/wave1
claimed_at: 2026-11-09T09:31:41Z
---

## Goal

The seed layout pass implements LEX-032/034; add LEX-030 (b) continuation lines starting with `|>`, `.`, `and`, `or`, and the E0023 check of LEX-033.

## Context

Spec rules: LEX-030, LEX-031, LEX-033, LEX-035. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [x] Pipelines and method chains over several lines produce no NEWLINE between continuation lines
- [x] `:` at end of line without INDENT → E0023
- [x] Property test: layout tokens are balanced (INDENT count = DEDENT count) on generated programs

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0016): Q-0016 decided: LEX-032 step 2 uses the last continuation line + 4 as body width, a line after a block colon is never a continuation, multi-line tokens do not affect layout, the first logical line has width 0. Layout follow-up is T-1035. The token contract (LEX-036, ADR-0013) is the existing behaviour; no change needed for it (T-1032 adds tests).

- 2026-11-09 syntax-engineer: LEX-030 (b) is implemented literally. A physical line at bracket depth 0 is a
  continuation when its width is **greater than the width of the first physical line of the current logical
  line** (not the stack top, not the previous physical line) and its first token is `|>`, `.`, `and` or `or`.
  Continuation lines may be indented by any amount and need not line up with each other. A continuation token at
  the same or smaller width starts a new logical line, and the parser rejects it.
- 2026-11-09 syntax-engineer: E0023 (LEX-033) points at the `:` token. It is reported when the logical line ending
  in `:` is followed by a line at width <= stack top, or by end of file. At end of file inside an unclosed bracket,
  the trailing `:` is not checked (LEX-035); the unclosed bracket is the parser's error. Recovery adds no tokens.
- 2026-11-09 syntax-engineer: The property test found a bug in the seed. E0022 recovery pushed the offending width
  without emitting INDENT, so the next pop or end of file emitted an unmatched DEDENT. Recovery entries are now
  marked `phantom` and emit no DEDENT when popped. The diagnostic itself is unchanged. Only the recovery token
  stream of the seed test "dedent to an unknown column" changed (one DEDENT fewer). The spec does not define a
  recovery stream; LEX-034 counts DEDENTs per real block.
- 2026-11-09 syntax-engineer: SYN-010 and the EBNF (`block = NEWLINE INDENT … NEWLINE DEDENT`) contradict LEX-032
  steps 2/3 and the §2.4 example (`: INDENT`, a single NEWLINE before several DEDENTs). The layout follows LEX-032.
  Raised as tasks/blocked/Q-0002-layout-tokens-vs-ebnf-block.md (blocks T-0010).
- 2026-11-09 syntax-engineer: qcheck-core (already a with-test dependency in dune-project) is added to the
  compiler/test/syntax test library. No benchmark added: the change adds O(1) work per line and touches no
  per-character path.

## Outcome

Done. `layout.ml` now implements LEX-030 (b) continuation lines (`|>`, `.`, `and`, `or`), the E0023 check of
LEX-033, and balanced INDENT/DEDENT under E0022 recovery. Single-line blocks (LEX-033) and bracket joining
(LEX-030 a / LEX-035) are covered by new tests, including a trailing `:` inside brackets, a dedent below the block
inside brackets, and an unclosed bracket at end of file.

Tests added:
- compiler/test/syntax/test_layout.ml: 16 expect tests (pipeline, method chain, and/or before a block colon,
  continuation widths, comments inside a continuation, non-continuation tokens, continuation after a
  multi-line bracket, E0023 x3, single-line blocks x2, brackets x2, E0022 recovery balance).
- compiler/test/syntax/test_layout_props.ml: qcheck properties, with a fixed seed. (1) On arbitrary line soup with
  colons, unbalanced brackets and continuation tokens, INDENT/DEDENT are balanced and properly nested and the
  stream ends with EOF (2000 cases). (2) Generated well-indented programs give no diagnostics and exactly one
  INDENT per block (1000 cases). Mutation-checked: removing the phantom fix, the continuation rule or the E0023
  check each makes a test fail.
- tests/conformance/lexical/layout_continuation_pipeline.egd, layout_continuation_method_chain.egd,
  layout_continuation_and_or.egd, layout_continuation_other_operator.egd (E0020), layout_single_line_block.egd,
  layout_colon_without_block.egd (E0023), layout_colon_at_eof.egd (E0023),
  layout_brackets_ignore_indentation.egd.

Rules covered: LEX-030, LEX-031, LEX-032, LEX-033, LEX-034, LEX-035.

Follow-ups: Q-0002 (spec-question, EBNF vs LEX-032 layout tokens, blocks T-0010). No new tasks.

Known limitations: E0020 recovery is unchanged from the seed. Each further line at the same unexpected width
reports E0020 again. Making recovery less noisy is left to T-0013.


