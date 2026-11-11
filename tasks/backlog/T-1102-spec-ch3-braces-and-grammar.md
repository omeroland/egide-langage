---
id: T-1102
title: Spec ch. 3, EBNF, ch. 1 heritage, spec/README wrappers
kind: task
phase: 0
role: language-architect
depends_on: [T-1100]
spec: [SYN-010, SYN-012, SYN-015, SYN-020, SYN-024, SYN-040, SYN-043, SYN-061, SYN-062, SYN-064, ERR-002]
paths: [spec/03-syntax.md, spec/grammar/egide.ebnf, spec/01-introduction.md, spec/README.md, spec/08-errors-and-resources.md]
estimate: M
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

Apply ADR-0018 section 5 to chapter 3, the EBNF (replacement block in the ADR; re-run `docs/adr/attachments/0018-check.py`, 0 conflicts required), the heritage table, the code-block wrappers and the ERR-002 line-end clause. SYN-061 and E0109 deleted.

## Context

ADR-0018 (Proposed): docs/adr/0018-surface-syntax-familiarity.md. Menhir transcription: docs/adr/attachments/0018-menhir-braces.mly.

## Acceptance criteria

- [ ] The change matches ADR-0018 section 5 as accepted by the owner
- [ ] `make ci` green

## Out of scope

Anything not listed above; create follow-up tasks.

## Log

## Outcome
