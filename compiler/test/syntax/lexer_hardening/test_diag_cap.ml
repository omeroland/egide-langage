(* T-1080 — the number of diagnostics per file is bounded (LEX-002, LEX-003, LEX-004, LEX-050, LEX-051, LEX-053,
   LEX-054, LEX-055). The checks are structural (counts, first and last diagnostic, exit-status predicate), not
   wall-clock: a flood must produce at most [limit] diagnostics plus one summary (E0006), keep the first ones in
   emission order, and never turn an error into acceptance. Memory of the accumulator itself is checked in
   compiler/test/diagnostics/test_sink_limit.ml. *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let n = 1_000_000
let lex src = Lexer.tokenize ~file:"t.egd" src

let rep k s =
  let b = Buffer.create (k * String.length s) in
  for _ = 1 to k do
    Buffer.add_string b s
  done;
  Buffer.contents b

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

let has_error ds = List.exists (fun (d : D.t) -> d.severity = D.Error) ds

(* count, first diagnostic, last diagnostic, "still fails" *)
let flood src =
  let _, ds = lex src in
  let first = List.hd ds and last = List.nth ds (List.length ds - 1) in
  Printf.printf "count=%d first=%s %d:%d last=%s %S error=%b\n" (List.length ds) first.code
    first.span.start.line first.span.start.col last.code last.message (has_error ds)

(* LEX-003 / ADR-0016: forbidden characters alternating with a valid one, so runs do not collapse. *)
let%expect_test "E0004 alternating flood" =
  flood ("module m\n\n# " ^ rep n (utf8 0x200B ^ "a") ^ "\n");
  [%expect
    {| count=101 first=E0004 3:3 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-002: lone CR. *)
let%expect_test "E0003 alternating flood" =
  flood ("module m\n\n# " ^ rep n "a\r" ^ "a\n");
  [%expect
    {| count=101 first=E0003 3:4 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-004: tab outside a string. *)
let%expect_test "E0005 alternating flood" =
  flood ("module m\n\n" ^ rep n "a\t" ^ "\n");
  [%expect
    {| count=101 first=E0005 3:2 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-050: invalid escape in a plain string. *)
let%expect_test "E0041 flood" =
  flood ("module m\nlet s = \"" ^ rep n "\\q" ^ "\"\n");
  [%expect
    {| count=101 first=E0041 2:10 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-053: non-ASCII in a byte string. *)
let%expect_test "E0043 flood" =
  flood ("module m\nlet s = b\"" ^ rep n "\xc3\xa9" ^ "\"\n");
  [%expect
    {| count=101 first=E0043 2:11 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-051: tab in the margin of a triple-quoted string, one per line, so runs do not collapse. *)
let%expect_test "E0005 triple-quoted margin flood" =
  flood ("module m\nlet s = \"\"\"\n" ^ rep n "    a\n\t\n" ^ "    \"\"\"\n");
  [%expect
    {| count=101 first=E0005 4:1 last=E0006 "999900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* LEX-055: a template whose interpolations are all bad. *)
let%expect_test "E0044 template interpolation flood" =
  flood ("module m\nlet s = f\"" ^ rep 200_000 "{#}" ^ "\"\n");
  [%expect
    {| count=101 first=E0044 2:12 last=E0006 "399900 further diagnostics suppressed (limit 100 per file)" error=true |}]

(* ADR-0016: consecutive identical forbidden characters / lone CRs collapse to one diagnostic with a count and
   a span over the run; the run does not consume the cap. *)
let%expect_test "E0004 run collapses" =
  let _, ds = lex ("module m\n\n# " ^ rep n (utf8 0x200B) ^ "\n") in
  List.iter
    (fun (d : D.t) ->
      Printf.printf "%s %d:%d-%d:%d %s\n" d.code d.span.start.line d.span.start.col d.span.stop.line
        d.span.stop.col d.message)
    ds;
  [%expect
    {| E0004 3:3-3:1000003 forbidden character U+200B (ZERO WIDTH SPACE) repeated 1000000 times — risk: hidden or reordered source text (Trojan Source) |}]

let%expect_test "E0003 run collapses" =
  let _, ds = lex ("module m\n\n# a" ^ rep 5 "\r" ^ "b\n") in
  List.iter
    (fun (d : D.t) ->
      Printf.printf "%s %d:%d-%d:%d %s\n" d.code d.span.start.line d.span.start.col d.span.stop.line
        d.span.stop.col d.message)
    ds;
  [%expect {| E0003 3:4-3:9 lone carriage return repeated 5 times |}]

(* A single character keeps its original text (the tests/conformance/lexical expectations rely on it). *)
let%expect_test "single forbidden character unchanged" =
  let _, ds = lex ("module m\n\n# a" ^ utf8 0x200B ^ "b\n") in
  List.iter (fun (d : D.t) -> Printf.printf "%s %s\n" d.code d.message) ds;
  [%expect
    {| E0004 forbidden character U+200B (ZERO WIDTH SPACE) — risk: hidden or reordered source text (Trojan Source) |}]

(* Boundary: exactly [limit] diagnostics are all kept, with no summary; limit + 1 gives a summary saying 1. *)
let%expect_test "limit boundary" =
  let run k =
    let _, ds = lex ("module m\n\n# " ^ rep k (utf8 0x200B ^ "a") ^ "\n") in
    let last = List.nth ds (List.length ds - 1) in
    Printf.printf "%d -> %d, last=%s\n" k (List.length ds) last.code
  in
  run 100;
  run 101;
  [%expect {|
    100 -> 100, last=E0004
    101 -> 101, last=E0006
    |}]

(* Language-server stability: the kept diagnostics of a longer flood are the same list as those of a shorter one
   (same first 100, same order); only the summary count differs. Deterministic: two runs are equal. *)
let%expect_test "prefix stable and deterministic" =
  let get k = snd (lex ("module m\n\n# " ^ rep k (utf8 0x200B ^ "a") ^ "\n")) in
  let kept ds = List.filteri (fun i _ -> i < 100) ds in
  Printf.printf "%b %b\n" (kept (get 1_000) = kept (get 5_000)) (get 5_000 = get 5_000);
  [%expect {| true true |}]

(* Mixed sources share one budget: a flood of E0041 after one E0004 keeps the E0004 first (Source_check runs
   before the lexer), and a file whose only errors are suppressed ones cannot exist (the first [limit] are kept). *)
let%expect_test "shared budget keeps the pre-lexing diagnostic" =
  let _, ds = lex ("module m\n# " ^ utf8 0x200B ^ "\nlet s = \"" ^ rep n "\\q" ^ "\"\n") in
  let first = List.hd ds in
  Printf.printf "%d %s %s\n" (List.length ds) first.code (List.nth ds 100).code;
  [%expect {| 101 E0004 E0006 |}]

(* The whole front end (lexer + layout) is bounded too. *)
let%expect_test "Parse.tokens flood" =
  let _, ds = Parse.tokens ~file:"t.egd" ("module m\n\n# " ^ rep n (utf8 0x200B ^ "a") ^ "\n") in
  Printf.printf "%d %b\n" (List.length ds) (has_error ds);
  [%expect {| 101 true |}]
