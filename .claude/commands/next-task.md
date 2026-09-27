---
description: Find the next ready task for a role on the task board
argument-hint: <role>
---

Find the best ready task for role `$ARGUMENTS`.

1. Run `git fetch origin` and read `tasks/PHASE` on `origin/main`.
2. List files in `tasks/backlog/` whose front matter has `role: $ARGUMENTS` and `phase` ≤ current phase.
3. Keep only tasks whose every `depends_on` id is present in `tasks/done/` on `origin/main`, and for which no remote
   branch `t-<id>-*` exists (`git branch -r | grep -i t-<id>`).
4. Rank by: security label first, then critical path (tasks that others depend on), then lowest id.
5. Print the top 3 with id, title, dependencies, paths and cited rules, and recommend one. Do not claim it; use
   `/claim <id>` for that.
