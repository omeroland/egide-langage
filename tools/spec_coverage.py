#!/usr/bin/env python3
"""Rule coverage report (T-0020). Normally invoked through `tools/check-spec.sh --coverage|--strict`.

Reads rule ids from spec/ (no id is hardcoded) and `# spec:` headers of tests under tests/conformance and
tests/security (tests/quarantine is ignored). Only the leading comment block of a test counts, as in the conformance
runner (tools/conformance/header.ml). A test is positive when its `# expect:` ends in `-pass`, negative when it ends
in `-fail` or is `run-panic`; tests with another or no expectation count for neither column.

Output (stable, one rule per line, in spec order):
    RULE  CH  POS  NEG
then summary lines starting with `uncovered rules:`, `rules with a positive test:`, `rules with a negative test:`,
`rules with both:`; then the list of cited ids not defined in spec/, if any.

--strict exits 1 if a rule in scope lacks a positive or a negative test, or a test cites an unknown id. Scope: the
chapters of all phases <= --phase (default: tasks/PHASE), see PHASE_CHAPTERS (derived from docs/roadmap.md);
--chapters 4,9 overrides it (empty = nothing in scope).
"""
import argparse, pathlib, re, sys

RULE_DEF = re.compile(r"\*\*\[([A-Z]+-[0-9]{3})\]")
RULE_ID = re.compile(r"^[A-Z]+-[0-9]{3}$")
# Spec chapters whose rules a phase must cover (docs/roadmap.md); scope at phase N is the union for phases <= N.
PHASE_CHAPTERS = {0: ["02", "03"], 2: ["04", "09"], 3: ["05", "08"], 4: ["06", "12"], 5: ["07", "11"], 6: ["10", "13"]}
TEST_DIRS = ["tests/conformance", "tests/security"]


def chapter_of(path):
    m = re.match(r"(\d+)-", path.name)
    return m.group(1) if m and path.parent.name != "appendix" else "A"


def spec_rules(root):
    """[(id, chapter)] in spec order: numbered chapters, then appendices."""
    files = sorted(p for p in (root / "spec").glob("[0-9]*.md")) + sorted((root / "spec" / "appendix").glob("*.md"))
    rules, seen = [], set()
    for f in files:
        for rid in RULE_DEF.findall(f.read_text(encoding="utf-8")):
            if rid not in seen:
                seen.add(rid)
                rules.append((rid, chapter_of(f)))
    return rules


def header(path):
    """(cited ids, expect) from the leading block of blank/`#` lines."""
    ids, expect = [], None
    for line in path.read_text(encoding="utf-8", errors="replace").lstrip("﻿").splitlines():
        line = line.rstrip("\r")
        if line and not line.startswith("#"):
            break
        m = re.match(r"# (spec|expect):(.*)$", line)
        if m and m.group(1) == "spec":
            ids += [t for t in re.split(r"[,\s]+", m.group(2).strip()) if t]
        elif m and expect is None:
            expect = m.group(2).strip()
    return ids, expect


def kind(expect):
    if expect and (expect.endswith("-pass") or expect.endswith("-fail") or expect == "run-panic"):
        return "neg" if not expect.endswith("-pass") else "pos"
    return None


def collect(root):
    counts, unknown = {}, {}
    for d in TEST_DIRS:
        for p in sorted((root / d).rglob("*.egd")):
            ids, expect = header(p)
            for rid in dict.fromkeys(ids):
                if RULE_ID.match(rid):
                    counts.setdefault(rid, {"pos": 0, "neg": 0, "any": 0})
                    counts[rid]["any"] += 1
                    k = kind(expect)
                    if k:
                        counts[rid][k] += 1
                    counts[rid].setdefault("files", []).append(str(p.relative_to(root)))
    return counts


def scope_chapters(phase):
    out = []
    for p, chs in PHASE_CHAPTERS.items():
        if p <= phase:
            out += chs
    return out if phase < 7 else None  # None = every chapter and appendix


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parent.parent))
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--phase", type=int)
    ap.add_argument("--chapters")
    ap.add_argument("--coverage", action="store_true", help="accepted for symmetry with check-spec.sh")
    a = ap.parse_args(argv)
    root = pathlib.Path(a.root)

    rules = spec_rules(root)
    counts = collect(root)
    defined = {r for r, _ in rules}
    zero = {"pos": 0, "neg": 0, "any": 0}
    cnt = lambda r: counts.get(r, zero)

    print(f"{'RULE':<10} {'CH':<3} {'POS':>4} {'NEG':>4}")
    for rid, ch in rules:
        c = cnt(rid)
        print(f"{rid:<10} {ch:<3} {c['pos']:>4} {c['neg']:>4}")
    n = len(rules)
    print()
    print(f"uncovered rules: {sum(1 for r, _ in rules if cnt(r)['any'] == 0)} / {n}")
    print(f"rules with a positive test: {sum(1 for r, _ in rules if cnt(r)['pos'])} / {n}")
    print(f"rules with a negative test: {sum(1 for r, _ in rules if cnt(r)['neg'])} / {n}")
    print(f"rules with both: {sum(1 for r, _ in rules if cnt(r)['pos'] and cnt(r)['neg'])} / {n}")
    unknown = sorted(set(counts) - defined)
    if unknown:
        print("\ntests citing unknown rule ids:")
        for rid in unknown:
            print(f"  {rid}: {', '.join(counts[rid]['files'])}")

    if not a.strict:
        return 0
    if a.chapters is not None:
        chs = [c.strip().zfill(2) for c in a.chapters.split(",") if c.strip()]
        label = "chapters " + (",".join(chs) or "none")
    else:
        phase = a.phase if a.phase is not None else int((root / "tasks" / "PHASE").read_text().strip())
        chs = scope_chapters(phase)
        label = f"phase {phase}"
    bad = []
    for rid, ch in rules:
        if chs is not None and ch not in chs:
            continue
        c = cnt(rid)
        miss = [w for w, k in (("positive", "pos"), ("negative", "neg")) if not c[k]]
        if miss:
            bad.append(f"  {rid}: missing {' and '.join(miss)} test")
    print(f"\nstrict check ({label}): {len(bad)} rule(s) incomplete, {len(unknown)} unknown id(s)")
    print("\n".join(bad))
    return 1 if bad or unknown else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
