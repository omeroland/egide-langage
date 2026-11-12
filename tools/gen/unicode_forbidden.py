#!/usr/bin/env python3
"""Generates compiler/lib/source/forbidden_table.ml: the LEX-003 set (spec/02-lexical-structure.md, ADR-0017)

    Cf | Default_Ignorable_Code_Point | Variation_Selector | Noncharacter_Code_Point | {U+2028, U+2029} | Cc

from the Unicode 16.0.0 files DerivedCoreProperties.txt, PropList.txt and UnicodeData.txt.

The three files are never trusted: their SHA-256 digests must equal the ones pinned in
tools/gen/unicode-16.0.0.sha256, or the generator stops. Digests are recorded in the generated header.

Usage:
  python3 tools/gen/unicode_forbidden.py [--ucd-dir DIR] [--check]

  --ucd-dir DIR  directory holding the three files. Default: tools/gen/.ucd-cache (git-ignored); a missing file is
                 downloaded there from the sources below, in order, and verified before use.
  --check        write nothing; exit 1 if compiler/lib/source/forbidden_table.ml differs from what would be generated.

The generator only parses the upstream files. The test oracle (compiler/test/diagnostics/forbidden_oracle.ml)
deliberately shares no code with it."""
import argparse, hashlib, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PINS = os.path.join(ROOT, "tools", "gen", "unicode-16.0.0.sha256")
OUT = os.path.join(ROOT, "compiler", "lib", "source", "forbidden_table.ml")
VERSION = "16.0.0"
SOURCES = [  # tried in order; the pinned digest, not the URL, is the authority
    "https://www.unicode.org/Public/16.0.0/ucd/",
    "https://raw.githubusercontent.com/unicode-org/unicodetools/main/unicodetools/data/ucd/16.0.0/",
]
FILES = ["DerivedCoreProperties.txt", "PropList.txt", "UnicodeData.txt"]
MAX_CP = 0x10FFFF


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def read_pins():
    pins = {}
    with open(PINS, encoding="ascii") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                digest, name = line.split(None, 1)
                pins[name.strip()] = digest
    assert sorted(pins) == sorted(FILES), "pin file must list exactly " + ", ".join(FILES)
    return pins


def fetch(name, dest, pin):
    errors = []
    for base in SOURCES:
        try:
            with urllib.request.urlopen(base + name, timeout=60) as r:
                data = r.read()
        except Exception as e:  # network policy, DNS, 404 ...
            errors.append(f"{base}{name}: {e}")
            continue
        if hashlib.sha256(data).hexdigest() == pin:
            with open(dest, "wb") as f:
                f.write(data)
            return
        errors.append(f"{base}{name}: digest mismatch")
    sys.exit(f"cannot obtain {name} with the pinned digest:\n  " + "\n  ".join(errors))


def load(ucd_dir):
    pins = read_pins()
    os.makedirs(ucd_dir, exist_ok=True)
    paths = {}
    for name in FILES:
        p = os.path.join(ucd_dir, name)
        if not os.path.exists(p):
            fetch(name, p, pins[name])
        if sha256(p) != pins[name]:
            sys.exit(f"{p}: SHA-256 {sha256(p)} differs from the pinned {pins[name]}")
        paths[name] = p
    return paths, pins


def property_ranges(path, prop):
    """Ranges of `prop` in a PropList.txt / DerivedCoreProperties.txt layout: `XXXX[..YYYY] ; Prop # ...`."""
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            rng, name = (s.strip() for s in line.split(";", 1))
            if name != prop:
                continue
            lo, _, hi = rng.partition("..")
            out.append((int(lo, 16), int(hi or lo, 16)))
    assert out, prop
    return out


def category_ranges(path, cats):
    """Ranges whose General_Category is in `cats`, from UnicodeData.txt (handles `<..., First>` / `<..., Last>`)."""
    out, first = [], None
    with open(path, encoding="utf-8") as f:
        for line in f:
            fields = line.rstrip("\n").split(";")
            cp, name, gc = int(fields[0], 16), fields[1], fields[2]
            if name.endswith(", First>"):
                first = cp
                continue
            lo = first if name.endswith(", Last>") else cp
            first = None
            if gc in cats:
                out.append((lo, cp))
    assert out, cats
    return out


def merge(ranges):
    out = []
    for lo, hi in sorted(ranges):
        if out and lo <= out[-1][1] + 1:
            out[-1] = (out[-1][0], max(out[-1][1], hi))
        else:
            out.append((lo, hi))
    return out


def build(paths):
    ranges = []
    ranges += category_ranges(paths["UnicodeData.txt"], {"Cf", "Cc"})
    ranges += property_ranges(paths["DerivedCoreProperties.txt"], "Default_Ignorable_Code_Point")
    ranges += property_ranges(paths["PropList.txt"], "Variation_Selector")
    ranges += property_ranges(paths["PropList.txt"], "Noncharacter_Code_Point")
    ranges += [(0x2028, 0x2029)]  # Zl, Zp: line and paragraph separators
    merged = merge(ranges)
    assert merged[0][0] == 0 and merged[-1][1] <= MAX_CP
    return merged


def render(merged, pins):
    lines = [
        "(* GENERATED by tools/gen/unicode_forbidden.py -- do not edit; `tools/check-generated.sh` fails when stale.",
        "",
        f"   LEX-003 (spec/02-lexical-structure.md, ADR-0017, T-1033): Cf | Default_Ignorable_Code_Point |",
        f"   Variation_Selector | Noncharacter_Code_Point | U+2028, U+2029 | Cc, Unicode {VERSION}.",
        "   Embedded in the compiler; never read from the host (libc, ICU, runtime Unicode data).",
        "",
        "   Upstream files (SHA-256, pinned in tools/gen/unicode-16.0.0.sha256):",
    ]
    for name in FILES:
        lines.append(f"     {pins[name]}  {name}")
    lines += ["*)", "", '[@@@ocamlformat "disable"]', "", f'let unicode_version = "{VERSION}"', "", "let source_digests =", "  ["]
    for name in FILES:
        lines.append(f'    ("{name}", "{pins[name]}");')
    lines += [
        "  ]",
        "",
        "(* Sorted, disjoint, non-adjacent inclusive ranges, flattened: [lo0; hi0; lo1; hi1; ...]. *)",
        f"let ranges =",
        "  [|",
    ]
    for lo, hi in merged:
        lines.append(f"    0x{lo:04X}; 0x{hi:04X};")
    lines += ["  |]", ""]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ucd-dir", default=os.path.join(ROOT, "tools", "gen", ".ucd-cache"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    paths, pins = load(args.ucd_dir)
    text = render(build(paths), pins)
    if args.check:
        with open(OUT, encoding="utf-8") as f:
            if f.read() != text:
                sys.exit(f"{OUT} is stale: run python3 tools/gen/unicode_forbidden.py")
        return
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)


if __name__ == "__main__":
    main()
