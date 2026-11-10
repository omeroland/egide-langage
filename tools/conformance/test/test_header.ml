(* Tests of header parsing (docs/testing.md §2). *)

open Egide_conformance

let show (h : Header.t) =
  Printf.printf "spec=[%s] expect=%s diags=[%s] stdout=%s phase=%d backends=[%s]\n"
    (String.concat "," h.spec)
    (Header.expect_to_string h.expect)
    (String.concat "; " (List.map Header.diagnostic_to_string h.diagnostics))
    (match h.stdout with
    | None -> "-"
    | Some l -> "[" ^ String.concat "|" (List.map (Printf.sprintf "%S") l) ^ "]")
    h.phase
    (String.concat "," (List.map Header.backend_to_string h.backends))

let p ?stdout_file src =
  match Header.parse ?stdout_file src with
  | Ok h -> show h
  | Error es -> List.iter (fun e -> print_endline ("error: " ^ e)) es

let%expect_test "the documented example header" =
  p
    "# spec: MEM-021\n\
     # expect: compile-fail\n\
     # diagnostic: E0301 at 11:14\n\
     module tests.mem.exclusivity_same_call\n";
  [%expect
    {| spec=[MEM-021] expect=compile-fail diags=[E0301 at 11:14] stdout=- phase=0 backends=[interp,go,native] |}]

let%expect_test "every header, shebang, doc comments, blank lines, requires" =
  p
    "#!/usr/bin/env egide run\n\
     # spec: LEX-010, LEX-011 LEX-012\n\
     # spec: SYN-001,LEX-010\n\n\
     ## Doc comment.\n\
     # requires: egide.k8s = \"1.2\"\n\
     # expect: run-pass\n\
     # stdout: hello\n\
     # stdout:\n\
     # stdout:   two spaces kept  \n\
     # phase: 3\n\
     # backends: go, interp\n\
     # A free comment: with a colon is fine.\n\
     module m\n\
     # a comment in the body: fine\n";
  [%expect
    {| spec=[LEX-010,LEX-011,LEX-012,SYN-001] expect=run-pass diags=[] stdout=["hello"|""|"  two spaces kept  "] phase=3 backends=[go,interp] |}]

let%expect_test "repeated diagnostics are kept in order; W codes are accepted" =
  p
    "# spec: LEX-032\n\
     # expect: lex-fail\n\
     # diagnostic: E0022 at 8:3\n\
     # diagnostic: W0001 at 1:1\n\
     # diagnostic: E0022 at 8:3\n\
     module m\n";
  [%expect
    {| spec=[LEX-032] expect=lex-fail diags=[E0022 at 8:3; W0001 at 1:1; E0022 at 8:3] stdout=- phase=0 backends=[interp,go,native] |}]

let%expect_test
    "a UTF-8 byte-order mark and CRLF line ends do not hide the header (LEX-001, LEX-002)" =
  p
    "\xEF\xBB\xBF# spec: LEX-001\r\n\
     # expect: lex-fail\r\n\
     # diagnostic: E0002 at 1:1\r\n\
     module m\r\n";
  [%expect
    {| spec=[LEX-001] expect=lex-fail diags=[E0002 at 1:1] stdout=- phase=0 backends=[interp,go,native] |}]

let%expect_test "sibling .stdout file" =
  p ~stdout_file:"a\nb\n" "# spec: ERR-040\n# expect: run-pass\nmodule m\n";
  [%expect
    {| spec=[ERR-040] expect=run-pass diags=[] stdout=["a"|"b"] phase=0 backends=[interp,go,native] |}]

let%expect_test "missing spec header is an error" =
  p "# expect: lex-pass\nmodule m\n";
  [%expect {| error: missing `# spec:` header |}];
  p "# spec:\n# expect: lex-pass\nmodule m\n";
  [%expect {| error: line 1: `# spec:` cites no rule id |}];
  p "module m\n# spec: LEX-001\n# expect: lex-pass\n";
  [%expect
    {|
    error: line 2: `# spec:` after the header block (headers must precede the first code line)
    error: line 3: `# expect:` after the header block (headers must precede the first code line)
    error: missing `# spec:` header
    error: missing `# expect:` header
    |}]

