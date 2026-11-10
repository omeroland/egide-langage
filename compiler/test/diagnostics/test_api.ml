(* Diagnostic constructors and the sink (TOOL-040). Malformed diagnostics are compiler bugs and are
   rejected at construction, so every emitted diagnostic satisfies docs/diagnostics.schema.json. *)

module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let sp l c =
  Span.make ~file:"t.egd" ~start:{ Span.line = l; col = c } ~stop:{ Span.line = l; col = c + 1 }

let try_ f =
  match f () with
  | (_ : D.t) -> print_endline "accepted"
  | exception Invalid_argument m -> print_endline m

(* spec: TOOL-040 — a stable code (E/W + 4 digits), a spec rule id, a one-line non-empty message. *)
let%expect_test "constructors validate code, rule, message, notes and fixes" =
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"E0001" (sp 1 1) "ok");
  try_ (fun () -> D.warning ~rule:"LEX-001" ~code:"W0999" (sp 1 1) "ok");
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"E1" (sp 1 1) "bad code");
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"W0001" (sp 1 1) "warning code on an error");
  try_ (fun () -> D.warning ~rule:"LEX-001" ~code:"E0001" (sp 1 1) "error code on a warning");
  try_ (fun () -> D.error ~rule:"SYN-*" ~code:"E0100" (sp 1 1) "bad rule");
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"E0001" (sp 1 1) "");
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"E0001" ~notes:[ "" ] (sp 1 1) "m");
  try_ (fun () -> D.error ~rule:"LEX-001" ~code:"E0001" ~fixes:[ D.fix "f" [] ] (sp 1 1) "m");
  try_ (fun () ->
      D.error ~rule:"LEX-001" ~code:"E0001" ~fixes:[ D.fix "" [ D.edit (sp 1 1) "" ] ] (sp 1 1) "m");
  [%expect
    {|
    accepted
    accepted
    Diagnostic: malformed code "E1"
    Diagnostic: an error needs an E code, got "W0001"
    Diagnostic: a warning needs a W code, got "E0001"
    Diagnostic: malformed rule id "SYN-*"
    Diagnostic: empty message
    Diagnostic: empty note
    Diagnostic: fix "f" has no edits
    Diagnostic: empty fix message
    |}]

(* spec: TOOL-040 — fields are readable by passes and tools. *)
let%expect_test "fields of a diagnostic" =
  let d =
    D.error ~rule:"MEM-021" ~code:"E0301"
      ~labels:[ D.label (sp 2 3) "here" ]
      ~notes:[ "n" ]
      ~fixes:[ D.fix "f" [ D.edit (sp 1 1) "x" ] ]
      (sp 1 1) "m"
  in
  Printf.printf "%s %s %s %s %d %d %d\n" d.code (D.severity_to_string d.severity)
    (Option.get d.rule) d.message (List.length d.labels) (List.length d.notes) (List.length d.fixes);
  let l = List.hd d.labels and f = List.hd d.fixes in
  Printf.printf "%s %d %s %s\n" l.message l.span.start.line f.message (List.hd f.edits).replacement;
  [%expect {|
    E0301 error MEM-021 m 1 1 1
    here 2 f x
    |}]

(* The sink keeps emission order; only errors count for has_errors. *)
let%expect_test "sink order and has_errors" =
  let s = D.Sink.create () in
  D.Sink.report s (D.warning ~rule:"LEX-001" ~code:"W0002" (sp 1 1) "first");
  Printf.printf "%b\n" (D.Sink.has_errors s);
  D.Sink.report s (D.error ~rule:"LEX-001" ~code:"E0001" (sp 2 1) "second");
  Printf.printf "%b\n" (D.Sink.has_errors s);
  List.iter (fun (d : D.t) -> print_endline d.message) (D.Sink.to_list s);
  [%expect {|
    false
    true
    first
    second
    |}]
