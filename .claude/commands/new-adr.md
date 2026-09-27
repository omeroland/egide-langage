---
description: Draft a new Architecture Decision Record proposal
argument-hint: <short title>
---

1. Find the next free ADR number in `docs/adr/`.
2. `git switch -c adr/<number>-<slug> origin/main`.
3. Copy `docs/adr/template.md` to `docs/adr/<number>-<slug>.md`, status `Proposed`, title `$ARGUMENTS`.
4. Fill Context (with a concrete Égide program), Decision, Alternatives, Consequences (complexity budget, security,
   implementation, migration).
5. Include the exact proposed edits to `spec/` in the same branch, with new rule ids, and add the ADR to the index in
   `docs/adr/README.md` with status Proposed.
6. Push and open a PR labelled `adr`. The human owner decides; never merge it yourself.
