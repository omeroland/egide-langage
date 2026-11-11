---
id: T-0009
title: Parser: declarations
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008, T-0007, T-1102, T-1104]
spec: [SYN-001, SYN-002, SYN-003, SYN-020, SYN-021, SYN-022, SYN-023]
paths: [compiler/lib/syntax/parser.mly, compiler/test/syntax/, tests/conformance/syntax/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Menhir rules for module, import (all forms incl. `import go`), fn signatures with modes, generics and `using`, struct, enum, trait, impl, type (alias/new/where), const, attributes.

## Context

Spec rules: SYN-001, SYN-002, SYN-003, SYN-020, SYN-021, SYN-022, SYN-023. See docs/architecture.md and the role file `.claude/agents/syntax-engineer.md`.

## Acceptance criteria

- [ ] Every declaration production has a parse-pass test; malformed forms have parse-fail tests
- [ ] `menhir --explain` reports 0 conflicts

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log
- 2026-11-10 language-architect: dependency on the ADR-0018 migration tasks added in PR #20 so that this task cannot start against the indentation grammar; T-1108 retargets its text.

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): Top-level `let` uses `const_block` (no unsafe/given/with); `pub(package)` counts as `pub` (TYP-003, CAP-034); one namespace for types and values; E0115 `import go` path is printable ASCII.

2026-11-10 language-architect (owner-delegated): spec/grammar/egide.ebnf is v0.3 (ADR-0013, ADR-0014, ADR-0015 accepted). Read `docs/adr/attachments/0013-menhir-check.mly` (0 conflicts) as the starting point for parser.mly, and do T-1030 (AST) first. Here: `suite`/layout contract LEX-036; `struct Name`/`impl T for U` without body; `visibility` incl. `pub(package)`; `params` with `self_param` first; `type_decl` where only after `new`; no top-level `comptime let`; no `pub impl`; `import` alias xor items; types per ADR-0014/TYP-006. Q-0002, Q-0011, Q-0020 are decided.

2026-11-10 syntax-engineer (T-1030): Q-0022 (tasks/blocked) blocks only `@go_threadsafe(reason: "…")`, whose argument the EBNF `attribute` cannot derive. Every other attribute parses, so this task can proceed with that one test carved out. The AST now has `Ti_type { bound : bound option }`, `bound` records, `visibility`, `Type.def`, `Import.form` (see T-1030 Log). E0105 (TYP-006, unparenthesised function type as a return type) has no owner: it is assigned to this task (types in declarations).

## Outcome


