#!/usr/bin/env bash
# PreToolUse hook: blocks edits to protected paths (AGENTS.md rule 6) unless the current git branch is
# adr/* or governance/*. New Proposed ADRs and tests/security additions are allowed on any branch.
# Input: Claude Code hook JSON on stdin. Exit 2 = block (stderr is shown to the agent).
set -euo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path") or d.get("tool_input",{}).get("notebook_path") or "")')"
[ -z "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
rel="${file#"$root"/}"
branch="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null || echo detached)"

case "$branch" in adr/*|governance/*) exit 0 ;; esac

# New ADR proposals may be created anywhere; existing ADRs may not be edited.
if [[ "$rel" == docs/adr/[0-9][0-9][0-9][0-9]-*.md && ! -e "$root/$rel" ]]; then exit 0; fi
# tests/security is append-only: creating new files is allowed, editing existing ones is not.
if [[ "$rel" == tests/security/* && ! -e "$root/$rel" ]]; then exit 0; fi

case "$rel" in
  spec/*|docs/adr/*|AGENTS.md|CLAUDE.md|.claude/*|agents/*|tools/hooks/*|.github/*|tests/security/*|tasks/PHASE)
    echo "BLOCKED: '$rel' is a protected path (AGENTS.md rule 6). Current branch '$branch'." >&2
    echo "Spec changes need an ADR (/new-adr) on an adr/* branch; governance changes go on governance/*." >&2
    echo "If you think the spec is wrong or unclear, write a spec-question (agents/escalation.md)." >&2
    exit 2 ;;
esac
exit 0
