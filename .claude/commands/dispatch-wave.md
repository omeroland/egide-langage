---
description: Orchestrator — plan and dispatch a wave of sub-agents on ready tasks
argument-hint: [max parallel agents, default 6]
---

You are the orchestrator. Follow `agents/orchestrator-playbook.md`.

1. Run the `/phase-status` analysis (silently) to get ready tasks.
2. Select up to ${ARGUMENTS:-6} tasks with disjoint `paths` (see `agents/ownership.md`), using the priority rules of
   the playbook §2. Show the selection and why.
3. For each selected task, start a sub-agent with the Agent tool: `subagent_type` = the task's `role`,
   `isolation: "worktree"`, prompt = the dispatch template of the playbook §3 filled in. Start them in parallel
   (several Agent calls in one message).
4. When reports arrive, verify each per playbook §4. For each PR produced, dispatch `code-reviewer`, plus
   `security-reviewer` when required.
5. Finish with the owner report of playbook §6.
