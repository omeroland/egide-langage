(* Unit tests for the lexer + layout seed. Each test cites the rules it covers. *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show src =
  let toks, diags = Parse.tokens ~file:"t.egd" src in
  print_endline (String.concat " " (List.map (fun (t : Lexer.located) -> Parse.token_to_string t.tok) toks));
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

(* spec: LEX-032 step 3 *)
let%expect_test "dedent to an unknown column" =
  show "module m\nfn f():\n    a\n  b\n";
  [%expect
    {|
    module IDENT("m") NEWLINE fn IDENT("f") ( ) : INDENT IDENT("a") NEWLINE DEDENT IDENT("b") NEWLINE DEDENT EOF
    t.egd:4:3: error[E0022]: inconsistent dedent: no enclosing block starts at column 3 (LEX-032)
    |}]

(* spec: LEX-030, LEX-035 *)
let%expect_test "line breaks inside brackets are joined" =
  show "module m\nlet x = f(1,\n      2)\n";
  [%expect {| module IDENT("m") NEWLINE let IDENT("x") = IDENT("f") ( INT("1") , INT("2") ) NEWLINE EOF |}]

(* spec: LEX-003 *)
let%expect_test "bidi override in a string is forbidden" =
  show "module m\nlet s = \"a\xe2\x80\xaeb\"\n";
  [%expect
    {|
    module IDENT("m") NEWLINE let IDENT("s") = STRING("a\226\128\174b") NEWLINE EOF
    t.egd:2:11: error[E0004]: forbidden character U+202E — risk: hidden or reordered source text (Trojan Source) (LEX-003)
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
