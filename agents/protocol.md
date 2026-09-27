# Coordination protocol

The repository is the only shared memory of the team. Every coordination step is a file change or a git operation, so
that any agent (or human) can reconstruct the state of the project from `main` and the open pull requests.

## 1. Task board

```
tasks/
├── backlog/       ready or waiting tasks, one file per task: T-NNNN-slug.md
├── in-progress/   claimed tasks (the claim is the lock)
├── done/          completed tasks, with their Outcome section filled
├── blocked/       tasks waiting on a decision (ADR, spec-question, owner)
└── security/      private security reports (see SECURITY.md) — never on public branches
```

The task file format is defined in [`tasks/README.md`](../tasks/README.md).

A task is **ready** when:
- it is in `tasks/backlog/`;
- every id in `depends_on` is in `tasks/done/` on `main`;
- its `phase` ≤ the current phase (in `tasks/PHASE`);
- no open PR already references it.

## 2. Claiming (the lock)

1. `git fetch origin && git switch -c t-NNNN-slug origin/main`
2. `git mv tasks/backlog/T-NNNN-slug.md tasks/in-progress/`
3. Set `status: in-progress`, `claimed_by: <role>/<session-id>`, `claimed_at: <UTC ISO date>` in the front matter.
4. Commit `chore(T-NNNN): claim` and **push the branch immediately**, then open a **draft PR** titled
   `T-NNNN: <title>`. The draft PR is the visible lock.
5. If the push or PR creation reveals another claim on the same task (branch or PR already exists), abandon yours:
   delete your branch and pick another task. First pushed claim wins.

## 3. While working

- Commit early and often with Conventional Commits scoped by the task id: `feat(T-0003): …`, `test(T-0003): …`.
- Stay inside the task's `paths`. Need to change something else? Create a follow-up task file in `tasks/backlog/`
  (next free id, `depends_on` set appropriately) in your PR, and mention it.
- Append to the task's **Log** section any decision, surprise or trade-off a reviewer should know.
- **Heartbeat:** a claim with no commit for 48 h is stale. The orchestrator may release it (move the file back to
  `backlog/` with a log line) and close the draft PR.

## 4. Finishing

1. `make ci` green locally.
2. Fill the task's **Outcome** section: what was done, tests added (paths), rules covered, follow-ups created,
   known limitations.
3. `git mv tasks/in-progress/T-NNNN-slug.md tasks/done/` and set `status: done`.
4. Mark the PR ready for review using the PR template; request `code-reviewer`; request `security-reviewer` if the task
   touches spec chapters 5, 6, 9, 11 or 12, `runtime/`, `tests/security/` or the Go purity list.

## 5. Review and merge

- Reviewers comment in the PR using the checklist in [`review-checklist.md`](review-checklist.md) and end with a verdict:
  `APPROVE`, `REQUEST_CHANGES` (with a numbered list) or `ESCALATE` (needs the owner or an ADR).
- The author addresses every numbered item with a commit or a reasoned reply. No force-push after review started.
- **Merge rules:** squash-merge, green CI, at least one `APPROVE` from `code-reviewer`, plus `security-reviewer` when
  required. PRs touching protected paths (AGENTS.md rule 6) are merged **only by the human owner**.
- After merge, the author (or the orchestrator) deletes the branch.

## 6. Conflicts between agents

- **Path conflicts**: the orchestrator never runs two tasks that own overlapping paths in the same wave
  ([`ownership.md`](ownership.md)). If you still hit a conflict, rebase on `main`; if the conflict is semantic
  (someone changed an interface you depend on), stop and write it in the task log, then ask the orchestrator.
- **Interface changes** to a module used by other libraries (its `.mli`) require a note in the PR description under
  "Interface changes" and the `code-reviewer` checks all callers were updated.
- **Disagreements** about behaviour are settled by the spec; if the spec does not settle it, by a `spec-question`
  answered by the `language-architect`; if that is not enough, by an ADR decided by the owner.

## 7. Communication artefacts

| Artefact | Where | When |
|----------|-------|------|
| Task log | the task file, `## Log` | any decision during the task |
| Spec question | `tasks/blocked/Q-NNNN-slug.md` | the spec is ambiguous or contradictory |
| ADR proposal | `docs/adr/NNNN-*.md` on branch `adr/NNNN-slug` | a language or architecture change is needed |
| Follow-up task | `tasks/backlog/T-NNNN-*.md` | work discovered outside your scope |
| Security report | `tasks/security/` on a private branch + owner notification | any SECURITY.md issue |
| Phase gate report | `docs/phase-reports/phase-N.md` | written by `release-manager` at phase exit |
