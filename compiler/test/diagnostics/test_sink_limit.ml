(* T-1080 — bounded sink (TOOL-040): a sink created with a limit keeps the first [limit] diagnostics, counts the
   rest in O(1) memory, and ends [to_list] with one E0006 summary (fixed text, counts only). *)

module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let sp line = Span.make ~file:"f.egd" ~start:{ Span.line; col = 1 } ~stop:{ Span.line; col = 2 }
let err line = D.error ~rule:"LEX-003" ~code:"E0004" (sp line) "x"

let%expect_test "unbounded sink is unchanged" =
  let s = D.Sink.create () in
  for i = 1 to 1000 do
    D.Sink.report s (err i)
  done;
  Printf.printf "%d %d\n" (List.length (D.Sink.to_list s)) (D.Sink.suppressed s);
  [%expect {| 1000 0 |}]

let%expect_test "limit, summary, order, has_errors" =
  let s = D.Sink.create ~limit:3 () in
  for i = 1 to 10 do
    D.Sink.report s (err i)
  done;
  List.iter
    (fun (d : D.t) -> Printf.printf "%s %d %s\n" d.code d.span.start.line d.message)
    (D.Sink.to_list s);
  Printf.printf "%d %b\n" (D.Sink.suppressed s) (D.Sink.has_errors s);
  [%expect
    {|
    E0004 1 x
    E0004 2 x
    E0004 3 x
    E0006 4 7 further diagnostics suppressed (limit 3 per file; E0004: 7)
    7 true
    |}]

(* A suppressed error still counts for has_errors even if the kept ones are warnings. *)
let%expect_test "suppressed error is still an error" =
  let s = D.Sink.create ~limit:1 () in
  D.Sink.report s (D.warning ~rule:"LEX-005" ~code:"W0001" (sp 1) "w");
  D.Sink.report s (err 2);
  Printf.printf "%b %d\n" (D.Sink.has_errors s) (List.length (D.Sink.to_list s));
  [%expect {| true 2 |}]

(* Memory: the live size of the sink does not grow with the number of reports. *)
let%expect_test "accumulator memory is bounded" =
  let s = D.Sink.create ~limit:100 () in
  let d = err 1 in
  for _ = 1 to 1_000_000 do
    D.Sink.report s d
  done;
  Printf.printf "%b\n" (Obj.reachable_words (Obj.repr s) < 10_000);
  [%expect {| true |}]

(* Per-class counts of the security-relevant codes, singular text, other codes uncounted. *)
let%expect_test "summary text" =
  let s = D.Sink.create ~limit:1 () in
  D.Sink.report s (err 1);
  D.Sink.report s (D.error ~rule:"LEX-004" ~code:"E0005" (sp 2) "t");
  Printf.printf "%s\n" (List.nth (D.Sink.to_list s) 1).message;
  D.Sink.report s (D.error ~rule:"LEX-001" ~code:"E0001" (sp 3) "u");
  D.Sink.report s (err 4);
  Printf.printf "%s\n" (List.nth (D.Sink.to_list s) 1).message;
  [%expect
    {|
    1 further diagnostic suppressed (limit 1 per file)
    3 further diagnostics suppressed (limit 1 per file; E0001: 1; E0004: 1)
    |}]
