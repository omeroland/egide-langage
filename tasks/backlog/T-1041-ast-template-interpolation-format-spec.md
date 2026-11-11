---
id: T-1041
title: AST: template interpolation format spec and self-parameter shape
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-1030]
spec: [LEX-055, SYN-021]
paths: [compiler/lib/syntax/ast.ml, compiler/lib/syntax/ast.mli, compiler/lib/syntax/print.ml, compiler/test/syntax/]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Two places where the AST still allows what an accepted rule forbids or cannot hold what a rule defines, found while
doing T-1030 and left out because they are not in its acceptance criteria.

## Context

1. LEX-055 (ADR-0016, ADR-0017): an interpolation is `{expr[:spec]}`; the spec is a raw string without `{ } "` or a
   line break, and an empty spec `{x:}` is a spec. `template_part.Interp of expr` has nowhere to keep it. Change to
   `Interp of { expr : expr; spec : string option; spec_span : span option }` (decide the exact shape with T-0005,
   which produces the parts). Literal parts are raw (no escape decoding): update the comment on `Text`.
2. SYN-021 / Q-0020.9 (ADR-0015): the EBNF has `params = self_param { "," param } [ "," ] | param { "," param }`
   and `self_param = [ "inout" | "take" ] "self"`, so `self` is first and never `comptime`. `fn_sig.params : param list`
   with `param_kind = Param_self | Param_named` and `mode` including `Comptime` can represent `comptime self` and a
   `self` in the middle. Either make it unrepresentable (`self_param : self_mode option` plus `params`) or document
   that E0114 covers it; decide with T-1031.

## Acceptance criteria

- [ ] LEX-055 interpolation spec is representable; printer snapshot added
- [ ] `self` parameter shape decided and recorded in the Log (change or reason for keeping)

## Out of scope

The lexer side of LEX-055 (T-0005) and the E0114 check (T-1031).

## Log

## Outcome
