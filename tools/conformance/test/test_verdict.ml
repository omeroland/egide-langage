(* Tests of the pass/fail decision for one compiler run (docs/testing.md §2; exit codes of the
   tooling-engineer rules; 101 for panics per ERR-040). *)

open Egide_conformance

let header src =
  match Header.parse src with Ok h -> h | Error es -> failwith (String.concat "; " es)

let h_of expect extra =
  header (Printf.sprintf "# spec: LEX-001\n# expect: %s\n%smodule m\n" expect extra)

let diag code line col =
  Printf.sprintf
    {|{"code":"%s","severity":"error","rule":"LEX-001","message":"m","span":{"file":"f.egd","start":{"line":%d,"col":%d},"end":{"line":%d,"col":%d}},"notes":[]}|}
    code line col line (col + 1)

let c ?(stdout = "") ?(stderr = "") h exit =
  print_endline
    (match Verdict.check h exit ~stdout ~stderr with Ok () -> "PASS" | Error m -> "FAIL " ^ m)

let%expect_test "pass expectations need exit 0" =
  let h = h_of "lex-pass" "" in
  c h (Exited 0);
  c h (Exited 0) ~stderr:(diag "W0001" 1 1);
  c h (Exited 1) ~stderr:(diag "E0001" 1 1);
  c (h_of "parse-pass" "") (Exited 2) ~stderr:"usage: egide ...";
  [%expect
    {|
    PASS
    PASS
    FAIL expected exit status 0, got 1
      reported: E0001 at 1:1
    FAIL expected exit status 0, got 2
    |}]

let%expect_test "fail expectations need exit 1 and every expected diagnostic" =
  let h = h_of "lex-fail" "# diagnostic: E0022 at 8:3\n# diagnostic: E0022 at 8:3\n" in
  c h (Exited 1)
    ~stderr:(String.concat "\n" [ diag "E0022" 8 3; diag "E0005" 2 1; diag "E0022" 8 3 ]);
  c h (Exited 1) ~stderr:(diag "E0022" 8 3);
  c h (Exited 1) ~stderr:(diag "E0022" 8 4 ^ "\n" ^ diag "E0021" 8 3);
  c h (Exited 0);
  c h (Exited 2) ~stderr:(diag "E0022" 8 3 ^ "\n" ^ diag "E0022" 8 3);
  c (h_of "compile-fail" "# diagnostic: E0301 at 11:14\n") (Exited 1) ~stderr:"11:14: error[E0301]";
  [%expect
    {|
    PASS
    FAIL missing diagnostic E0022 at 8:3
      reported: E0022 at 8:3
    FAIL missing diagnostic E0022 at 8:3
      missing diagnostic E0022 at 8:3
      reported: E0022 at 8:4, E0021 at 8:3
    FAIL expected exit status 1, got 0
    FAIL expected exit status 1, got 2
      reported: E0022 at 8:3, E0022 at 8:3
    FAIL missing diagnostic E0301 at 11:14
      reported: none (diagnostics are read from --error-format=json output)
    |}]

let%expect_test "crashes fail whatever the expectation" =
  let f = h_of "lex-fail" "# diagnostic: E0001 at 1:1\n" in
  c f (Exited 70) ~stderr:(diag "E0001" 1 1);
  c f (Exited 1) ~stderr:(diag "E0001" 1 1 ^ "\n" ^ diag "ICE" 3 4);
  c f (Exited 1) ~stderr:(diag "E0001" 1 1 ^ "\nFatal error: exception Not_found\n");
  c f (Signaled Sys.sigsegv);
  c f (Timed_out 30.);
  c f (Spawn_error "No such file or directory");
  [%expect
    {|
    FAIL compiler crash: internal compiler error (exit status 70)
    FAIL compiler crash: ICE diagnostic reported
    FAIL compiler crash: uncaught OCaml exception
    FAIL compiler crash: killed by signal SIGSEGV
    FAIL timed out after 30s
    FAIL cannot run the compiler: No such file or directory
    |}]

let%expect_test "run-pass checks exit 0 and stdout lines" =
  let h = h_of "run-pass" "# stdout: hello\n# stdout:\n# stdout: x\n" in
  c h (Exited 0) ~stdout:"hello\n\nx\n";
  c h (Exited 0) ~stdout:"hello\n\nx";
  c h (Exited 0) ~stdout:"hello\n\nx\n\n";
  c h (Exited 0) ~stdout:"hello\r\n\r\nx\r\n";
  c h (Exited 1) ~stdout:"hello\n\nx\n";
  c (h_of "run-pass" "") (Exited 0) ~stdout:"anything";
  [%expect
    {|
    PASS
    PASS
    FAIL stdout differs
      expected: ["hello", "", "x"]
      actual:   ["hello", "", "x", ""]
    FAIL stdout differs
      expected: ["hello", "", "x"]
      actual:   ["hello\r", "\r", "x\r"]
    FAIL expected exit status 0, got 1
    PASS
    |}]

let%expect_test "run-panic needs exit 101 (ERR-040)" =
  let h = h_of "run-panic" "" in
  c h (Exited 101) ~stderr:"panic: index out of bounds";
  c h (Exited 1);
  c h (Exited 0);
  [%expect
    {|
    PASS
    FAIL expected exit status 101 (panic), got 1
    FAIL expected exit status 101 (panic), got 0
    |}]

let%expect_test "lines" =
  List.iter
    (fun s -> print_endline ("[" ^ String.concat "|" (Verdict.lines s) ^ "]"))
    [ ""; "\n"; "a"; "a\n"; "a\n\n"; "a\nb" ];
  [%expect {|
    []
    []
    [a]
    [a]
    [a|]
    [a|b]
    |}]
