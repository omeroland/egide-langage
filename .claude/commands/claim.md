---
description: Claim a task (creates branch, moves the task file, pushes, opens a draft PR)
argument-hint: <task-id e.g. T-0003>
---

Claim task `$ARGUMENTS` following `agents/protocol.md` §2 exactly:

1. `git fetch origin`; verify the task is still in `tasks/backlog/` on `origin/main` and no branch `t-<id>-*` exists.
2. `git switch -c t-<id-lowercase-digits>-<slug> origin/main` (slug from the file name).
3. `git mv tasks/backlog/<file> tasks/in-progress/`; set `status: in-progress`, `claimed_by`, `claimed_at` (UTC).
4. Commit `chore(<id>): claim`, push with upstream, open a draft PR titled `<id>: <title>` (use `gh pr create --draft`
   if available; otherwise report that the PR must be opened manually).
5. If any step reveals a competing claim, undo (delete the local branch) and report it.