let%expect_test "malformed values are errors" =
  p
    "# spec: LEX-1, lex-001, LEX-001\n\
     # expect: lex-passes\n\
     # expect: lex-pass\n\
     # diagnostic: E0001 at 1\n\
     # diagnostic: E001 at 1:1\n\
     # diagnostic: E0001 at 1:1 trailing\n\
     # diagnostic: E0001 at 0:1\n\
     # phase: two\n\
     # phase: 1\n\
     # phase: 2\n\
     # backends: interp, jvm\n\
     # backends:\n\
     module m\n";
  [%expect
    {|
    error: line 1: invalid rule id `LEX-1` (expected PREFIX-NNN)
    error: line 1: invalid rule id `lex-001` (expected PREFIX-NNN)
    error: line 2: unknown expectation `lex-passes` (expected lex-pass, lex-fail, parse-pass, parse-fail, compile-fail, run-pass or run-panic)
    error: line 3: duplicate `# expect:` header
    error: line 4: malformed diagnostic `E0001 at 1` (expected `<code> at <line>:<col>`, e.g. `E0022 at 8:3`)
    error: line 5: malformed diagnostic `E001 at 1:1` (expected `<code> at <line>:<col>`, e.g. `E0022 at 8:3`)
    error: line 6: malformed diagnostic `E0001 at 1:1 trailing` (expected `<code> at <line>:<col>`, e.g. `E0022 at 8:3`)
    error: line 7: malformed diagnostic `E0001 at 0:1` (expected `<code> at <line>:<col>`, e.g. `E0022 at 8:3`)
    error: line 8: invalid phase `two` (expected a non-negative integer)
    error: line 9: duplicate `# phase:` header
    error: line 10: duplicate `# phase:` header
    error: line 11: unknown backend `jvm` (expected interp, go or native)
    error: line 12: duplicate `# backends:` header
    error: line 12: `# backends:` lists no backend
    |}]

let%expect_test "a misspelt directive is an error, not a silent comment" =
  p "# spec: LEX-001\n# expect: lex-fail\n# diagnostics: E0001 at 1:1\nmodule m\n";
  [%expect
    {|
    error: line 3: unknown header `# diagnostics:` (known: spec, expect, diagnostic, stdout, phase, backends, requires)
    error: `lex-fail` requires at least one `# diagnostic:` header
    |}]

let%expect_test "headers that do not fit the expectation are errors" =
  p
    "# spec: LEX-001\n\
     # expect: lex-pass\n\
     # diagnostic: E0001 at 1:1\n\
     # stdout: x\n\
     # backends: go\n\
     module m\n";
  [%expect
    {|
    error: `# diagnostic:` is only allowed with lex-fail, parse-fail or compile-fail
    error: `# stdout:` is only allowed with run-pass
    error: `# backends:` is only allowed with run-pass or run-panic
    |}];
  p ~stdout_file:"x\n" "# spec: LEX-001\n# expect: run-pass\n# stdout: x\nmodule m\n";
  [%expect {| error: both `# stdout:` headers and a sibling .stdout file; use one |}];
  p ~stdout_file:"x\n" "# spec: LEX-001\n# expect: run-panic\nmodule m\n";
  [%expect {| error: a sibling .stdout file is only allowed with run-pass |}]

let%expect_test "is_rule_id" =
  List.iter
    (fun s -> Printf.printf "%s %b\n" s (Header.is_rule_id s))
    [ "LEX-001"; "CT-004"; "GOP-123"; "LEX-01"; "LEX-0001"; "lex-001"; "-001"; "LEX001" ];
  [%expect
    {|
    LEX-001 true
    CT-004 true
    GOP-123 true
    LEX-01 false
    LEX-0001 false
    lex-001 false
    -001 false
    LEX001 false
    |}]
