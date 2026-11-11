(* T-0005 — prefixed templates with recursive interpolation (LEX-055; decisions of Q-0014 / ADR-0016 / ADR-0017).
   The tests call [Lexer.tokenize] directly (raw tokens, no layout). *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show_diag (d : D.t) =
  Printf.sprintf "%s %d:%d-%d:%d %s" d.code d.span.start.line d.span.start.col d.span.stop.line
    d.span.stop.col d.message

let show src =
  let toks, diags = Lexer.tokenize ~file:"t.egd" src in
  List.iter
    (fun (t : Lexer.located) ->
      Printf.printf "%d:%d-%d:%d %s\n" t.startp.pos_lnum
        (t.startp.pos_cnum - t.startp.pos_bol + 1)
        t.endp.pos_lnum
        (t.endp.pos_cnum - t.endp.pos_bol + 1)
        (Parse.token_to_string t.tok))
    toks;
  List.iter (fun d -> print_endline (show_diag d)) diags

(* spec: LEX-055 *)
let%expect_test "literal parts and interpolations" =
  show {x|f"a{b}c"
sql"x {y} z"
f"{x}"
f""
|x};
  [%expect
    {|
    1:1-1:9 TEMPLATE("f", ["a"; {IDENT("b")}; "c"])
    2:1-2:13 TEMPLATE("sql", ["x "; {IDENT("y")}; " z"])
    3:1-3:7 TEMPLATE("f", [{IDENT("x")}])
    4:1-4:4 TEMPLATE("f", [])
    |}]

(* spec: LEX-055 (templates nest) *)
let%expect_test "nested templates" =
  show {x|f"{f"{x}"}"|x};
  [%expect {| 1:1-1:12 TEMPLATE("f", [{TEMPLATE("f", [{IDENT("x")}])}]) |}]

(* spec: LEX-055 ({{ and }} are the only lexer escapes) *)
let%expect_test "doubled braces" =
  show {x|f"{{a}}"|x};
  [%expect {| 1:1-1:9 TEMPLATE("f", ["{a}"]) |}]

(* spec: LEX-055, LEX-052, LEX-053 (r and b are not template prefixes; keywords are never prefixes) *)
let%expect_test "r, b and keywords are not prefixes" =
  show {x|r"x{y}" b"x" return"x"|x};
  [%expect
    {|
    1:1-1:8 RAW_STRING("x{y}")
    1:9-1:13 BYTES("x")
    1:14-1:20 return
    1:20-1:23 STRING("x")
    |}]

(* spec: LEX-055 (an unterminated interpolation is E0044) *)
let%expect_test "unterminated interpolation" =
  show {x|f"{x|x};
  [%expect {| 1:3-1:4 E0044 unterminated interpolation |}]
