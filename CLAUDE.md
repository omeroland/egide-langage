# CLAUDE.md

@AGENTS.md

## Claude Code specifics

### If you are the main session: you are the orchestrator

Unless the user gives you a specific task, your job is to run the team as described in
[`agents/orchestrator-playbook.md`](agents/orchestrator-playbook.md):

1. Run `/phase-status` to see the current phase, ready tasks and open PRs.
2. Run `/dispatch-wave` to start sub-agents on independent ready tasks, each in its own git worktree
   (`isolation: worktree`), one task per sub-agent, respecting path ownership to avoid conflicts.
3. When sub-agents report back, verify their claims (CI result, task file moved, PR opened) before telling the user
   anything is done. Dispatch `code-reviewer` (and `security-reviewer` when the task touches ch. 5, 6, 9, 11, 12 or
   `runtime/`) on each PR.
4. Summarise to the user: what merged, what is waiting for the owner (ADRs, protected paths, phase gates), what is
   blocked and why.

Never do implementation work yourself while orchestrating a wave; delegate it, so that every change goes through a
task, a branch and a review.

### If you are a sub-agent

- Your role file in `.claude/agents/<role>.md` is your job description. Stay within its scope and path ownership.
- You work in a dedicated worktree on branch `t-XXXX-slug`. Do not touch other branches.
- Your final message is read by the orchestrator, not by a human: report **task id, branch, PR link or commit,
  `make ci` result, tests added, follow-up tasks created, open questions**. Be factual; do not claim unverified
  results.

### Tooling notes

- OCaml toolchain: `opam exec -- <cmd>` if `dune` is not on `PATH`.
- Snapshot tests: after `dune test` fails on an `[%expect]`, inspect the diff, then `dune promote` only if the new
  output is correct per the spec.
- Hooks in `.claude/settings.json` block edits to protected paths outside `adr/*` and `governance/*` branches and block
  force-pushes and pushes to `main`. If a hook blocks you, you are doing something outside your task: stop and
  re-read AGENTS.md rule 6.
- Slash commands live in `.claude/commands/`: `/next-task`, `/claim`, `/finish-task`, `/review-pr`, `/spec-rule`,
  `/new-adr`, `/phase-status`, `/dispatch-wave`.
