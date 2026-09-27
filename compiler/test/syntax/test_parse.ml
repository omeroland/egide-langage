open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show src =
  let ast, diags = Parse.file ~file:"t.egd" src in
  Option.iter (fun a -> print_endline (Ast.to_sexp a)) ast;
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
