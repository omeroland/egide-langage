---
id: T-1036
title: Comment trivia side table, doc-comment attachment and ERR-002 check
kind: task
phase: 0
role: syntax-engineer
depends_on: [T-0008, T-0009]
spec: [LEX-011, LEX-031, ERR-002]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Keep every comment in a trivia table (kind, span, text); attach `##` runs to declarations (LEX-011) with W0002 for stray ones; expose the comment that ends a statement's last line for the ERR-002 discard check.

## Context

Q-0012 option A, ADR-0016. The AST gets `doc : string option` on attachable nodes and a comment table in `Ast.file`. The ERR-002 check itself lands with the type checker (E0304); this task provides the lookup.

## Acceptance criteria

- [ ] Lexer returns comments alongside tokens; grammar and token stream are unchanged
- [ ] Attachment tests: module, struct, field, variant, trait item, impl item; blank line breaks it; stray `##` gives W0002
- [ ] `Trivia.comment_ending_line : int -> comment option` with tests

## Out of scope

Anything not listed in the acceptance criteria; create follow-up tasks.

## Log

2026-11-10 language-architect (owner-delegated, ADR-0017, security review resolution): ERR-002: the lookup returns the kind-`#` comment on the line of the statement's last token (not the first), never from inside strings; `##` does not count; reason needs a non-whitespace, non-Zs character. A never-read `Result` binding (`_x` too) is a discard (E0304).

2026-11-10 syntax-engineer (T-1030): T-1030 removed every `doc` field (`file.doc`, `decl`, `field`, `variant`, `trait_item`, `impl_item`) because nothing filled them. This task must reintroduce `doc : string option` on the module, declarations, fields, variants, trait items and impl items, plus the comment table (Q-0012 option A, ADR-0016: the parser attaches `##` runs to nodes), or record in its own Log a decision to keep docs out of the tree. Printer: add the `(doc "…")` atom back with its snapshots.

## Outcome
