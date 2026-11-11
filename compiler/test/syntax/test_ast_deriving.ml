(* Tests for the ppx_deriving [show, eq] functions of Ast (T-0029). Spec: none (compiler infrastructure; architecture
   section 2, invariant 3: ids are part of the tree, so equality compares them).

   What is pinned here, and why:
   - [Ast.equal_*] exist for every node type, not only the seven of T-0008, and compare spans and ids;
   - [Ast.pp_*] / [Ast.show_*] are the derived debug printers (record syntax, with [#n] ids and spans), whereas
     [Print.pp_*] stays the S-expression formatter, which omits both. The two must not be confused. *)

open Egide_syntax
open Ast

let sp = Egide_source.Span.dummy

let sp2 =
  Egide_source.Span.make ~file:"f.egd" ~start:{ line = 3; col = 4 } ~stop:{ line = 3; col = 9 }

let gen = Node_id.Gen.create ()
let nid () = Node_id.Gen.fresh gen
let id ?(span = sp) name : ident = { id = nid (); name; span }
let path s : path = { id = nid (); segments = [ id s ]; span = sp }

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let e expr : expr = { id = nid (); expr; span = sp }

let%expect_test "derived show prints records with ids and spans" =
  let g = Node_id.Gen.create () in
  let i : ident = { id = Node_id.Gen.fresh g; name = "x"; span = sp2 } in
  print_endline (show_ident i);
  [%expect {| { Ast.id = #0; name = "x"; span = f.egd:3:4 } |}]

let%expect_test "derived show covers constructors, options, lists and Uchar" =
  let ch = e (Lit (Char (Uchar.of_int 0x1F600))) in
  let s = show_expr ch in
  Printf.printf "has constructor: %b, has id: %b, uchar: %b\n" (contains s "Lit") (contains s "#")
    (contains s "U+1F600");
  [%expect {| has constructor: true, has id: true, uchar: true |}]

(* The S-expression formatter is not replaced: no ids, no record syntax. *)
let%expect_test "Print.pp_sexp_expr is the S-expression, Ast.pp_expr is the derived one" =
  let one = e (Lit (Int "1")) and two = e (Lit (Int "2")) in
  let sum = e (Binary { op = Add; lhs = one; rhs = two }) in
  Format.printf "%a@." Print.pp_sexp_expr sum;
  Printf.printf "derived differs: %b, derived shows ids: %b\n"
    (Format.asprintf "%a" Ast.pp_expr sum <> Format.asprintf "%a" Print.pp_sexp_expr sum)
    (contains (Format.asprintf "%a" Ast.pp_expr sum) "#");
  Printf.printf "S-expression shows ids: %b\n"
    (contains (Format.asprintf "%a" Print.pp_sexp_expr sum) "#");
  [%expect
    {|
    (+ (int 1) (int 2))
    derived differs: true, derived shows ids: true
    S-expression shows ids: false
    |}]

(* Equality exists for the nodes that T-0008 did not export, and compares ids and spans. *)
let%expect_test "equal_* on ident, path, bound, arg, literal compare ids and spans" =
  let a = id "x" in
  let same_id_other_span = { a with span = sp2 } in
  let fresh = id "x" in
  Printf.printf "ident: %b %b %b\n" (equal_ident a a)
    (equal_ident a same_id_other_span)
    (equal_ident a fresh);
  let pa = path "m" in
  Printf.printf "path: %b %b\n" (equal_path pa pa) (equal_path pa (path "m"));
  let b : bound = { id = nid (); path = pa; args = []; span = sp } in
  Printf.printf "bound: %b %b\n" (equal_bound b b) (equal_bound b { b with id = nid () });
  let ar : arg =
    { id = nid (); arg = Arg_plain { label = None; value = e (Lit (Bool true)) }; span = sp }
  in
  Printf.printf "arg: %b %b\n" (equal_arg ar ar) (equal_arg ar { ar with span = sp2 });
  Printf.printf "literal: %b %b %b\n"
    (equal_literal (Int "1") (Int "1"))
    (equal_literal (Int "1") (Int "01"))
    (equal_literal (Char (Uchar.of_int 0x61)) (Char (Uchar.of_int 0x62)));
  Printf.printf "span: %b %b\n" (equal_span sp sp) (equal_span sp sp2);
  [%expect
    {|
    ident: true false false
    path: true false
    bound: true false
    arg: true false
    literal: true false false
    span: true false
    |}]

(* The derived equality agrees with the structural equality it replaces, on equal and on different trees. *)
let%expect_test "derived equal agrees with structural equality" =
  let mk n =
    let one = e (Lit (Int n)) in
    e (Binary { op = Add; lhs = one; rhs = e (Lit (Bool true)) })
  in
  let a = mk "1" in
  let pairs = [ (a, a); (a, mk "1"); (a, mk "2"); (a, { a with span = sp2 }) ] in
  List.iter (fun (x, y) -> Printf.printf "%b " (equal_expr x y = (x = y))) pairs;
  print_newline ();
  [%expect {| true true true true |}]

(* LEX-006: a file name is attacker-controlled, and the derived printers must not let a dangerous code point through
   (ESC, U+202E right-to-left override, LF). Every show_* reaches a span through [pp_span]; five representative ones. *)
let%expect_test "derived show_* escape a hostile file name in spans" =
  let hostile = "a\x1b[31m\xE2\x80\xAEb\nc.egd" in
  let hsp =
    Egide_source.Span.make ~file:hostile ~start:{ line = 1; col = 1 } ~stop:{ line = 1; col = 2 }
  in
  let g = Node_id.Gen.create () in
  let i : ident = { id = Node_id.Gen.fresh g; name = "x"; span = hsp } in
  let pa : path = { id = Node_id.Gen.fresh g; segments = [ i ]; span = hsp } in
  let ex : expr = { id = Node_id.Gen.fresh g; expr = Path pa; span = hsp } in
  let ty : ty = { id = Node_id.Gen.fresh g; ty = Ty_path { path = pa; args = [] }; span = hsp } in
  let st : stmt = { id = Node_id.Gen.fresh g; stmt = Expr ex; span = hsp } in
  let outs =
    [
      show_ident i;
      show_path pa;
      show_expr ex;
      show_ty ty;
      show_stmt st;
      Format.asprintf "%a" pp_span hsp;
    ]
  in
  (* [Format] breaks a long record over several lines, so a plain LF is layout, not data: only the single-line outputs
     are checked for LF. Every other scalar is checked with the repository's own predicate. *)
  let dangerous ~allow_lf s =
    let rec go k =
      k < String.length s
      &&
      let d = String.get_utf_8_uchar s k in
      let u = Uchar.to_int (Uchar.utf_decode_uchar d) in
      (Egide_diagnostics.Escape.is_dangerous u && not (allow_lf && u = 0x0A))
      || (not (Uchar.utf_decode_is_valid d))
      || go (k + Uchar.utf_decode_length d)
    in
    go 0
  in
  Printf.printf "dangerous in any output: %b\n" (List.exists (dangerous ~allow_lf:true) outs);
  Printf.printf "LF in the single-line outputs: %b\n"
    (List.exists (dangerous ~allow_lf:false) [ show_ident i; Format.asprintf "%a" pp_span hsp ]);
  print_endline (show_ident i);
  [%expect
    {|
    dangerous in any output: false
    LF in the single-line outputs: false
    { Ast.id = #0; name = "x"; span = a\u{1B}[31m\u{202E}b\nc.egd:1:1 }
    |}]
