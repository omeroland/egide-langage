"""Tests of tools/spec_coverage.py (T-0020) on fixture repositories in temp dirs. Run: python3 -I tools/tests/spec_coverage_test.py"""
import importlib.util, os, subprocess, sys, tempfile, unittest, pathlib

HERE = pathlib.Path(__file__).resolve().parent
TOOL = HERE.parent / "spec_coverage.py"
CHECK = HERE.parent / "check-spec.sh"


def make_repo(spec, tests, phase="0"):
    d = tempfile.mkdtemp()
    root = pathlib.Path(d)
    (root / "spec" / "appendix").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "tasks").mkdir()
    (root / "tasks" / "PHASE").write_text(phase + "\n")
    for name, text in spec.items():
        (root / "spec" / name).write_text(text)
    for name, text in tests.items():
        p = root / "tests" / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    return root


def run(root, *args):
    r = subprocess.run([sys.executable, "-I", str(TOOL), "--root", str(root), *args], capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


SPEC = {
    "02-lex.md": "# 2\n- **[LEX-001]** a.\n- **[LEX-002] Title.** b.\n",
    "04-types.md": "# 4\n- **[TYP-001]** c.\n",
    "appendix/a.md": "# A\n- **[GO-001]** d.\n",
}
TESTS = {
    "conformance/lexical/a.egd": "# spec: LEX-001, TYP-001\n# expect: lex-pass\nx\n",
    "conformance/lexical/b.egd": "# spec: LEX-001\n# expect: lex-fail\n# diagnostic: E0001 at 1:1\nx\n",
    "security/lexical/c.egd": "# spec: LEX-002\n# expect: compile-fail\nx\n",
    "quarantine/q.egd": "# spec: GO-001\n# expect: run-pass\nx\n",
    "conformance/lexical/late.egd": "x\n# spec: GO-001\n",
}


class Report(unittest.TestCase):
    def test_columns_and_counts(self):
        rc, out, _ = run(make_repo(SPEC, TESTS))
        self.assertEqual(rc, 0)
        rows = {l.split()[0]: l.split() for l in out.splitlines() if l[:1].isupper() and "-" in l.split()[0]}
        self.assertEqual(rows["LEX-001"][1:4], ["02", "1", "1"])
        self.assertEqual(rows["LEX-002"][1:4], ["02", "0", "1"])
        self.assertEqual(rows["TYP-001"][1:4], ["04", "1", "0"])
        self.assertEqual(rows["GO-001"][1:4], ["A", "0", "0"])  # quarantine and mid-file spec lines do not count

    def test_summary_lines(self):
        _, out, _ = run(make_repo(SPEC, TESTS))
        self.assertIn("uncovered rules: 1 / 4", out)
        self.assertIn("rules with a positive test: 2 / 4", out)
        self.assertIn("rules with a negative test: 2 / 4", out)
        self.assertIn("rules with both: 1 / 4", out)

    def test_unknown_ids_reported_not_fatal(self):
        t = dict(TESTS, **{"conformance/x.egd": "# spec: LEX-999\n# expect: lex-pass\n"})
        rc, out, _ = run(make_repo(SPEC, t))
        self.assertEqual(rc, 0)
        self.assertIn("LEX-999", out.split("tests citing unknown rule ids")[1])

    def test_no_hardcoded_ids(self):
        spec = {"02-z.md": "- **[ZZZ-007]** a.\n- **[QQ-123]** b.\n"}
        t = {"conformance/a.egd": "# spec: ZZZ-007\n# expect: run-panic\n"}
        _, out, _ = run(make_repo(spec, t))
        self.assertRegex(out, r"(?m)^ZZZ-007 +02 +0 +1")
        self.assertRegex(out, r"(?m)^QQ-123 +02 +0 +0")


class Strict(unittest.TestCase):
    def test_phase0_scope_is_ch2_3(self):
        # phase 0: only LEX-001/002 are in scope; LEX-002 lacks a positive test
        rc, out, _ = run(make_repo(SPEC, TESTS, "0"), "--strict")
        self.assertEqual(rc, 1)
        self.assertIn("LEX-002", out.split("strict")[-1])
        self.assertNotIn("TYP-001", out.split("strict")[-1])

    def test_strict_passes_when_both_kinds(self):
        t = dict(TESTS, **{"conformance/lexical/d.egd": "# spec: LEX-002\n# expect: lex-pass\n"})
        rc, _, _ = run(make_repo(SPEC, t, "0"), "--strict")
        self.assertEqual(rc, 0)

    def test_strict_phase_option_widens_scope(self):
        rc, out, _ = run(make_repo(SPEC, TESTS, "0"), "--strict", "--phase", "2")
        self.assertEqual(rc, 1)
        self.assertIn("TYP-001", out.split("strict")[-1])

    def test_chapters_override(self):
        rc, _, _ = run(make_repo(SPEC, TESTS), "--strict", "--chapters", "4")
        self.assertEqual(rc, 1)  # TYP-001 has only a positive test
        rc, _, _ = run(make_repo(SPEC, TESTS), "--strict", "--chapters", "")
        self.assertEqual(rc, 0)

    def test_strict_fails_on_unknown_ids(self):
        t = {"conformance/x.egd": "# spec: LEX-999\n# expect: lex-pass\n"}
        rc, _, _ = run(make_repo({"02-x.md": "- **[LEX-001]** a.\n"}, t), "--strict", "--chapters", "")
        self.assertEqual(rc, 1)


class Wrapper(unittest.TestCase):
    def sh(self, root, *args):
        env = dict(os.environ, EGIDE_ROOT=str(root))
        r = subprocess.run([str(CHECK), *args], capture_output=True, text=True, env=env)
        return r.returncode, r.stdout

    def test_coverage_flag_runs_report(self):
        rc, out = self.sh(make_repo(SPEC, TESTS), "--coverage")
        self.assertEqual(rc, 0)
        self.assertIn("uncovered rules: 1 / 4", out)

    def test_strict_flag_propagates_exit_status(self):
        rc, _ = self.sh(make_repo(SPEC, TESTS), "--strict")
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
