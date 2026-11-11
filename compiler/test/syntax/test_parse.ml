open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show src =
  let ast, diags = Parse.file ~file:"t.egd" src in
  Option.iter (fun a -> print_endline (Print.file a)) ast;
  List.iter (fun d -> print_endline (D.to_human d)) diags

(* spec: SYN-001, SYN-002 *)
let%expect_test "module, imports and constants" =
  show "module api.tenants\nimport std.fmt\nimport egide.pg as pg\nlet LIMIT = 10\nlet ok = true\n";
  [%expect
    {|
    (module api.tenants)
      (import std.fmt)
      (import egide.pg as pg)
      (let LIMIT (int 10))
      (let ok (bool true))
    |}]

(* spec: SYN-001 *)
let%expect_test "missing module declaration" =
  show "let x = 1\n";
  [%expect {| t.egd:1:1: error[E0100]: syntax error: unexpected let (SYN-001) |}]

(* spec: SYN-002 — imports precede all other declarations. The diagnostic cites SYN-001 today (generic parse-error
   mapping); T-0013 owns the message and rule id. *)
let%expect_test "import after a declaration is rejected" =
  show "module m\nlet x = 1\nimport std.fmt\n";
  [%expect {| t.egd:3:1: error[E0100]: syntax error: unexpected import (SYN-001) |}]

(* spec: LEX-042, EBNF `literal = ... | DURATION` — the six units reach the AST. *)
let%expect_test "duration literals" =
  show "module m\nlet a = 500.ms\nlet b = 1.ns\nlet c = 2.us\nlet d = 5.s\nlet e = 30.min\nlet f = 3.h\n";
  [%expect {|
    (module m)
      (let a (duration 500 ms))
      (let b (duration 1 ns))
      (let c (duration 2 us))
      (let d (duration 5 s))
      (let e (duration 30 min))
      (let f (duration 3 h))
    |}]

(* spec: LEX-041 — a dot not followed by a digit is not part of the number; `1.` is `INT .` and the parser rejects it
   (T-0003 criterion 2, Q-0025.2). *)
let%expect_test "1. is a syntax error, not a lexical one" =
  show "module m\nlet a = 1.\n";
  [%expect {| t.egd:2:10: error[E0100]: syntax error: unexpected . (SYN-001) |}]
