# Task board

File-based, versioned with the code. Protocol: [`agents/protocol.md`](../agents/protocol.md).
Current phase: [`PHASE`](PHASE) (protected; bumped by the owner at each phase gate).

## Task file format

File name: `T-NNNN-short-slug.md`, in the folder matching its status.

```markdown
---
id: T-0003
title: Lexer — numeric and duration literals
kind: task            # task | epic (an epic must be split into tasks before anyone claims it)
phase: 0
role: syntax-engineer
depends_on: [T-0001]
spec: [LEX-040, LEX-041, LEX-042]
paths: [compiler/lib/syntax/, compiler/test/syntax/, tests/conformance/lexical/]
estimate: M           # S (< 200 lines) | M (< 400) | L (split it)
labels: []            # e.g. security, perf, good-first-task
status: backlog       # backlog | in-progress | done | blocked
claimed_by:
claimed_at:
---

## Goal
One paragraph: what exists after this task that did not before.

## Context
Pointers: spec sections, ADRs, architecture notes, related tasks.

## Acceptance criteria
- [ ] Verifiable statements (tests that pass, commands that output X).

## Out of scope
What not to do (goes to follow-up tasks).

## Log
- YYYY-MM-DD role: decisions, surprises.

## Outcome
Filled when done: summary, tests added, rules covered, follow-ups, limitations.
```

## Numbering

Ids are global and never reused. Ranges by phase keep the board readable: phase 0 → T-0001..0029,
phase 1 → T-0030..0049, phase 2 → T-0050..0059, phase 3 → T-0060..0069, phase 4 → T-0070..0079,
phase 5 → T-0080..0089 (plus T-0040), phase 6 → T-0090..0099, phase 7 → T-0100..0109, phase 8 → T-0110+.
When a range is full, continue at T-1000 and above.

`tools/check-tasks.sh` validates front matter, uniqueness, dependencies and folder/status consistency in CI.
