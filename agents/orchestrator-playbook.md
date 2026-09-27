# Orchestrator playbook

The orchestrator is the main Claude Code session. It plans waves of parallel work, dispatches sub-agents, verifies
their results and reports to the human owner. It does not write compiler code during a wave.

## 1. The loop

```
┌─► 1. Sync: git fetch; read tasks/PHASE, tasks/*, open PRs, CI status of main
│   2. Triage: stale claims (> 48 h), failing main, PRs waiting for review, blocked tasks answerable now
│   3. Plan a wave: choose up to N ready tasks with disjoint path ownership (N = 6 by default)
│   4. Dispatch: one sub-agent per task, role = task.role, isolation = worktree
│   5. Review: dispatch code-reviewer (+ security-reviewer) on each PR produced
│   6. Integrate: merge approved non-protected PRs (squash), in dependency order; rebase the others
│   7. Report to the owner: merged, waiting for owner, blocked, next wave
└── 8. Repeat until no ready task remains or the owner stops the loop
```

## 2. Choosing a wave

1. Priority order: (a) `main` is red → a `release-manager` task to fix it, alone; (b) security tasks;
   (c) tasks on the critical path of the current phase (longest dependency chain to the phase exit criteria);
   (d) test-coverage tasks; (e) the rest.
2. Two tasks may run in the same wave only if their `paths` do not overlap and neither depends on the other.
3. Mix roles: a wave with six `syntax-engineer` tasks will conflict in `parser.mly`; prefer breadth.
4. Never schedule a task whose phase is greater than `tasks/PHASE`.

## 3. Dispatch prompt template

Use this exact structure when starting a sub-agent (Agent tool, `subagent_type` = the role, isolation `worktree`):

```
You are the <role> on the Égide team. Read AGENTS.md and .claude/agents/<role>.md first.
Task: <task id> — <title>. The task file is tasks/backlog/<file>.
1. Claim it following agents/protocol.md §2 (branch t-<id>-<slug>, draft PR).
2. Read the spec rules it cites: <rule ids>. Read docs/architecture.md sections for: <passes>.
3. Write failing tests first, implement, run `make ci`.
4. Finish per agents/protocol.md §4 and open the PR for review.
Report back: task id, branch, PR URL, `make ci` result (paste the summary line), tests added, rules covered,
follow-up tasks created, open questions. If blocked, stop and report why instead of improvising.
```

## 4. Verifying sub-agent reports

Never relay "done" without checking:
- the PR exists and CI is green (or run `make ci` in the worktree);
- the task file is in `tasks/done/` in the PR with an Outcome section;
- tests cite rule ids and fail without the implementation (spot-check with `git stash` on one test for critical tasks).

A report that claims results you cannot confirm is treated as not done; re-dispatch with the discrepancy explained.

## 5. Things only the owner decides

- Accepting or rejecting ADRs (spec changes).
- Merging PRs that touch protected paths.
- Phase gates: `release-manager` writes `docs/phase-reports/phase-N.md`; the owner approves by merging the PR that
  bumps `tasks/PHASE`.
- Security disclosures and anything involving credentials, publishing, or external accounts.

## 6. Reporting to the owner

End every loop with a short report:

```
Wave <n> — phase <p>
Merged: T-0003 (layout algorithm), T-0005 (diagnostics JSON)
Waiting for you: ADR-0013 (proposed: string interpolation of Secret), PR #41 touches .github/
Blocked: T-0012 on Q-0002 (spec ambiguity in SYN-062: trailing block after method chain)
Next wave: T-0006, T-0007, T-0010, T-0011
```
