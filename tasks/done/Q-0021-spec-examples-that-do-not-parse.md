---
id: Q-0021
rule: SYN-001, SYN-011, LEX-055, LEX-032, CT-011
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0015, T-0017]
severity: low
status: decided
---
## Question

T-0015 turns `egide` code blocks into parse tests. Several examples are invalid under the current spec, and most spec
blocks are fragments, not files. What does the extractor expect, and who fixes the invalid examples?

### Examples that are invalid under the spec

| Where | Problem | Fix (proposed) |
|-------|---------|----------------|
| `spec/05-values-and-memory.md` §5.1 | `assert a == [1, 2, 3]`: `assert` is not a keyword; juxtaposition is a syntax error | `assert(a == [1, 2, 3])` |
| `spec/05-values-and-memory.md` MEM-021 block | contains a deliberately erroneous line (`# error MEM-021`) | tag the block as invalid (below) |
| `examples/tenants_api.egd` | `re"…{2,62}$"`: `{2,62}` is an interpolation (Q-0014) | `{{2,62}}` |
| `agents/escalation.md` | trailing block after a continuation line: E0021 (Q-0016) | depends on Q-0016 |
| `spec/09-comptime.md` CT-011 | `-> type` and `struct:` are not in the grammar (Q-0011) | depends on Q-0011 |
| README, `examples/tenants_api.egd`, ch. 8 | let-else with an irrefutable pattern (Q-0019) | depends on Q-0019 |

### Fragments

Chapters 3 (§3.3, §3.5, SYN-062), 5, 6, 7, 8, 9 and 11 have blocks without `module` (SYN-001), with top-level
statements (`add_line(&cart, item)`, `select([...])`) or with a bare `match`. The SYN-062 block is also indented
inside a Markdown list item.

## Options

A. **Info-string tags** in the spec: ```` ```egide ```` is a complete file, ```` ```egide fragment ```` is a statement
   sequence that T-0015 wraps in `module spec.fragment` plus `fn fragment():`, ```` ```egide decls ```` is a
   declaration sequence that T-0015 wraps with a module line, and ```` ```egide invalid ```` is expected to fail.
   Tools strip the common indentation of list-item blocks.
B. No spec change: T-0015 tries the file wrapping, then the declaration wrapping, then the statement wrapping, and
   accepts the first that parses. Invalid examples are listed in an allow-list in `tests/`.

## Recommendation

A. Tags are explicit, are checked by CI, and make invalid examples visible. B would let a broken example silently
pass through a different wrapping. The spec edits (tags plus the `assert` fix) are mechanical, and the owner can apply
them in the same PR as ADR-0013. `examples/` and `agents/escalation.md` fixes go to their owners (`docs-writer`; the
owner for `agents/`).

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Option A. `spec/README.md` defines the info strings `egide`, `egide decls`, `egide fragment`, `egide invalid`; all blocks of chapters 2, 3, 5, 6, 7, 8, 9, 11 are tagged; `assert a == …` is `assert(a == …)`; the MEM-021 block is split into a `decls` and a `fragment` (its error line is semantic and parses); the SYN-015 negative example is an `invalid` block; `{2,62}` is `{{2,62}}` (Q-0014); let-else sites use `let Ok(…)`/`let Some(…)` (Q-0019); CT-011 no longer uses `-> type` (ADR-0015); the `agents/escalation.md` example is valid under Q-0016 B and needs no change.

ADR-0016. Files: spec/README.md, spec chapters, README.md, examples/tenants_api.egd. Tasks T-0015, T-0017 updated.
