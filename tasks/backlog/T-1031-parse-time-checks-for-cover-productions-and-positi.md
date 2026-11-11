---
id: T-1031
title: Parse-time checks for COVER productions and positional rules
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0011, T-0012]
spec: [SYN-005, SYN-012, SYN-017, SYN-021, SYN-023, SYN-024, SYN-033, SYN-037, SYN-053, SYN-065]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/syntax/, docs/diagnostics.md]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Implement the post-parse checks that the grammar delegates (SYN-005): E0104, E0106, E0107, E0108, E0109, E0110, E0111, E0112, E0113, E0114, E0116, E0117.

## Context

Rules and diagnostic templates are in spec/03-syntax.md and docs/diagnostics.md (allocated by ADR-0015). Each check needs one positive and one negative conformance test citing the rule.

## Acceptance criteria

- [ ] One check per diagnostic above, with the span and hint in the catalogue
- [ ] Block-ended expression placement (E0104) for every position listed in SYN-015
- [ ] Place check shared by assignment and `&` arguments (E0106); pipeline shape (E0108)
- [ ] `docs/diagnostics.md` rows move from `allocated` to `implemented`
- [ ] 0 Menhir conflicts is kept

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): Add: cover checks (E0106, E0107) run inside the Menhir semantic actions, not in a separate traversal (SYN-005); PoCs cover_in_attribute_arg, cover_in_default_param, cover_in_generic_arg, cover_inout_arg_paren become conformance tests. Also E0110/E0115/E0118 (SYN-018 shape of tool strings, checked on the value after escapes), E0119 (nesting limit 256, SYN-006), E0120 (`using` arguments, SYN-030), E0121 (SYN-053 lowercase typo), `&(x)`/`(x) = 1` are E0106, top-level `let` restricted by the grammar (const_block). Diff the Menhir attachment against the EBNF mechanically.

2026-11-10 syntax-engineer (T-1030 review): (1) E0121 is not a parse-time check: it concerns an *unused* lowercase binding equal to a variant name ignoring case, which needs types and use information; T-0012's Log gives it to T-0032. Remove it from this task's list. (2) E0105 (TYP-006) is in docs/diagnostics.md but in no task: T-0009 owns it (types in declarations), this task only tests it if T-0009 has not. (3) E0104 on a top-level `let X = unsafe(…):` (`unsafe`/`given`/`with` are not a `const_block`): SYN-015 calls it a grammar restriction, ADR-0017 says E0104; see Q-0024 for the diagnostic. Add the negative conformance test; it has no PoC under tests/security/syntax. (4) `_x` as a pattern: Q-0023.

## Outcome
