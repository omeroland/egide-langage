(* Property tests for the layout pass (spec/02 §2.4, LEX-030..035). *)

open Egide_syntax

(* A source line is an indentation width and a sequence of fragments. The fragments include block
   colons, brackets (possibly unbalanced) and the continuation tokens of LEX-030 (b), so the generator
   reaches every branch of the layout algorithm, error paths included. *)
let fragments =
  [| "x"; "1"; ":"; "("; ")"; "["; "]"; "{"; "}"; "|>"; "."; "and"; "or"; "+"; "f(a)"; "# c" |]

let gen_line =
  let open QCheck2.Gen in
  let* width = oneof [ map (fun n -> 4 * n) (int_bound 4); int_bound 17 ] in
  let+ frags = list_size (int_bound 5) (map (Array.get fragments) (int_bound (Array.length fragments - 1))) in
  String.make width ' ' ^ String.concat " " frags

let gen_program =
  QCheck2.Gen.(map (fun ls -> String.concat "\n" ("module m" :: ls) ^ "\n") (list_size (int_bound 30) gen_line))

(* Well-indented programs: a tree of blocks, every block opened by a line ending with `:`, bodies at
   +4, optional continuation lines. These must produce no layout diagnostic. *)
let gen_well_indented =
  let open QCheck2.Gen in
  let rec block indent fuel =
    let pad = String.make indent ' ' in
    let simple =
      let conts = [| "|> f"; ".g()"; "and y"; "or z" |] in
      let* cont = list_size (int_bound 2) (map (Array.get conts) (int_bound 3)) in
      let+ k = int_range 1 4 in
      [ pad ^ "x" ] @ List.map (fun c -> String.make (indent + 4 + (4 * (k mod 2))) ' ' ^ c) cont
    in
    let compound =
      let* inline = bool in
      if inline then return [ pad ^ "if c: x" ]
      else
        let+ body = block (indent + 4) (fuel / 2) in
        (pad ^ "if c:") :: body
    in
    let stmt = if fuel <= 1 then simple else oneof [ simple; compound ] in
    map List.concat (list_size (int_range 1 3) stmt)
  in
  let+ ls = sized_size (int_bound 24) (fun n -> block 0 (n + 1)) in
  String.concat "\n" ("module m" :: ls) ^ "\n"

let layout_tokens src = Parse.tokens ~file:"p.egd" src

(* INDENT/DEDENT are balanced and properly nested: the running count never goes negative and ends at
   zero; the stream ends with EOF (LEX-032, LEX-034). *)
let balanced (toks : Lexer.located list) =
  let rec go open_ = function
    | [] -> false
    | [ ({ tok = Tokens.EOF; _ } : Lexer.located) ] -> open_ = 0
    | ({ tok = Tokens.EOF; _ } : Lexer.located) :: _ -> false
    | ({ tok = Tokens.INDENT; _ } : Lexer.located) :: rest -> go (open_ + 1) rest
    | ({ tok = Tokens.DEDENT; _ } : Lexer.located) :: rest -> open_ > 0 && go (open_ - 1) rest
    | _ :: rest -> go open_ rest
  in
  go 0 toks

let count tok toks = List.length (List.filter (fun (t : Lexer.located) -> t.tok = tok) toks)

let prop_balanced_any =
  QCheck2.Test.make ~name:"layout tokens are balanced on arbitrary line soup" ~count:2000
    ~print:(fun s -> s) gen_program (fun src -> balanced (fst (layout_tokens src)))

let prop_well_indented =
  QCheck2.Test.make ~name:"well-indented programs: balanced, no diagnostics, one INDENT per block"
    ~count:1000 ~print:(fun s -> s) gen_well_indented (fun src ->
      let toks, diags = layout_tokens src in
      let blocks =
        List.length
          (List.filter (fun l -> String.ends_with ~suffix:":" l) (String.split_on_char '\n' src))
      in
      balanced toks && diags = [] && count Tokens.INDENT toks = blocks)

(* spec: LEX-030, LEX-032, LEX-033, LEX-034, LEX-035 *)
let%expect_test "layout properties" =
  (* Fixed seed: the expect test is deterministic; check_exn raises with a shrunk counter-example. *)
  List.iter
    (fun t -> QCheck2.Test.check_exn ~rand:(Random.State.make [| 7 |]) t)
    [ prop_balanced_any; prop_well_indented ];
  print_endline "ok";
  [%expect {| ok |}]
