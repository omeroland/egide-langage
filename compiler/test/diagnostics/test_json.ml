(* JSON rendering of diagnostics (TOOL-040, TOOL-042), validated against docs/diagnostics.schema.json. *)

module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span
module J = Json_check

let sp ?(file = "t.egd") l1 c1 l2 c2 =
  Span.make ~file ~start:{ Span.line = l1; col = c1 } ~stop:{ Span.line = l2; col = c2 }

let schema = lazy (J.load_schema ())

let validate_json s =
  let schema = Lazy.force schema in
  J.validate ~root:schema schema (J.parse s)

let check d =
  let s = D.to_json d in
  if String.contains s '\n' then print_endline "NOT ONE LINE";
  print_endline s;
  match validate_json s with
  | [] -> print_endline "schema: ok"
  | errs -> List.iter print_endline errs

let example =
  let file = "src/cart.egd" in
  D.error ~rule:"MEM-021" ~code:"E0301"
    ~labels:[ D.label (sp ~file 12 16 12 29) "used here" ]
    ~notes:[ "an inout argument must be exclusively accessible during the call (MEM-021)" ]
    ~fixes:
      [
        D.fix "copy the element first" [ D.edit (sp ~file 12 5 12 5) "let first = cart.lines[0]\n" ];
      ]
    (sp ~file 12 9 12 14)
    "`cart` is passed as inout and also used by another argument of the same call"

(* spec: TOOL-040, TOOL-042 — the docs/diagnostics.md example, every field present. *)
let%expect_test "docs example renders with all fields and validates" =
  check example;
  [%expect
    {|
    {"code":"E0301","severity":"error","rule":"MEM-021","message":"`cart` is passed as inout and also used by another argument of the same call","span":{"file":"src/cart.egd","start":{"line":12,"col":9},"end":{"line":12,"col":14}},"labels":[{"span":{"file":"src/cart.egd","start":{"line":12,"col":16},"end":{"line":12,"col":29}},"message":"used here"}],"notes":["an inout argument must be exclusively accessible during the call (MEM-021)"],"fixes":[{"message":"copy the element first","edits":[{"span":{"file":"src/cart.egd","start":{"line":12,"col":5},"end":{"line":12,"col":5}},"replacement":"let first = cart.lines[0]\n"}]}]}
    schema: ok
    |}]

(* spec: TOOL-042 — a minimal warning: empty arrays are still present. *)
let%expect_test "minimal warning validates" =
  check (D.warning ~rule:"LEX-061" ~code:"W0001" (sp 1 1 1 2) "w");
  [%expect
    {|
    {"code":"W0001","severity":"warning","rule":"LEX-061","message":"w","span":{"file":"t.egd","start":{"line":1,"col":1},"end":{"line":1,"col":2}},"labels":[],"notes":[],"fixes":[]}
    schema: ok
    |}]

(* Escaping: JSON is always valid UTF-8 (invalid bytes become U+FFFD); control, bidi and line
   separator characters are \u-escaped; other non-ASCII text (é, emoji) is kept as is. *)
let%expect_test "strings are escaped safely" =
  check
    (D.error ~rule:"LEX-050" ~code:"E0041"
       (sp ~file:"dir/\"q\".egd" 1 1 1 2)
       "q\" b\\ n\n t\t c\x01 del\x7f bidi\xE2\x80\xAE ls\xE2\x80\xA8 bad\xFF é🎉");
  [%expect
    {|
    {"code":"E0041","severity":"error","rule":"LEX-050","message":"q\" b\\ n\n t\t c\u0001 del\u007f bidi\u202e ls\u2028 bad\ufffd é🎉","span":{"file":"dir/\"q\".egd","start":{"line":1,"col":1},"end":{"line":1,"col":2}},"labels":[],"notes":[],"fixes":[]}
    schema: ok
    |}]

(* Columns count Unicode scalar values (docs/diagnostics.md), end to end through the lexer: the `;`
   after a string holding `é` and an emoji is at column 9 (it would be 13 if columns counted bytes). *)
let%expect_test "lexer columns in JSON count scalar values" =
  let _, diags = Egide_syntax.Parse.tokens ~file:"t.egd" "module m\nx = \"é🎉\";\n" in
  List.iter
    (fun (d : D.t) ->
      if d.code = "E0050" then
        Printf.printf "%d:%d-%d\n" d.span.start.line d.span.start.col d.span.stop.col)
    diags;
  [%expect {| 2:9-10 |}]

