---
id: T-0022
title: Spec audit of chapters 2 and 3
kind: task
phase: 0
role: language-architect
depends_on: [T-0001]
spec: []
paths: [tasks/blocked/, docs/adr/]
estimate: S
labels: []
status: done
claimed_by: language-architect/wave1
claimed_at: 2026-11-09T09:32:12Z
---

## Goal

Read chapters 2–3 and the EBNF adversarially; list ambiguities, contradictions and missing rules as spec-questions or ADR proposals.

## Context

Spec rules: n/a. See docs/architecture.md and the role file `.claude/agents/language-architect.md`.

## Acceptance criteria

- [x] Every finding is a Q-file or an ADR draft; a summary comment in the Log

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

- 2026-11-09 language-architect: audited `spec/02-lexical-structure.md`, `spec/03-syntax.md`,
  `spec/grammar/egide.ebnf` against each other, against the seed `lexer.ml`/`layout.ml`/`parser.mly`, and against
  every `egide` example in `spec/`, `README.md`, `examples/`, `stdlib/` and `tests/conformance/`.
- Summary of findings (severity, tasks affected):

  | Id | Finding | Sev. | Affects |
  |----|---------|------|---------|
  | ADR-0013 | EBNF block/statement productions cannot parse the LEX-032 token stream (no `NEWLINE` before `INDENT`, none after `DEDENT`); `if`/`match` stmt-vs-expr reduce/reduce conflict; block-ended expressions (`let x = match …`, `let r = f() fn: …`, `with`/`given` values) unspecified; `place` conflicts and omits `self` | high | T-0008, T-0009..T-0013 |
  | ADR-0014 | Generic arguments in expressions (`db.one[Tenant](…)`) do not parse; `type_arg = type \| expr` and `slice_or_index` are conflicts; `(T)` tuple type contradicts SYN-038; `-> fn() -> T using …` ambiguous; `dyn A + B` missing | high | T-0008, T-0009, T-0011, T-0030 |
  | Q-0001 | Parenthesised lambda heads vs tuples (not LR(1)); `&` accepts non-places | high | T-0011, T-0008 |
  | Q-0002 | Syntax used elsewhere but absent: `using` call args (CAP-032), `pub(package)` (PKG-003), `-> type`/`struct:` (CT-011/012 vs TYP-022), `@go_threadsafe T` (GO-032), no attribute list (SYN-023), `unsafe` block has no rule | high | T-0009, T-0011, T-0008 |
  | Q-0003 | Doc comments and ERR-002 discard comments are significant but comments produce no tokens; `doc_comment` undefined in EBNF | medium | T-0008, T-0009, T-0006 |
  | Q-0004 | `case None:` parses as a binding; `case Status.NotFound:` does not parse | high | T-0012, T-0032, T-0008 |
  | Q-0005 | Templates: `{2,62}` in `re"…"` is an interpolation; escapes, format specs (`{x:>8}`), keyword prefixes unspecified | high | T-0005, T-0055 |
  | Q-0006 | Literal details: `1__0` (task stricter than spec), `0755`, case of prefixes, `5.msg`, hex durations, no tuple access, char/byte escapes, dedent order | medium | T-0003, T-0004 |
  | Q-0007 | Block after a continuation line is E0021 (escalation.md example invalid); LEX-030b vs LEX-033 order; multi-line tokens | medium | T-0007 |
  | Q-0008 | `\|>` right-hand side shape unspecified (`x \|> f(a)?`, `xs \|> len == 0`) | medium | T-0011, T-0033 |
  | Q-0009 | SYN-031 literally rejects `Some(true)` and `assert(c)`; SYN-032 omits newtypes | medium | T-0031, T-0052 |
  | Q-0010 | let-else: ERR-012 "unwraps" vs TYP-062 refutable pattern; examples rely on unwrap | medium | T-0032, T-0051 |
  | Q-0011 | 11 small prose/EBNF mismatches (SYN-061 list, empty blocks, `pub impl`, `where` without `new`, …) | low | T-0009, T-0010 |
  | Q-0012 | Spec examples that do not parse; fragments need tagging for T-0015 | low | T-0015, T-0017 |

- Verification: transcribed the ADR-0013/0014 EBNF into a scratch Menhir grammar (not committed; simplified
  literals, patterns and bitwise levels): 0 conflicts. With the current `place` production: 2 reduce/reduce
  conflicts. With the current parenthesised `lambda_head`: 2 shift/reduce conflicts. The first draft of ADR-0014 had
  a real conflict (`using (A, B)` vs tuple type, then `using dyn A + B`), which this check found and fixed.
- `tools/check-spec.sh` fails on rule ids not yet in `spec/` anywhere under `docs/`, so the ADRs write new ids as
  `SYN 015` placeholders. Follow-up T-0025 (release-manager).
- No task was moved to `tasks/blocked/`: moving T-0003..T-0013 is outside this task's paths and several are claimed by
  other agents. The `blocking:` field of each Q lists them; the orchestrator decides.
- No SECURITY.md issue found. Q-0002 item 6 (`unsafe` has no rule) and Q-0005 (template escaping) should be seen by
  `security-reviewer`.

## Outcome

- Delivered 2 `Proposed` ADRs (`docs/adr/0013-layout-token-contract-and-block-ended-expressions.md`,
  `docs/adr/0014-generic-arguments-in-expressions-and-types.md`) with exact spec and EBNF edits, and 12 spec-questions
  `tasks/blocked/Q-0001..Q-0012` with options and recommendations. The table in the Log is the summary.
- No spec, code or test changes (protected paths untouched). Tests added: none (audit task).
- Rules covered: n/a. Follow-up: T-0025 (check-spec and Proposed ADR ids).
- Limitations: chapters 4–13 were read only for syntax they use, not audited for their own semantics. The LR(1) check
  is a simplified transcription; the parser tasks must still pass `menhir --explain` on the real grammar.
- Owner action needed: decide ADR-0013 and ADR-0014 before T-0009 starts (T-0008's AST shape depends on both), then
  Q-0001, Q-0002, Q-0004 and Q-0005 before T-0011/T-0012/T-0005.


