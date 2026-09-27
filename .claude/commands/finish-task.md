---
description: Verify the Definition of Done, close the task file and mark the PR ready for review
---

For the task claimed on the current branch:

1. Run `make ci`. If it fails, stop and fix; do not continue.
2. Walk through `agents/definition-of-done.md` item by item and state, for each, the evidence (file, command output).
   If any item is not met, stop and list what is missing.
3. Fill the task file's `## Outcome` section (what was done, tests added, rules covered, follow-ups, limitations),
   `git mv` it to `tasks/done/`, set `status: done`.
4. Commit `chore(<id>): done`, push, fill the PR description from `.github/PULL_REQUEST_TEMPLATE.md`, mark ready for
   review, and state which reviewers are required (code-reviewer; security-reviewer when applicable per
   `agents/protocol.md` §4).
