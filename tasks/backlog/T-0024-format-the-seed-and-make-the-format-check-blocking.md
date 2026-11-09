---
id: T-0024
title: Format the seed with ocamlformat and make the CI format check blocking
kind: task
phase: 0
role: release-manager
depends_on: [T-0001, T-0025]
spec: []
paths: [compiler/, .github/workflows/ci.yml]
estimate: S
labels: [good-first-task]
status: backlog
claimed_by:
claimed_at:
---

## Goal

The bootstrap session had no access to ocamlformat, so the OCaml seed is not guaranteed to be ocamlformat-clean and
the CI step `dune build @fmt` is temporarily `continue-on-error: true`. After this task, the code is formatted and the
step is blocking.

## Context

`.ocamlformat` pins version 0.26.2. The change to `.github/` is a protected path: open the PR from a
`governance/t-0024-fmt` branch for the owner to merge.

## Acceptance criteria

- [ ] `dune fmt` applied; `dune build @fmt` passes with ocamlformat 0.26.2
- [ ] `continue-on-error` removed from the CI format step
- [ ] `dune test` still passes (formatting may reflow `[%expect]` blocks: review the diff)

## Out of scope

Any semantic change.

## Log

## Outcome
