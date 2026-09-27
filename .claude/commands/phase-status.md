---
description: Summarise the project state for the orchestrator
---

Produce a status report:

1. Current phase (`tasks/PHASE`) and its exit criteria from `docs/roadmap.md`, each marked met / not met / unknown
   with evidence.
2. Task board counts per folder, and the list of **ready** tasks (see `agents/protocol.md` §1) grouped by role.
3. In-progress tasks with `claimed_at` older than 48 h (stale).
4. Blocked tasks and open spec-questions.
5. Open PRs and their review state (use `gh pr list` if available).
6. CI status of `main` (last run), and `./tools/check-spec.sh --coverage` summary.
End with a recommended next wave (up to 6 tasks with disjoint paths, per `agents/orchestrator-playbook.md` §2).
