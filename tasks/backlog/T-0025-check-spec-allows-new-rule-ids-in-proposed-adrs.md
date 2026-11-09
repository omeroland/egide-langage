---
id: T-0025
title: check-spec allows new rule ids in Proposed ADRs
kind: task
phase: 0
role: release-manager
depends_on: [T-0020]
spec: []
paths: [tools/check-spec.sh]
estimate: S
labels: []
status: backlog
claimed_by:
claimed_at:
---

## Goal

A `Proposed` ADR can cite the rule ids it introduces (e.g. `SYN-015`) without failing `make ci`. Today
`tools/check-spec.sh` fails on any id referenced in `spec/` or `docs/` that is not defined in `spec/`. ADR authors
therefore write placeholders such as `SYN 015` (ADR-0013, ADR-0014), which reviewers cannot grep.

## Context

Found during T-0022. `docs/adr/README.md` asks ADRs to carry "the spec edits, with new rule ids". The reference check
covers `spec docs -r` without exception.

## Acceptance criteria

- [ ] Files under `docs/adr/` whose `- Status:` line is `Proposed` are excluded from the "referenced but undefined"
      check; `Accepted` ADRs and every other file stay checked
- [ ] A shell test or documented manual check shows both cases (Proposed ADR citing a new id passes; Accepted ADR
      citing an undefined id fails)

## Out of scope

Rewriting the placeholders in ADR-0013/0014 (the owner does that on acceptance).

## Log

## Outcome
