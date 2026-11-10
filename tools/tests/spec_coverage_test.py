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

    def test_cumulative_scope(self):
        # LEX-002 (ch. 2, phase 0) lacks a positive test and must stay in scope at --phase 2 (union of phases <= N)
        _, out, _ = run(make_repo(SPEC, TESTS, "0"), "--strict", "--phase", "2")
        self.assertIn("LEX-002", out.split("strict")[-1])
        self.assertIn("TYP-001", out.split("strict")[-1])

    def test_chapters_override(self):
        rc, out, _ = run(make_repo(SPEC, TESTS), "--strict", "--chapters", "4")
        self.assertEqual(rc, 1)  # TYP-001 has only a positive test
        self.assertNotIn("LEX-002", out.split("strict")[-1])
        rc, _, _ = run(make_repo(SPEC, TESTS), "--strict", "--chapters", "2,04")
        self.assertEqual(rc, 1)
        t = dict(TESTS, **{"conformance/d.egd": "# spec: LEX-002, TYP-001\n# expect: lex-pass\n",
                           "conformance/e.egd": "# spec: TYP-001\n# expect: lex-fail\n"})
        rc, _, _ = run(make_repo(SPEC, t), "--strict", "--chapters", "2,04")
        self.assertEqual(rc, 0)

    def test_section_scope(self):
        spec = {"08-err.md": "# 8\n## 8.1 A\n- **[ERR-001]** a.\n## 8.4 R\n- **[ERR-040]** b.\n",
                "02-lex.md": "- **[LEX-001]** x.\n"}
        _, out, _ = run(make_repo(spec, {}), "--strict", "--phase", "2")
        tail = out.split("strict")[-1]
        self.assertIn("ERR-001", tail)       # 8.1-8.3 are phase 2
        self.assertNotIn("ERR-040", tail)    # 8.4 is phase 3
        _, out, _ = run(make_repo(spec, {}), "--strict", "--phase", "3")
        self.assertIn("ERR-040", out.split("strict")[-1])
        _, out, _ = run(make_repo(spec, {}), "--strict", "--chapters", "8.4")
        tail = out.split("strict")[-1]
        self.assertIn("ERR-040", tail)
        self.assertNotIn("ERR-001", tail)

    def test_strict_fails_on_unknown_ids(self):
        t = dict(TESTS, **{"conformance/x.egd": "# spec: LEX-999\n# expect: lex-pass\n",
                           "conformance/d.egd": "# spec: LEX-002\n# expect: lex-pass\n"})
        rc, _, _ = run(make_repo(SPEC, t), "--strict", "--chapters", "2")
        self.assertEqual(rc, 1)

    def test_strict_fails_on_malformed_ids(self):
        t = dict(TESTS, **{"conformance/d.egd": "# spec: LEX-002, LEX-01\n# expect: lex-pass\n"})
        rc, out, _ = run(make_repo(SPEC, t), "--strict", "--chapters", "2")
        self.assertEqual(rc, 1)
        self.assertIn("LEX-01", out)


class Header(unittest.TestCase):
    """Headers are read as the conformance runner does (tools/conformance/header.ml): lines split on LF only."""

    def rows(self, text):
        _, out, _ = run(make_repo({"02-x.md": "- **[LEX-001]** a.\n"}, {"conformance/h.egd": text}))
        return out

    def test_unicode_line_separator_is_not_a_line_break(self):
        for sep in ("\t", "\u2028", "\u2029", "\u0085", "\x0b", "\x0c", "\x1c"):
            out = self.rows(f"# spec: LEX-001{sep}# expect: lex-pass\nx\n")
            self.assertRegex(out, r"(?m)^LEX-001 +02 +0 +0", repr(sep))  # runner rejects the id: not counted
            self.assertIn("malformed rule ids", out, repr(sep))
            # a separator glued to an id makes the id invalid for the runner, so the test must not count
            out = self.rows(f"# spec: LEX-001{sep}\n# expect: lex-pass\nx\n")
            self.assertRegex(out, r"(?m)^LEX-001 +02 +0 +0", repr(sep))

    def test_crlf_is_accepted(self):
        out = self.rows("# spec: LEX-001\r\n# expect: lex-pass\r\nx\r\n")
        self.assertRegex(out, r"(?m)^LEX-001 +02 +1 +0")

    def test_lone_cr_is_not_a_line_break(self):
        out = self.rows("# spec: LEX-001\r# expect: lex-pass\nx\n")
        self.assertRegex(out, r"(?m)^LEX-001 +02 +0 +0")

    def test_malformed_ids_reported(self):
        for bad in ("LEX-01", "lex-001", "LEX-0011", "LEX001"):
            out = self.rows(f"# spec: LEX-001, {bad}\n# expect: lex-pass\n")
            self.assertRegex(out, r"(?m)^LEX-001 +02 +1 +0")
            self.assertIn("malformed rule ids in test headers", out)
            self.assertIn(bad, out.split("malformed rule ids in test headers")[1])


class BadInput(unittest.TestCase):
    def fails(self, root, *args):
        rc, out, err = run(root, *args)
        self.assertEqual(rc, 2, (args, out, err))
        self.assertIn("spec_coverage: error:", err)
        return err

    def test_bad_chapters(self):
        for bad in ("abc", "", "2,,4", "2.x", "100", "-1"):
            self.fails(make_repo(SPEC, TESTS), "--strict", "--chapters", bad)

    def test_bad_phase(self):
        for bad in ("-1", "9", "x"):
            self.fails(make_repo(SPEC, TESTS), "--strict", "--phase", bad)

    def test_bad_phase_file(self):
        r = make_repo(SPEC, TESTS, "banana")
        self.fails(r, "--strict")

    def test_missing_root(self):
        self.fails("/nonexistent/egide-root")

    def test_no_rules_in_spec(self):
        self.fails(make_repo({"02-x.md": "no rules here\n"}, {}))
        self.fails(make_repo({}, {}), "--strict")

    def test_empty_scope(self):
        err = self.fails(make_repo(SPEC, TESTS), "--strict", "--chapters", "09")
        self.assertIn("no rule", err)
        self.fails(make_repo({"04-t.md": "- **[TYP-001]** x.\n"}, {}), "--strict", "--phase", "0")


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

    def test_phase_and_chapters_are_passed_through(self):
        r = make_repo(SPEC, TESTS, "0")
        _, out = self.sh(r, "--strict", "--phase", "2")
        self.assertIn("strict check (phase 2)", out)
        self.assertIn("TYP-001", out.split("strict")[-1])
        _, out = self.sh(r, "--strict", "--chapters", "4")
        self.assertIn("strict check (chapters 04)", out)
        rc, _ = self.sh(r, "--strict", "--chapters", "abc")
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
