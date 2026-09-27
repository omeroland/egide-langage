# ADR-0012: Development by a coordinated team of AI agents

- Status: Accepted
- Date: 2026-09-26

## Decision

The compiler is developed by Claude Code agents with specialised roles (`.claude/agents/`), coordinated through a
file-based task board (`tasks/`), git branches and pull requests. The human owner keeps three exclusive powers:
accepting ADRs (spec changes), merging to `main` for protected paths, and phase gate approval. Operating rules are in
`AGENTS.md` and `agents/`.

## Consequences

- The repository itself is the coordination medium: every decision and hand-off is a file or a commit.
- Guardrails are mechanical where possible (CI, hooks, CODEOWNERS), not only written.
