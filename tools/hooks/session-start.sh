#!/usr/bin/env bash
# SessionStart hook: prints a short orientation, added to the agent's context.
root="${CLAUDE_PROJECT_DIR:-.}"
phase="$(cat "$root/tasks/PHASE" 2>/dev/null || echo '?')"
count() { find "$root/tasks/$1" -maxdepth 1 -name 'T-*.md' 2>/dev/null | wc -l | tr -d ' '; }
branch="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null || echo detached)"
echo "Égide — phase ${phase}. Board: backlog $(count backlog), in-progress $(count in-progress), done $(count done), blocked $(count blocked)."
echo "Branch: ${branch}. Read AGENTS.md first. The spec in spec/ is law; protected paths are guarded by hooks."