(* The validator and the schema have teeth: each mutation of a valid object is rejected. *)
let%expect_test "schema rejects malformed diagnostics" =
  let base = D.to_json (D.warning ~rule:"LEX-061" ~code:"W0001" (sp 1 1 1 2) "w") in
  let mutate from into =
    let i = Str.search_forward (Str.regexp_string from) base 0 in
    String.sub base 0 i ^ into
    ^ String.sub base (i + String.length from) (String.length base - i - String.length from)
  in
  List.iter
    (fun (from, into) ->
      let s = mutate from into in
      Printf.printf "%s -> %s: %s\n" from into (String.concat "; " (validate_json s)))
    [
      ({|"W0001"|}, {|"X12"|});
      ({|"warning"|}, {|"fatal"|});
      ({|"LEX-061"|}, {|"lex61"|});
      ({|"LEX-061"|}, "null");
      ({|"message":"w"|}, {|"message":""|});
      ({|"col":1|}, {|"col":0|});
      ({|"labels":[],|}, "");
      ({|"fixes":[]|}, {|"fixes":[{"message":"m","edits":[]}]|});
      ({|"notes":[]|}, {|"notes":[1]|});
      ({|"code"|}, {|"extra":1,"code"|});
    ];
  [%expect
    {|
    "W0001" -> "X12": /code: "X12" does not match ^([EW][0-9]{4}|ICE)$
    "warning" -> "fatal": /severity: value not in enum
    "LEX-061" -> "lex61": /rule: "lex61" does not match ^[A-Z]+-[0-9]{3}$
    "LEX-061" -> null:
    "message":"w" -> "message":"": /message: string too short
    "col":1 -> "col":0: /span/start/col: below minimum
    "labels":[], -> : /: missing required property labels
    "fixes":[] -> "fixes":[{"message":"m","edits":[]}]: /fixes/0/edits: too few items
    "notes":[] -> "notes":[1]: /notes/0: expected type string, got integer
    "code" -> "extra":1,"code": /: unexpected property extra
    |}]

(* spec: TOOL-042 — property: any diagnostic built through the API renders as one line of JSON that
   parses and validates, whatever bytes its strings contain, and valid UTF-8 text round-trips. *)
let gen_diag =
  let open QCheck.Gen in
  let any_string = string_size ~gen:char (int_bound 12) in
  let text = map (fun s -> "m" ^ s) any_string in
  let pos = map2 (fun line col -> { Span.line; col }) (int_range 1 500) (int_range 1 200) in
  let span = map3 (fun file start stop -> Span.make ~file ~start ~stop) any_string pos pos in
  let code = int_bound 9999 in
  let rule =
    map2
      (fun p n -> Printf.sprintf "%s-%03d" p n)
      (oneof_list [ "LEX"; "SYN"; "MEM"; "SEC" ])
      (int_bound 999)
  in
  let label = map2 D.label span any_string in
  let fix = map2 D.fix text (list_size (int_range 1 3) (map2 D.edit span any_string)) in
  map
    (fun ((warn, n, rule, msg), (span, labels, notes, fixes)) ->
      let code = Printf.sprintf "%c%04d" (if warn then 'W' else 'E') n in
      (if warn then D.warning else D.error) ~rule ~labels ~notes ~fixes ~code span msg)
    (pair (quad bool code rule text)
       (quad span
          (list_size (int_bound 3) label)
          (list_size (int_bound 3) text)
          (list_size (int_bound 2) fix)))

let%test "property: to_json is one valid line for arbitrary diagnostics" =
  QCheck.Test.check_exn
    (QCheck.Test.make ~count:500 ~name:"to_json validates" (QCheck.make gen_diag) (fun d ->
         let s = D.to_json d in
         (not (String.contains s '\n')) && validate_json s = []));
  true

(* Valid UTF-8 text over all scalar values, biased towards ASCII and the escaped ranges. *)
let utf8_text =
  let open QCheck.Gen in
  let scalar =
    oneof_weighted
      [
        (3, int_range 0 0x7F);
        (1, int_range 0x80 0x9F);
        (1, int_range 0x2000 0x206F);
        ( 1,
          map (fun c -> if c >= 0xD800 && c <= 0xDFFF then 0xFFFD else c) (int_range 0xA0 0x10FFFF)
        );
      ]
  in
  map
    (fun cps ->
      let b = Buffer.create 16 in
      List.iter (fun c -> Buffer.add_utf_8_uchar b (Uchar.of_int c)) cps;
      Buffer.contents b)
    (list_size (int_bound 20) scalar)

let%test "property: valid UTF-8 messages round-trip through JSON" =
  QCheck.Test.check_exn
    (QCheck.Test.make ~count:500 ~name:"message round-trip" (QCheck.make utf8_text) (fun s ->
         let msg = "m" ^ s in
         match J.parse (D.to_json (D.error ~rule:"LEX-001" ~code:"E0001" (sp 1 1 1 2) msg)) with
         | J.Obj kv -> List.assoc "message" kv = J.Str msg
         | _ -> false));
  true
