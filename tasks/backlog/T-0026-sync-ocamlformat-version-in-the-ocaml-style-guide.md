---
id: T-0026
title: Sync the ocamlformat version in the OCaml style guide (governance)
kind: task
phase: 0
role: release-manager
depends_on: [T-0025]
spec: []
paths: [agents/style-guide-ocaml.md]
estimate: S
labels: [good-first-task]
status: backlog
claimed_by:
claimed_at:
---

## Goal

`agents/style-guide-ocaml.md` names the same ocamlformat version as `.ocamlformat` and `dune-project`. T-0025 bumped
the pin from 0.26.2 to 0.28.1 (0.26.2 cannot be installed on OCaml 5.3), but the style guide still says 0.26.2 and
`agents/` is a protected path, so it could not be changed in T-0025.

## Context

- T-0025 (pin bump), AGENTS.md rule 6: `agents/` changes only on a `governance/*` branch, merged by the owner.
- Branch: `governance/t-0026-style-guide-ocamlformat`.

## Acceptance criteria

- [ ] The "Toolchain" bullet of `agents/style-guide-ocaml.md` names the version in `.ocamlformat` (0.28.1).
- [ ] Optional, owner's call: replace the literal version by "the version pinned in `.ocamlformat`" so that the next
      bump does not need another governance change.

## Out of scope

Any other style-guide change.

## Log

- 2026-11-09 release-manager: created as a follow-up of T-0025.

## Outcome
