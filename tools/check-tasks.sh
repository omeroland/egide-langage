#!/usr/bin/env bash
# Validates the task board (tasks/README.md): front matter fields, unique ids, known dependencies,
# folder/status consistency, claims on in-progress tasks.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import os, re, sys
REQ = ["id","title","kind","phase","role","depends_on","spec","paths","estimate","labels","status"]
ROLES = {os.path.splitext(f)[0] for f in os.listdir(".claude/agents")}
errors, tasks = [], {}
for folder in ["backlog","in-progress","done","blocked"]:
    d = os.path.join("tasks", folder)
    for f in sorted(os.listdir(d)):
        if not f.startswith("T-"): continue
        text = open(os.path.join(d, f)).read()
        m = re.match(r"---\n(.*?)\n---\n", text, re.S)
        if not m: errors.append(f"{f}: missing front matter"); continue
        fm = {}
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1); fm[k.strip()] = v.strip()
        for k in REQ:
            if k not in fm: errors.append(f"{f}: missing field {k}")
        tid = fm.get("id","")
        if not f.startswith(tid + "-"): errors.append(f"{f}: file name does not start with id {tid}")
        if tid in tasks: errors.append(f"{f}: duplicate id {tid}")
        expected = {"backlog":"backlog","in-progress":"in-progress","done":"done","blocked":"blocked"}[folder]
        if fm.get("status") != expected: errors.append(f"{f}: status {fm.get('status')} but folder {folder}")
        if fm.get("role") not in ROLES: errors.append(f"{f}: unknown role {fm.get('role')}")
        if folder == "in-progress" and not fm.get("claimed_by"): errors.append(f"{f}: in-progress without claimed_by")
        deps = [x.strip() for x in fm.get("depends_on","[]").strip("[]").split(",") if x.strip()]
        tasks[tid] = deps
for tid, deps in tasks.items():
    for d in deps:
        if d not in tasks: errors.append(f"{tid}: unknown dependency {d}")
if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"tasks: {len(tasks)} task files valid")
PY
