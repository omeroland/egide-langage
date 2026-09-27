# Agent operating manual

This directory is the handbook for the AI agents (and humans) building Égide. Start with [`../AGENTS.md`](../AGENTS.md).

| File | Read it when |
|------|--------------|
| [`protocol.md`](protocol.md) | before claiming, finishing or reviewing any task |
| [`orchestrator-playbook.md`](orchestrator-playbook.md) | you are the main session coordinating sub-agents |
| [`definition-of-done.md`](definition-of-done.md) | before saying a task is done |
| [`review-checklist.md`](review-checklist.md) | you review a pull request |
| [`style-guide-ocaml.md`](style-guide-ocaml.md) | you write OCaml |
| [`ownership.md`](ownership.md) | you need to know which role may change a path |
| [`escalation.md`](escalation.md) | you are blocked, unsure, or found a security issue |

## Team structure

```
                         Human owner (Omeroland)
             accepts ADRs · merges protected paths · approves phase gates
                                   │
                          Orchestrator (main session)
                 plans waves · dispatches · verifies · reports
                                   │
   ┌──────────────┬────────────────┼─────────────────┬──────────────────┐
 Design        Frontend         Middle/back end     Library/tooling    Quality
 language-     syntax-          memory-semantics-   stdlib-engineer    test-engineer
 architect     engineer         engineer            tooling-engineer   code-reviewer
               type-system-     comptime-engineer   docs-writer        security-reviewer
               engineer         go-backend-engineer                    release-manager
               capability-      go-interop-engineer
               engineer         native-backend-engineer
```
