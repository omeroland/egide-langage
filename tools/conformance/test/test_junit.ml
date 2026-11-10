(* Tests of the JUnit XML report. *)

open Egide_conformance

let%expect_test "one testsuite per directory, failures and skips" =
  print_string
    (Junit.to_xml
       [
         { file = "tests/a/x.egd"; name = "x"; status = Pass; time = 0.0126 };
         {
           file = "tests/a/y.egd";
           name = "y[interp]";
           status = Fail "expected <1> & \"2\"\n  | ok";
           time = 1.;
         };
         {
           file = "tests/b/z.egd";
           name = "z";
           status = Skip "phase 2 > current phase 0";
           time = 0.;
         };
       ]);
  [%expect
    {|
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuites name="egide-conformance" tests="3" failures="1" errors="0" skipped="1" time="1.013">
      <testsuite name="tests/a" tests="2" failures="1" errors="0" skipped="0" time="1.013">
        <testcase classname="tests.a" name="x" file="tests/a/x.egd" time="0.013"/>
        <testcase classname="tests.a" name="y[interp]" file="tests/a/y.egd" time="1.000">
          <failure message="expected &lt;1&gt; &amp; &quot;2&quot;">expected &lt;1&gt; &amp; "2"
      | ok</failure>
        </testcase>
      </testsuite>
      <testsuite name="tests/b" tests="1" failures="0" errors="0" skipped="1" time="0.000">
        <testcase classname="tests.b" name="z" file="tests/b/z.egd" time="0.000">
          <skipped message="phase 2 &gt; current phase 0"/>
        </testcase>
      </testsuite>
    </testsuites>
    |}]

let%expect_test "empty report is well-formed" =
  print_string (Junit.to_xml []);
  [%expect
    {|
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuites name="egide-conformance" tests="0" failures="0" errors="0" skipped="0" time="0.000">
    </testsuites>
    |}]

let%expect_test "invalid UTF-8 and characters forbidden by XML 1.0 are escaped" =
  print_endline (Junit.sanitize "ok \xC3\xA9 \xE2\x80\xAE bad:\xFF\xC3 ctl:\x00\x1B tab:\t");
  [%expect {| ok é ‮ bad:\xFF\xC3 ctl:\x00\x1B tab:	 |}]
