(* Unit tests for the lexer + layout seed. Each test cites the rules it covers. *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show src =
  let toks, diags = Parse.tokens ~file:"t.egd" src in
  print_endline
    (String.concat " " (List.map (fun (t : Lexer.located) -> Parse.token_to_string t.tok) toks));
  List.iter (fun d -> print_endline (D.to_human d)) diags

(* spec: LEX-032, LEX-034 *)
let%expect_test "nested blocks produce INDENT/DEDENT" =
  show "module m\nfn f():\n    if x:\n        y\n    z\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT if IDENT("x") : INDENT IDENT("y") NEWLINE DEDENT IDENT("z") NEWLINE DEDENT EOF |}]

(* spec: LEX-031 *)
let%expect_test "blank and comment lines are ignored" =
  show "module m\n\n# comment\n   # indented comment\nlet x = 1\n";
  [%expect {| module IDENT("m") NEWLINE let IDENT("x") = INT("1") NEWLINE EOF |}]

(* spec: LEX-032 step 2 *)
let%expect_test "indentation without a colon is rejected" =
  show "module m\nlet x = 1\n    let y = 2\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("x") = INT("1") let IDENT("y") = INT("2") NEWLINE EOF
    t.egd:3:5: error[E0020]: unexpected indentation (the previous line does not end with `:`) (LEX-032)
    |}]

(* spec: LEX-032 step 2 *)
let%expect_test "indentation must grow by exactly 4 spaces" =
  show "module m\nfn f():\n  x\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT IDENT("x") NEWLINE DEDENT EOF
    t.egd:3:3: error[E0021]: indentation must increase by exactly 4 spaces (LEX-032)
    |}]

(* spec: LEX-032 step 3. Recovery (T-0007): the width of the offending line is remembered without an
   INDENT, so no DEDENT is emitted for it at end of file (LEX-034 counts only real blocks). *)
let%expect_test "dedent to an unknown column" =
  show "module m\nfn f():\n    a\n  b\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT IDENT("a") NEWLINE DEDENT IDENT("b") NEWLINE EOF
    t.egd:4:3: error[E0022]: inconsistent dedent: no enclosing block starts at column 3 (LEX-032)
    |}]

(* spec: LEX-030, LEX-035 *)
let%expect_test "line breaks inside brackets are joined" =
  show "module m\nlet x = f(1,\n      2)\n";
  [%expect
    {| module IDENT("m") NEWLINE let IDENT("x") = IDENT("f") ( INT("1") , INT("2") ) NEWLINE EOF |}]

(* spec: LEX-003 *)
let%expect_test "bidi override in a string is forbidden" =
  show "module m\nlet s = \"a\xe2\x80\xaeb\"\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("s") = STRING("a\226\128\174b") NEWLINE EOF
    t.egd:2:11: error[E0004]: forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source) (LEX-003)
    |}]

(* spec: LEX-004 *)
let%expect_test "tab outside a string is rejected" =
  show "module m\nlet x =\t1\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("x") = INT("1") NEWLINE EOF
    t.egd:2:8: error[E0005]: tab character outside a string literal; indent with 4 spaces (LEX-004)
    |}]

(* spec: LEX-061 *)
let%expect_test "semicolon is rejected" =
  show "module m\nlet x = 1;\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("x") = INT("1") NEWLINE EOF
    t.egd:2:10: error[E0050]: `;` is not used in Égide; statements end at line breaks (LEX-061)
    |}]

(* spec: LEX-001 *)
let%expect_test "invalid UTF-8 stops lexing" =
  show "module m\nlet x = \"\xff\"\n";
  [%expect {|
    EOF
    t.egd:2:10: error[E0001]: invalid UTF-8 sequence (LEX-001)
    |}]

(* ---- T-0007: continuation lines, block colon, single-line blocks, brackets ---- *)

(* spec: LEX-030 (b) *)
let%expect_test "pipeline continuation lines are joined" =
  show "module m\nlet y = xs\n    |> map(f)\n    |> filter(g)\nlet z = 1\n";
  [%expect
    {| module IDENT("m") NEWLINE let IDENT("y") = IDENT("xs") |> IDENT("map") ( IDENT("f") ) |> IDENT("filter") ( IDENT("g") ) NEWLINE let IDENT("z") = INT("1") NEWLINE EOF |}]

(* spec: LEX-030 (b) *)
let%expect_test "method chain continuation lines are joined" =
  show "module m\nfn f():\n    let s = b\n        .push(1)\n        .build()\n    s\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT let IDENT("s") = IDENT("b") . IDENT("push") ( INT("1") ) . IDENT("build") ( ) NEWLINE IDENT("s") NEWLINE DEDENT EOF |}]

(* spec: LEX-030 (b), LEX-032 step 2: the colon ending a continued condition opens a block whose
   width is measured from the stack top, not from the continuation lines. *)
let%expect_test "and/or continuation lines before a block colon" =
  show "module m\nfn f():\n    if a\n        and b\n        or c:\n        x\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT if IDENT("a") and IDENT("b") or IDENT("c") : INDENT IDENT("x") NEWLINE DEDENT DEDENT EOF |}]

(* spec: LEX-030 (b): "more than the first physical line of the current logical line", so continuation
   lines may be indented by any amount and need not be aligned with each other. *)
