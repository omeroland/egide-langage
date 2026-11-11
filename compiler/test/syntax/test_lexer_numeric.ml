(* T-0003 — numeric and duration literals (LEX-040, LEX-041, LEX-042; decisions of Q-0015 / ADR-0016).
   The tests call [Lexer.tokenize] directly (raw tokens, no layout). One literal per line so that every token
   starts at column 1 unless the case is about the tokens that follow it. *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show_diag (d : D.t) =
  Printf.sprintf "%s %d:%d-%d:%d %s%s" d.code d.span.start.line d.span.start.col d.span.stop.line
    d.span.stop.col d.message
    (String.concat "" (List.map (fun n -> " [" ^ n ^ "]") d.notes))

let show src =
  let toks, diags = Lexer.tokenize ~file:"t.egd" src in
  List.iter
    (fun (t : Lexer.located) ->
      Printf.printf "%d:%d-%d %s\n" t.startp.pos_lnum
        (t.startp.pos_cnum - t.startp.pos_bol + 1)
        (t.endp.pos_cnum - t.endp.pos_bol + 1)
        (Parse.token_to_string t.tok))
    toks;
  List.iter (fun d -> print_endline (show_diag d)) diags

(* spec: LEX-040 *)
let%expect_test "integer literals: decimal, hexadecimal, octal, binary, with underscores" =
  show "0\n123\n1_000_000\n0x7F\n0xdead_BEEF\n0o755\n0b1010\n0b1_0\n";
  [%expect
    {|
    1:1-2 INT("0")
    2:1-4 INT("123")
    3:1-10 INT("1_000_000")
    4:1-5 INT("0x7F")
    5:1-12 INT("0xdead_BEEF")
    6:1-6 INT("0o755")
    7:1-7 INT("0b1010")
    8:1-6 INT("0b1_0")
    |}]

(* spec: LEX-041 *)
let%expect_test "float literals" =
  show "1.5\n1e9\n2.5e-3\n1e+9\n1_000.25\n1.5_0\n1e1_0\n0.5\n";
  [%expect
    {|
    1:1-4 FLOAT("1.5")
    2:1-4 FLOAT("1e9")
    3:1-7 FLOAT("2.5e-3")
    4:1-5 FLOAT("1e+9")
    5:1-9 FLOAT("1_000.25")
    6:1-6 FLOAT("1.5_0")
    7:1-6 FLOAT("1e1_0")
    8:1-4 FLOAT("0.5")
    |}]

(* spec: LEX-042 *)
let%expect_test "duration literals are single tokens" =
  show "500.ms\n5.s\n30.min\n1.ns\n2.us\n3.h\n1_0.s\n";
  [%expect
    {|
    1:1-7 DURATION("500", "ms")
    2:1-4 DURATION("5", "s")
    3:1-7 DURATION("30", "min")
    4:1-5 DURATION("1", "ns")
    5:1-5 DURATION("2", "us")
    6:1-4 DURATION("3", "h")
    7:1-6 DURATION("1_0", "s")
    |}]

(* spec: LEX-042 *)
let%expect_test "a unit followed by an identifier character, or a non-decimal base, is INT . IDENT" =
  show "5.msg\n5.s2\n5.min_value\n0x10.s\n0b1.ms\n5.s.x\n";
  [%expect
    {|
    1:1-2 INT("5")
    1:2-3 .
    1:3-6 IDENT("msg")
    2:1-2 INT("5")
    2:2-3 .
    2:3-5 IDENT("s2")
    3:1-2 INT("5")
    3:2-3 .
    3:3-12 IDENT("min_value")
    4:1-5 INT("0x10")
    4:5-6 .
    4:6-7 IDENT("s")
    5:1-4 INT("0b1")
    5:4-5 .
    5:5-7 IDENT("ms")
    6:1-4 DURATION("5", "s")
    6:4-5 .
    6:5-6 IDENT("x")
    |}]

(* spec: LEX-041, LEX-042 *)
let%expect_test "a dot must be followed by a digit to make a float; .5 is not a float; no t.0 special case" =
  show "1..5\n1.\n1.e3\n.5\n1.5.5\nt.0\n1e5.ms\n";
  [%expect
    {|
    1:1-2 INT("1")
    1:2-4 ..
    1:4-5 INT("5")
    2:1-2 INT("1")
    2:2-3 .
    3:1-2 INT("1")
    3:2-3 .
    3:3-5 IDENT("e3")
    4:1-2 .
    4:2-3 INT("5")
    5:1-4 FLOAT("1.5")
    5:4-5 .
    5:5-6 INT("5")
    6:1-2 IDENT("t")
    6:2-3 .
    6:3-4 INT("0")
    7:1-4 FLOAT("1e5")
    7:4-5 .
    7:5-7 IDENT("ms")
    |}]

(* spec: LEX-040. Overflow is not checked by the lexer (TYP-070): the source text is kept verbatim. *)
let%expect_test "integer literals are not range-checked in the lexer" =
  show "99999999999999999999999999999999999999\n0xFFFFFFFFFFFFFFFFFFFFFFFF\n";
  [%expect
    {|
    1:1-39 INT("99999999999999999999999999999999999999")
    2:1-27 INT("0xFFFFFFFFFFFFFFFFFFFFFFFF")
    |}]

(* spec: LEX-040 (E0030). One diagnostic per literal, spanning the whole literal; the token is still produced. *)
let%expect_test "malformed integer literals" =
  show "1__0\n1_\n0x_1\n0x\n0b102\n0o8\n0xFG\n0755\n0_1\n0X1F\n5ms\n12abc\n";
  [%expect
    {|
    1:1-5 INT("1__0")
    2:1-3 INT("1_")
    3:1-5 INT("0x_1")
    4:1-3 INT("0x")
    5:1-6 INT("0b102")
    6:1-4 INT("0o8")
    7:1-5 INT("0xFG")
    8:1-5 INT("0755")
    9:1-4 INT("0_1")
    10:1-5 INT("0X1F")
    11:1-4 INT("5ms")
    12:1-6 INT("12abc")
    E0030 1:1-1:5 `_` may not be doubled in a numeric literal
    E0030 2:1-2:3 a digit group may not end with `_`
    E0030 3:1-3:5 a digit group may not start with `_`
    E0030 4:1-4:3 `0x` must be followed by digits
    E0030 5:1-5:6 `2` is not a valid digit of a binary literal
    E0030 6:1-6:4 `8` is not a valid digit of an octal literal
    E0030 7:1-7:5 `G` is not a valid digit of a hexadecimal literal
    E0030 8:1-8:5 leading zero in `0755` [write 0o755 for octal]
    E0030 9:1-9:4 leading zero in `0_1`
    E0030 10:1-10:5 `X1F` directly follows the numeric literal `0` [integer prefixes are lowercase: 0x, 0o, 0b]
    E0030 11:1-11:4 `ms` directly follows the numeric literal `5`
    E0030 12:1-12:6 `abc` directly follows the numeric literal `12`
    |}]

(* spec: LEX-041 (E0031) *)
let%expect_test "malformed float literals" =
  show "1E9\n1e\n1.5_\n1.5ms\n1e_5\n1_.5\n1.5__0\n1e+\n00.5\n";
  [%expect
    {|
    1:1-4 FLOAT("1E9")
    2:1-3 FLOAT("1e")
    3:1-5 FLOAT("1.5_")
    4:1-6 FLOAT("1.5ms")
    5:1-5 FLOAT("1e_5")
    6:1-5 FLOAT("1_.5")
    7:1-7 FLOAT("1.5__0")
    8:1-3 FLOAT("1e")
    8:3-4 +
    9:1-5 FLOAT("00.5")
    E0031 1:1-1:4 the exponent letter must be lowercase `e`
    E0031 2:1-2:3 the exponent has no digits
    E0031 3:1-3:5 a digit group may not end with `_`
    E0031 4:1-4:6 `ms` directly follows the numeric literal `1.5`
    E0031 5:1-5:5 a digit group may not start with `_`
    E0031 6:1-6:5 a digit group may not end with `_`
    E0031 7:1-7:7 `_` may not be doubled in a numeric literal
    E0031 8:1-8:3 the exponent has no digits
    E0031 9:1-9:5 leading zero in `00`
    |}]

(* spec: LEX-042, LEX-040 *)
let%expect_test "the integer part of a duration is validated like any decimal integer" =
  show "05.ms\n1__0.s\n1_.s\n";
  [%expect
    {|
    1:1-6 DURATION("05", "ms")
    2:1-7 DURATION("1__0", "s")
    3:1-5 DURATION("1_", "s")
    E0030 1:1-1:6 leading zero in `05` [write 0o5 for octal]
    E0030 2:1-2:7 `_` may not be doubled in a numeric literal
    E0030 3:1-3:5 a digit group may not end with `_`
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* Properties *)

let seeded t = QCheck2.Test.check_exn ~rand:(Random.State.make [| 3 |]) t

(* spec: LEX-040, LEX-041, LEX-042: arbitrary text built from the literal alphabet never raises. *)
let%test "the lexer never raises on literal-like soup" =
  seeded
    (QCheck2.Test.make ~name:"literal soup" ~count:5000
       QCheck2.Gen.(
         string_size ~gen:(oneof_list (List.of_seq (String.to_seq "0123456789_xobeE.+-sminuhfa ")))
           (int_range 0 24))
       (fun s ->
         match Lexer.tokenize ~file:"t.egd" s with _ -> true | exception _ -> false));
  true

(* spec: LEX-040: a canonical decimal integer lexes to exactly one INT token with no diagnostic. *)
let%test "canonical decimal integers lex to one INT" =
  seeded
    (QCheck2.Test.make ~name:"canonical int" ~count:2000
       QCheck2.Gen.(int_range 0 max_int)
       (fun n ->
         let s = string_of_int n in
         match Lexer.tokenize ~file:"t.egd" s with
         | [ { tok; _ } ], [] -> Parse.token_to_string tok = Printf.sprintf "INT(%S)" s
         | _ -> false));
  true

(* spec: LEX-042: every duration unit forms exactly one DURATION token. *)
let%test "amount.unit lexes to one DURATION" =
  seeded
    (QCheck2.Test.make ~name:"duration" ~count:2000
       QCheck2.Gen.(pair (int_range 0 1_000_000) (oneof_list [ "ns"; "us"; "ms"; "s"; "min"; "h" ]))
       (fun (n, u) ->
         match Lexer.tokenize ~file:"t.egd" (Printf.sprintf "%d.%s" n u) with
         | [ { tok; _ } ], [] -> Parse.token_to_string tok = Printf.sprintf "DURATION(%S, %S)" (string_of_int n) u
         | _ -> false));
  true
