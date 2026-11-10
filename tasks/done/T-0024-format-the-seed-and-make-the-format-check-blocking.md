---
id: T-0024
title: Format the seed with ocamlformat and make the CI format check blocking
kind: task
phase: 0
role: release-manager
depends_on: [T-0001, T-0028]
spec: []
paths: [compiler/, .github/workflows/ci.yml]
estimate: S
labels: [good-first-task]
status: done
claimed_by: release-manager/wave2
claimed_at: 2026-11-10
---

## Goal

The bootstrap session had no access to ocamlformat, so the OCaml seed is not guaranteed to be ocamlformat-clean and
the CI step `dune build @fmt` is temporarily `continue-on-error: true`. After this task, the code is formatted and the
step is blocking.

## Context

`.ocamlformat` pins version 0.28.1. The change to `.github/` is a protected path: open the PR from a
`governance/t-0024-fmt` branch for the owner to merge.

## Acceptance criteria

- [x] `dune fmt` applied; `dune build @fmt` passes with ocamlformat 0.28.1
- [x] `continue-on-error` removed from the CI format step
- [x] `dune test` still passes (formatting may reflow `[%expect]` blocks: review the diff)

## Out of scope

Any semantic change.

## Log

- 2026-11-10: ocamlformat 0.28.1 cannot be built in the agents' sandbox (dependency `fix` is hosted on
  gitlab.inria.fr, blocked by the proxy). Owner delegated the CI route: a temporary workflow `fmt-bot.yml` (push to
  this branch only) ran `dune fmt` with the CI-installed ocamlformat 0.28.1 and pushed commit 654348f as
  github-actions[bot]. The workflow is deleted in the PR head and must not be merged.
- Formatting commit: 47 files, +1228/-635, formatting only (also blank lines after comments in 4 `dune` files).
  `dune test` and `make ci` pass locally after the bot commit; no `[%expect]` promotion was needed.

## Outcome

Seed formatted with ocamlformat 0.28.1; `continue-on-error` removed so the `dune build @fmt` step is blocking.
Open PRs touching OCaml files need a rebase onto this change (run `dune fmt` after rebasing to resolve conflicts).
