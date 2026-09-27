#!/usr/bin/env bash
# PreToolUse hook for Bash: blocks history rewriting and direct pushes to main (defence in depth on top of
# the permission deny-list in .claude/settings.json).
set -euo pipefail
cmd="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"

block() { echo "BLOCKED: $1 (agents/escalation.md: things you must never do)." >&2; exit 2; }

[[ "$cmd" =~ git[[:space:]]+push.*(--force|[[:space:]]-f([[:space:]]|$)|--force-with-lease) ]] && block "force push"
[[ "$cmd" =~ git[[:space:]]+push.*[[:space:]](main|master)([[:space:]]|$) ]] && block "push to main"
[[ "$cmd" =~ git[[:space:]]+push.*:main ]] && block "push to main"
[[ "$cmd" =~ git[[:space:]]+(filter-branch|filter-repo) ]] && block "history rewrite"
[[ "$cmd" =~ gh[[:space:]]+(pr[[:space:]]+merge|release|repo[[:space:]]+(delete|edit)) ]] && block "merge/release/repo settings are owner-only"
[[ "$cmd" =~ --no-verify ]] && block "skipping git hooks"
exit 0
