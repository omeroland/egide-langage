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

Cited ids that are not defined in spec/, and malformed ids (not PREFIX-NNN, as the runner rejects them), are listed
after the summary.

--strict exits 1 if a rule in scope lacks a positive or a negative test, or a test cites an unknown or malformed id.
Scope: the chapters/sections of all phases <= --phase (default: tasks/PHASE), see PHASE_CHAPTERS; --chapters 4,8.4,A
overrides it (chapter numbers, sections `N.M`, `A` for appendices). Exit status 2 on unusable input: bad option values,
missing root or tasks/PHASE, a spec without rules, a scope that selects no rule (never a silent pass).
"""
import argparse, pathlib, re, sys

RULE_DEF = re.compile(r"\*\*\[([A-Z]+-[0-9]{3})\]")
RULE_ID = re.compile(r"^[A-Z]+-[0-9]{3}$")
# Spec chapters ("NN") and sections ("NN.M") whose rules a phase must cover; the scope at phase N is the union of the
# entries of phases <= N. Derived from docs/roadmap.md, which names chapters only for phase 2 (ch. 4 and 9); the rest is
# inferred from the Scope column. Sections are used where one chapter spans phases: 8.1-8.3 (Result, ?, Option) are
# phase 2 and 8.4-8.5 (resources, panics) phase 3; 10.1 (modules, name resolution) and 13.1/13.4 (execution modes,
# diagnostics) are needed from phase 1, the rest of ch. 10 and 13 in phase 6. Appendices and ch. 1 only from phase 7.
PHASE_CHAPTERS = {
    0: ["02", "03"],
    1: ["10.1", "13.1", "13.4"],
    2: ["04", "09", "08.1", "08.2", "08.3"],
    3: ["05", "08.4", "08.5"],
    4: ["06", "12"],
    5: ["07", "11"],
    6: ["10", "13"],
}
LAST_PHASE = 8
SCOPE_TOKEN = re.compile(r"^(\d{1,2}(\.\d{1,2})?|A)$")
HEADING = re.compile(r"^#{2,6} (\d+)\.(\d+)\b")
TEST_DIRS = ["tests/conformance", "tests/security"]


def chapter_of(path):
    m = re.match(r"(\d+)-", path.name)
    return m.group(1) if m and path.parent.name != "appendix" else "A"


def spec_rules(root):
    """[(id, chapter, section)] in spec order: numbered chapters, then appendices; section is "NN.M" or None."""
    files = sorted((root / "spec").glob("[0-9]*.md")) + sorted((root / "spec" / "appendix").glob("*.md"))
    rules, seen = [], set()
    for f in files:
        section, fenced = None, False
        for line in f.read_bytes().decode("utf-8", errors="replace").split("\n"):
            if line.startswith("```"):
                fenced = not fenced
            m = None if fenced else HEADING.match(line)
            if m:
                section = f"{int(m.group(1)):02d}.{int(m.group(2))}"
            for rid in RULE_DEF.findall(line):
                if rid not in seen:
                    seen.add(rid)
                    rules.append((rid, chapter_of(f), section))
    return rules


def header(path):
    """(cited tokens, expect) from the leading block of blank/`#` lines, read as tools/conformance/header.ml does:
    lines end at LF only (a trailing CR is dropped), a leading BOM is ignored, ids are separated by `,` and space."""
    ids, expect = [], None
    text = path.read_bytes().decode("utf-8", errors="replace").removeprefix("\ufeff")
    for line in text.split("\n"):
        line = line.removesuffix("\r")
        if line and not line.startswith("#"):
            break
        m = re.match(r"# (spec|expect):(.*)$", line)
        if m and m.group(1) == "spec":
            ids += [t for t in re.split(r"[, ]+", m.group(2).strip(" ")) if t]
        elif m and expect is None:
            expect = m.group(2).strip()
    return ids, expect


def kind(expect):
    if expect and (expect.endswith("-pass") or expect.endswith("-fail") or expect == "run-panic"):
        return "neg" if not expect.endswith("-pass") else "pos"
    return None


def collect(root):
    """(counts per well-formed cited id, {malformed token: [files]})"""
    counts, malformed = {}, {}
    for d in TEST_DIRS:
        for p in sorted((root / d).rglob("*.egd")):
            ids, expect = header(p)
            for rid in dict.fromkeys(ids):
                if not RULE_ID.match(rid):
                    malformed.setdefault(rid, []).append(str(p.relative_to(root)))
                else:
                    counts.setdefault(rid, {"pos": 0, "neg": 0, "any": 0})
                    counts[rid]["any"] += 1
                    k = kind(expect)
                    if k:
                        counts[rid][k] += 1
                    counts[rid].setdefault("files", []).append(str(p.relative_to(root)))
    return counts, malformed


def scope_chapters(phase):
    if phase >= 7:
        return None  # every chapter and appendix
    return [c for p, chs in PHASE_CHAPTERS.items() if p <= phase for c in chs]


def norm_token(t):
    if t == "A":
        return t
    ch, _, sec = t.partition(".")
    return f"{int(ch):02d}" + (f".{int(sec)}" if sec else "")


class Usage(Exception):
    pass


def phase_arg(v):
    try:
        n = int(v)
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid phase {v!r}")
    if not 0 <= n <= LAST_PHASE:
        raise argparse.ArgumentTypeError(f"phase {n} out of range 0..{LAST_PHASE}")
    return n


def parse_chapters(v):
    toks = v.split(",")
    for t in toks:
        if not SCOPE_TOKEN.match(t.strip()):
            raise Usage(f"invalid --chapters entry {t!r} (expected a chapter `4`, a section `8.4` or `A`)")
    return [norm_token(t.strip()) for t in toks]


def in_scope(chs, chapter, section):
    return chs is None or chapter in chs or (section is not None and section in chs)


def run(a):
    root = pathlib.Path(a.root)
    if not (root / "spec").is_dir():
        raise Usage(f"{root}: no spec/ directory")
    rules = spec_rules(root)
    if not rules:
        raise Usage(f"no rule ids found in {root / 'spec'}")
    counts, malformed = collect(root)
    defined = {r for r, _, _ in rules}
    zero = {"pos": 0, "neg": 0, "any": 0}
    cnt = lambda r: counts.get(r, zero)

    chs = label = None
    if a.strict:
        if a.chapters is not None:
            chs = parse_chapters(a.chapters)
            label = "chapters " + ",".join(chs)
        else:
            phase = a.phase
            if phase is None:
                try:
                    phase = phase_arg((root / "tasks" / "PHASE").read_text().strip())
                except (OSError, argparse.ArgumentTypeError) as e:
                    raise Usage(f"cannot read the current phase from tasks/PHASE ({e}); use --phase N")
            chs = scope_chapters(phase)
            label = f"phase {phase}"
        if not any(in_scope(chs, c, s) for _, c, s in rules):
            raise Usage(f"no rule of the spec is in the scope of the strict check ({label})")

    print(f"{'RULE':<10} {'CH':<3} {'POS':>4} {'NEG':>4}")
    for rid, ch, _ in rules:
        c = cnt(rid)
        print(f"{rid:<10} {ch:<3} {c['pos']:>4} {c['neg']:>4}")
    n = len(rules)
    print()
    print(f"uncovered rules: {sum(1 for r, _, _ in rules if cnt(r)['any'] == 0)} / {n}")
    print(f"rules with a positive test: {sum(1 for r, _, _ in rules if cnt(r)['pos'])} / {n}")
    print(f"rules with a negative test: {sum(1 for r, _, _ in rules if cnt(r)['neg'])} / {n}")
    print(f"rules with both: {sum(1 for r, _, _ in rules if cnt(r)['pos'] and cnt(r)['neg'])} / {n}")
    unknown = sorted(set(counts) - defined)
    if unknown:
        print("\ntests citing unknown rule ids:")
        for rid in unknown:
            print(f"  {rid}: {', '.join(counts[rid]['files'])}")
    if malformed:
        print("\nmalformed rule ids in test headers (expected PREFIX-NNN):")
        for tok in sorted(malformed):
            print(f"  {tok!r}: {', '.join(malformed[tok])}")

    if not a.strict:
        return 0
    bad = []
    for rid, ch, sec in rules:
        if not in_scope(chs, ch, sec):
            continue
        c = cnt(rid)
        miss = [w for w, k in (("positive", "pos"), ("negative", "neg")) if not c[k]]
        if miss:
            bad.append(f"  {rid}: missing {' and '.join(miss)} test")
    print(f"\nstrict check ({label}): {len(bad)} rule(s) incomplete, {len(unknown)} unknown id(s), "
          f"{len(malformed)} malformed id(s)")
    print("\n".join(bad))
    return 1 if bad or unknown or malformed else 0


def main(argv):
    ap = argparse.ArgumentParser(prog="spec_coverage", description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parent.parent))
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--phase", type=phase_arg)
    ap.add_argument("--chapters")
    ap.add_argument("--coverage", action="store_true", help="accepted for symmetry with check-spec.sh")
    a = ap.parse_args(argv)  # exits 2 with `spec_coverage: error: ...` on bad option values
    try:
        return run(a)
    except Usage as e:
        print(f"spec_coverage: error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