let%expect_test "continuation lines compare with the first physical line" =
  show "module m\nlet y = xs\n  |> a\n          |> b\n |> c\n";
  [%expect
    {| module IDENT("m") NEWLINE let IDENT("y") = IDENT("xs") |> IDENT("a") |> IDENT("b") |> IDENT("c") NEWLINE EOF |}]

(* spec: LEX-030 (b), LEX-031: blank and comment lines between continuation lines are skipped. *)
let%expect_test "blank and comment lines inside a continuation" =
  show "module m\nlet y = xs\n\n    # step one\n    |> a\n";
  [%expect {| module IDENT("m") NEWLINE let IDENT("y") = IDENT("xs") |> IDENT("a") NEWLINE EOF |}]

(* spec: LEX-030 (b): a continuation token at the same width does not join (NEWLINE is emitted). *)
let%expect_test "continuation token not indented more starts a new logical line" =
  show "module m\nlet y = xs\n|> f\n";
  [%expect
    {| module IDENT("m") NEWLINE let IDENT("y") = IDENT("xs") NEWLINE |> IDENT("f") NEWLINE EOF |}]

(* spec: LEX-030 (b), LEX-032 step 2: only `|>`, `.`, `and`, `or` continue a line. *)
let%expect_test "other operators do not continue a line" =
  show "module m\nlet y = a\n    + b\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("y") = IDENT("a") + IDENT("b") NEWLINE EOF
    t.egd:3:5: error[E0020]: unexpected indentation (the previous line does not end with `:`) (LEX-032)
    |}]

(* spec: LEX-030 (a)+(b): the first physical line of the logical line is the reference, even after
   a bracketed part spanning lines. *)
let%expect_test "continuation after a multi-line bracket" =
  show "module m\nlet x = f(\n  a\n)\n    .g()\n";
  [%expect
    {| module IDENT("m") NEWLINE let IDENT("x") = IDENT("f") ( IDENT("a") ) . IDENT("g") ( ) NEWLINE EOF |}]

(* spec: LEX-033 *)
let%expect_test "colon at end of line without an indented block" =
  show "module m\nfn f():\nlet x = 1\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : NEWLINE let IDENT("x") = INT("1") NEWLINE EOF
    t.egd:2:7: error[E0023]: expected an indented block after `:` (LEX-033)
    |}]

(* spec: LEX-033, LEX-032 step 3 *)
let%expect_test "colon followed by a dedent" =
  show "module m\nfn f():\n    if x:\n    y\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT if IDENT("x") : NEWLINE IDENT("y") NEWLINE DEDENT EOF
    t.egd:3:9: error[E0023]: expected an indented block after `:` (LEX-033)
    |}]

(* spec: LEX-033, LEX-034 *)
let%expect_test "colon at end of file" =
  show "module m\nfn f():\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : NEWLINE EOF
    t.egd:2:7: error[E0023]: expected an indented block after `:` (LEX-033)
    |}]

(* spec: LEX-033: single-line blocks emit no INDENT. *)
let%expect_test "single-line blocks" =
  show "module m\nfn f(): 1\nfn g():\n    if x: return 1\n    else: 2\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INT("1") NEWLINE fn IDENT("g") ( ) : INDENT if IDENT("x") : return INT("1") NEWLINE else : INT("2") NEWLINE DEDENT EOF |}]

(* spec: LEX-033, LEX-032 step 2: a single-line block cannot be followed by an indented body. *)
let%expect_test "single-line block followed by an indented line" =
  show "module m\nfn f(): 1\n    2\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INT("1") INT("2") NEWLINE EOF
    t.egd:3:5: error[E0020]: unexpected indentation (the previous line does not end with `:`) (LEX-032)
    |}]

(* spec: LEX-035, LEX-033: inside brackets a trailing `:` is not a block colon and a dedent below the
   enclosing block is not significant. *)
let%expect_test "indentation and colons inside brackets are not significant" =
  show "module m\nfn f():\n    let p = P{x:\n1, y: 2}\n    g(1,\n  2)\n    h\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT let IDENT("p") = IDENT("P") { IDENT("x") : INT("1") , IDENT("y") : INT("2") } NEWLINE IDENT("g") ( INT("1") , INT("2") ) NEWLINE IDENT("h") NEWLINE DEDENT EOF |}]

(* spec: LEX-035, LEX-034: an unclosed bracket still ends with NEWLINE, DEDENTs and EOF. *)
let%expect_test "unclosed bracket at end of file" =
  show "module m\nfn f():\n    g(1,\n";
  [%expect
    {| module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT IDENT("g") ( INT("1") , NEWLINE DEDENT EOF |}]

(* spec: LEX-032 step 3, LEX-034: recovery after an inconsistent dedent keeps INDENT/DEDENT balanced. *)
let%expect_test "inconsistent dedent recovery stays balanced" =
  show "module m\nfn f():\n    if x:\n        a\n      b\n      c\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT if IDENT("x") : INDENT IDENT("a") NEWLINE DEDENT IDENT("b") NEWLINE IDENT("c") NEWLINE DEDENT EOF
    t.egd:5:7: error[E0022]: inconsistent dedent: no enclosing block starts at column 7 (LEX-032)
    |}]
