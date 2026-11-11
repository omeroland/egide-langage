---
id: T-1038
title: Security review of ADR-0015 and ADR-0016 decisions
kind: task
phase: 0
role: security-reviewer
depends_on: [T-1033]
spec: [LEX-003, LEX-055, CT-011, GO-032, ERR-012, SYN-017, SYN-053]
paths: [tests/security/]
estimate: S
labels: []
status: done
claimed_by:
claimed_at:
---

## Goal

Review the security-relevant decisions taken owner-delegated and add attack tests to tests/security/ (append-only).

## Context

Items: unsafe as a block-ended expression (SYN-017, MEM-070/071); removal of type-returning comptime functions (CT-011/012); `@go_threadsafe` as an attribute (GO-032); sink templates reject `:spec` and raw literal parts (LEX-055, E0601); let-else as pure matching (ERR-012); comptime generic value arguments (SYN-042, CT-001..004, CAP-041); no allowlist in LEX-003.

## Acceptance criteria

- [x] Written verdict per item in the task Outcome; objections become ADR proposals
- [x] Attack tests for the forbidden set (TAG, fillers, variation selectors), `:spec` on sinks, `return unsafe` placement

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): The review is posted (PR #14, #15). Resolution is ADR-0017. Remaining: add the review's PoC files to tests/security/ (append-only) once the rules are implemented, and re-review the SYN-018 / LEX-006 / GO-032 text.

## Outcome

Executive summary. The four blockers of the review of ADR-0015/ADR-0016 (S1, S2, #14-B1, #14-B2) are closed by the
text of ADR-0017 and by the 107 attack tests now in `tests/security/` (49 from PR #16, 58 added here), with residuals
listed below; nothing was implemented, so every verdict is on the spec text and the tests are phase-gated.

Evidence labels: *established* = spec text, a reproduction or a test; *extrapolated* = my inference.

Verdict per item of the task Context

| Item | Verdict | Basis |
|------|---------|-------|
| `unsafe` as a block-ended expression (SYN-017, MEM-070/071) | accepted | *established*: SYN-015 + grammar; reproduced with Menhir (`1 + unsafe…`, parenthesised `unsafe`, `return unsafe` are REJECT). SYN-018 closes the audit-output channel (S1). |
| Removal of type-returning comptime functions (CT-011/012) | accepted | Reduces the comptime attack surface; no objection. |
| `@go_threadsafe` as an attribute (GO-032) | accepted with conditions | B1 closed by E0420/E0421 and the manifest gate (PKG-030/031) *if* the manifest entry is made precise: Q-0022 items 3 and 4 (module name for std types, granularity, root self-allow) and the grammar defect of Q-0022 item 1 (`reason:` cannot be parsed by the EBNF `attribute`). |
| Sink templates reject `:spec` (LEX-055, E0601) | accepted | E0601 is keyed by result type; `:spec` can never reach a sink in a standard prefix. Residual: "sink type" must be transitive once a spec-grammar registration exists (Q-0022 item 9). |
| let-else as pure matching (ERR-012) | accepted | `egide audit` lists every `let … else` on a `Result`; swallow pattern remains a documented residual. |
| Comptime generic value arguments (SYN-042, CT-001..004, CAP-041) | accepted with conditions | Arguments are evaluated under CAP-040 and E0610. Residuals: E0610 names only top-level `let` and `comptime` arguments (Q-0022 item 7); purity through `dyn`/trait calls is unspecified (item 8); no bound on the number or depth of generic instantiations (availability only). |
| No allowlist in LEX-003 | accepted | Closed by property (Cf, DICP, Variation_Selector, noncharacters, U+2028/2029, Cc); *established* against `PropList-15.1.0.txt` (Other_Default_Ignorable_Code_Point lists exactly U+034F, 115F-1160, 17B4-17B5, 2065, 3164, FFA0, FFF0-FFF8, E0000, E0002-E001F, E0080-E00FF, E01F0-E0FFF); Unicode 16.0.0 equality of those ranges is *extrapolated* (the 16.0.0 files were not reachable from the review environment). |

Blockers: S1 closed (LEX-006, SYN-018; residual LEX-006 scope by origin, Q-0022 item 6; `trust` reason literal, item 5). S2 closed (LEX-003 by
property). #14-B1 closed on paper (GO-032 1-4; residuals above). #14-B2 closed at the head of the initialiser by the
grammar (`const_decl`/`const_block`, 0 conflicts reproduced; `unsafe`, `given`, `with` after `=` are REJECT) and for
nested occurrences by E0610 only (the grammar still accepts `unsafe` inside an `if` branch, a lambda body or a trailing
block of a top-level initialiser).

Tests added (this PR): 58 files. Lexical (LEX-003 gaps by property: U+17B4, 17B5, 2065, FFF0, FFF8, E0000, E001F,
E0080, E00FF, E01F0, E0FFF, noncharacters FDD0, FDEF, FFFE, 1FFFF, 10FFFF, C1 U+009F; two negative controls for
unassigned code points; two NBSP E0051 cases; LEX-055 E0044 cases and the nesting limit 8/9/300). Syntax (SYN-018 on
`unsafe` reasons and `import go` paths, attribute arguments, `@go_threadsafe` targets, top-level `let` heads, `using`
order). Semantics (E0610 nested and transitive, E0421 for `@go_threadsafe`, E0602, E0121, E0304 for a never-read
`Result` binding, E0120). Five are active now (`cp_c1_control_009f_string`, the two `cp_no_break_space_*` files, the two
`cp_unassigned_*_not_forbidden` controls): they pass against today's lexer and guard against regression. The
`toplevel_let_initialiser_*` files and `template_nesting_depth_8_accepted` also pass today, but only because the parser
and the template lexer are stubs, so they stay gated. The rest carry `# phase:` (1 lexer/parser, 2 checker and
comptime, 4 `using`, 6 manifest).
Positions are derived from the spec text, not from compiler output, except the active files, which were run.

Not committed (the spec fixes no diagnostic, and the files are append-only): `@go_threadsafe` with a missing,
non-string, duplicated or extra argument; on an alias of a non-Go type, an alias of an alias or `GoRef[T]`;
`Untrusted.trust(reason: <non-literal>)` and a `trust` reason with a terminal escape; `f(api: c)` for a `using api`
parameter; `if c: unsafe(…):` (SYN-061 gives no code); a raw tab or NUL escape in a reason; `let` with an irrefutable
pattern before `else`; an unknown upper-case pattern name. E0420 and a dependency-level E0421 need a package fixture
that the runner cannot express: task T-1159. All are listed in Q-0022.

Follow-ups: Q-0022 (spec questions, `tasks/blocked/`), T-1159 (runner: package fixtures).
Open questions: Q-0022 items 1-9.
