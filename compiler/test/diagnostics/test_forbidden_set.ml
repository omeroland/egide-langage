(* T-1033: the LEX-003 set (ADR-0017) against an independently written oracle, over every code point, through the
   real lexer and through the output escaping (LEX-006). Rule ids: LEX-003, LEX-050, LEX-006, LEX-060. *)

module O = Forbidden_oracle
module D = Egide_diagnostics.Diagnostic
module E = Egide_diagnostics.Escape
module F = Egide_diagnostics.Forbidden_set
module L = Egide_syntax.Lexer
module S = Egide_syntax.Source_check

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

let all_scalars f =
  for cp = 0 to 0x10FFFF do
    if O.is_scalar cp then f cp
  done

let failures = ref 0

(* Prints the first 20 failures only. *)
let fail fmt =
  Printf.ksprintf
    (fun s ->
      incr failures;
      if !failures <= 20 then print_endline ("FAIL " ^ s))
    fmt

(* spec: LEX-003 — the membership function equals the property-defined set on every code point (surrogates and
   values above U+10FFFF are not scalar values and are not members). *)
let%test "Forbidden_set.mem equals the oracle over 0..0x10FFFF" =
  let ok = ref true in
  for cp = 0 to 0x10FFFF do
    if F.mem cp <> (O.is_scalar cp && O.forbidden cp) then begin
      ok := false;
      fail "U+%04X: mem=%b oracle=%b" cp (F.mem cp) (O.forbidden cp)
    end
  done;
  !ok

let%test "Forbidden_set.mem is total" = (not (F.mem (-1))) && not (F.mem 0x110000)

(* spec: LEX-003 — reviewer's gaps (ADR-0017 S2), TAG, Hangul fillers, CGJ, variation selectors, noncharacters *)
let%test "the reviewer's gap list is members" =
  let gaps =
    [
      0x17B4;
      0x17B5;
      0x2065;
      0xFFF0;
      0xFFF1;
      0xFFF8;
      0xE0080;
      0xE00FF;
      0xE01F0;
      0xE0FFF;
      0xE0001;
      0xE0020;
      0xE007F;
      0x115F;
      0x1160;
      0x3164;
      0xFFA0;
      0x34F;
      0xFE00;
      0xFE0F;
      0xE0100;
      0xE01EF;
      0x180B;
      0x180F;
      0xAD;
      0xFDD0;
      0xFDEF;
      0xFFFE;
      0xFFFF;
      0x1FFFF;
      0x10FFFF;
      0x2028;
      0x2029;
    ]
  in
  List.for_all
    (fun cp ->
      F.mem cp
      ||
      (fail "U+%04X not a member" cp;
       false))
    gaps

(* spec: LEX-003 — neighbours of the set are not members (no "all Cn"; Zs is handled by the lexer, not by the set) *)
let neighbours =
  [ 0xAC; 0xAE; 0x378; 0x2027; 0x202F; 0xFE10; 0xFFEF; 0xE1000; 0x10FFFD; 0x20; 0x7E ]

let%test "neighbours are not members" =
  List.for_all
    (fun cp ->
      (not (F.mem cp))
      ||
      (fail "U+%04X is a member" cp;
       false))
    neighbours

(* ---- through the lexer ---- *)

let lex src = snd (L.tokenize ~file:"t.egd" src)
let has code ds = List.exists (fun (d : D.t) -> d.code = code) ds
let codes ds = String.concat "," (List.map (fun (d : D.t) -> d.code) ds)

(* One comment line per scalar value (LF, CR and HT have their own rules: E0004 is not their code), after a first
   line, so that a U+FEFF is mid-file. The set of lines reported E0004 is the set of forbidden scalars. Linear in the
   size of the input: a quadratic lexer would not finish. T-1080: a file reports at most [Sink.default_limit]
   diagnostics, so the sweep is cut into files of [batch] scalars (< limit, so nothing is suppressed); the property
   checked is unchanged. *)
let%test "the lexer reports E0004 for exactly the oracle set, in comments (all scalars)" =
  let batch = 64 in
  let cps = ref [] in
  all_scalars (fun cp -> if cp <> 0x0A && cp <> 0x0D && cp <> 0x09 then cps := cp :: !cps);
  let cps = Array.of_list (List.rev !cps) in
  let rejected = Hashtbl.create 8192 in
  let ok = ref true in
  let i = ref 0 in
  while !i < Array.length cps do
    let m = min batch (Array.length cps - !i) in
    let b = Buffer.create 1024 in
    Buffer.add_string b "module m\n";
    for k = 0 to m - 1 do
      Buffer.add_string b "# ";
      Buffer.add_string b (utf8 cps.(!i + k));
      Buffer.add_char b '\n'
    done;
    List.iter
      (fun (d : D.t) ->
        if d.code <> "E0004" then begin
          ok := false;
          fail "unexpected %s at line %d" d.code d.span.start.line
        end
        else if d.span.start.col <> 3 || d.span.stop.col <> 4 then begin
          ok := false;
          fail "span of E0004 at line %d" d.span.start.line
        end
        else Hashtbl.replace rejected cps.(!i + d.span.start.line - 2) ())
      (lex (Buffer.contents b));
    i := !i + m
  done;
  Array.iter
    (fun cp ->
      let r = Hashtbl.mem rejected cp in
      if r <> O.forbidden cp then begin
        ok := false;
        fail "U+%04X: lexer rejects=%b oracle=%b" cp r (O.forbidden cp)
      end;
      (* spec: LEX-006 — everything the lexer rejects is escaped by the output layer *)
      if r && not (E.is_dangerous cp) then begin
        ok := false;
        fail "U+%04X rejected by the lexer but not Escape.is_dangerous" cp
      end)
    cps;
  !ok

let forbidden_list =
  let l = ref [] in
  all_scalars (fun cp ->
      if O.forbidden cp && cp <> 0x0A && cp <> 0x0D && cp <> 0x09 then l := cp :: !l);
  List.rev !l

(* spec: LEX-003 — in code and in string literals as well: one E0004 each, and no E0051 for the character itself *)
let%test "every forbidden code point is E0004 in code and in strings" =
  let src ctx cp =
    match ctx with
    | `Code -> "let x = " ^ utf8 cp ^ "1\n"
    | `String -> "let s = \"a" ^ utf8 cp ^ "b\"\n"
  in
  List.for_all
    (fun cp ->
      List.for_all
        (fun ctx ->
          match lex (src ctx cp) with
          | [ d ] ->
              d.code = "E0004"
              ||
              (fail "U+%04X: %s" cp d.code;
               false)
          | ds ->
              fail "U+%04X: %s" cp (codes ds);
              false)
        [ `Code; `String ])
    forbidden_list

(* spec: LEX-003 — HT stays legal in strings (LEX-004); other Cc are E0004 *)
let%test "HT is allowed in a string, not LF-splitting" = lex "let s = \"a\tb\"\n" = []

(* spec: LEX-003 — Zs other than U+0020: accepted in comments and strings, E0051 in code *)
let%test "Zs other than U+0020 is accepted in comments and strings and E0051 in code" =
  List.for_all
    (fun cp ->
      cp = 0x20
      ||
      let c = utf8 cp in
      let comment = lex ("# a" ^ c ^ "b\n") and str = lex ("let s = \"a" ^ c ^ "b\"\n") in
      let code = lex ("let x =" ^ c ^ "1\n") in
      (comment = []
      ||
      (fail "U+%04X in comment: %s" cp (codes comment);
       false))
      && (str = []
         ||
         (fail "U+%04X in string: %s" cp (codes str);
          false))
      &&
      match code with
      | [ d ] ->
          d.code = "E0051"
          ||
          (fail "U+%04X in code: %s" cp d.code;
           false)
      | ds ->
          fail "U+%04X in code: %s" cp (codes ds);
          false)
    (List.concat_map (fun (lo, hi) -> List.init (hi - lo + 1) (fun k -> lo + k)) O.zs)

let%test "neighbours are accepted in comments and strings" =
  List.for_all
    (fun cp ->
      let c = utf8 cp in
      (lex ("# a" ^ c ^ "b\n") = [] && lex ("let s = \"a" ^ c ^ "b\"\n") = [])
      ||
      (fail "U+%04X rejected" cp;
       false))
    neighbours

(* spec: LEX-050 (ADR-0017) — `\u{...}` accepts every scalar value, one literal per line; surrogates and values above
   U+10FFFF are E0041 *)
let%test "\\u{...} accepts every scalar value" =
  let b = Buffer.create (20 * 1024 * 1024) in
  all_scalars (fun cp -> Buffer.add_string b (Printf.sprintf "let s = \"\\u{%X}\"\n" cp));
  match lex (Buffer.contents b) with
  | [] -> true
  | d :: _ as ds ->
      fail "%d diagnostics, first %s at line %d" (List.length ds) d.code d.span.start.line;
      false

let%test "\\u{...} rejects surrogates and values above U+10FFFF with E0041" =
  List.for_all
    (fun h ->
      match lex (Printf.sprintf "let s = \"\\u{%s}\"\n" h) with
      | [ d ] ->
          d.code = "E0041"
          ||
          (fail "%s: %s" h d.code;
           false)
      | ds ->
          fail "%s: %s" h (codes ds);
          false)
    [ "D800"; "DBFF"; "DC00"; "DFFF"; "110000"; "FFFFFF" ]

let%test "the three escapes of the acceptance criteria are accepted" =
  lex "let a = \"\\u{200D}\"\nlet b = \"\\u{E0041}\"\nlet c = \"\\u{1B}\"\n" = []

(* spec: LEX-003 — linear time: 4 MB of forbidden code points on one line, 1 MB of valid text *)
let%test "a long line of forbidden code points is linear" =
  let n = 1_000_000 in
  let src = "# " ^ String.concat "" (List.init n (fun _ -> "\xE2\x80\xAE")) ^ "\n" in
  let ds = lex src in
  (* T-1080 (ADR-0016): the run of identical characters is one E0004 spanning all of it *)
  (match ds with
    | [ d ] -> d.code = "E0004" && d.span.start.col = 3 && d.span.stop.col = 3 + n
    | _ -> false)
  && S.check ~file:"t.egd" (String.make 4_000_000 'a') = []

(* ---- the pinned table (LEX-003: Unicode 16.0.0, embedded, never read from the host) ---- *)

module T = Egide_source.Forbidden_table

let read file =
  let ic = open_in_bin file in
  Fun.protect
    ~finally:(fun () -> close_in ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let%test "the table is Unicode 16.0.0" = T.unicode_version = "16.0.0"

(* The upstream digests recorded in the generated header are the ones pinned in tools/gen/unicode-16.0.0.sha256, so a
   table regenerated from other files differs here (and the generator refuses such files anyway). *)
let%test "the table records the pinned upstream digests" =
  let pins =
    String.split_on_char '\n' (read "../../../tools/gen/unicode-16.0.0.sha256")
    |> List.filter_map (fun l ->
        let l = String.trim l in
        if l = "" || l.[0] = '#' then None
        else
          match String.split_on_char ' ' l with
          | digest :: rest -> Some (String.trim (String.concat " " rest), digest)
          | [] -> None)
  in
  List.sort compare pins = List.sort compare T.source_digests && List.length pins = 3

(* MD5 of the canonical text of the ranges: any change to the embedded table, even one that keeps this test file
   green elsewhere, changes it. Update it together with the oracle, in a reviewed change. *)
let pinned_table_digest = "0af5d280e38a86a8cd7768abc0aabe83"

let%test "the table digest is pinned" =
  let canonical = String.concat "," (Array.to_list (Array.map (Printf.sprintf "%X") T.ranges)) in
  let d = Digest.to_hex (Digest.string canonical) in
  d = pinned_table_digest
  ||
  (Printf.printf "table digest is %s\n" d;
   false)

let%test "the table is flat, sorted, disjoint and non-adjacent" =
  let r = T.ranges in
  Array.length r mod 2 = 0
  &&
  let ok = ref true in
  for i = 0 to (Array.length r / 2) - 1 do
    if r.(2 * i) > r.((2 * i) + 1) then ok := false;
    if i > 0 && r.(2 * i) <= r.((2 * i) - 1) + 1 then ok := false
  done;
  !ok

(* The table module is data only: it reads nothing from the host at run time. *)
let%test "the table module performs no I/O" =
  let src = read "../../lib/source/forbidden_table.ml" in
  let contains sub =
    try
      ignore (Str.search_forward (Str.regexp_string sub) src 0);
      true
    with Not_found -> false
  in
  not (List.exists contains [ "open_in"; "Sys."; "Unix"; "In_channel"; "Stdlib.input" ])

(* spec: LEX-003 — the class label in the E0004 message (docs/diagnostics.md): U+180F is a variation selector, U+180E
   is Cf, U+E0041 a tag character, U+FDD0 a noncharacter. *)
let%test "E0004 class labels" =
  let label cp = match lex ("# a" ^ utf8 cp ^ "b\n") with [ d ] -> d.message | _ -> "" in
  let has_sub s sub =
    try
      ignore (Str.search_forward (Str.regexp_string sub) s 0);
      true
    with Not_found -> false
  in
  List.for_all
    (fun (cp, l) ->
      has_sub (label cp) ("(" ^ l ^ ")")
      ||
      (fail "U+%04X: %s" cp (label cp);
       false))
    [
      (0x180F, "variation selector");
      (0x180B, "variation selector");
      (0x180E, "format or default-ignorable character");
      (0xE0041, "tag character");
      (0xFDD0, "noncharacter");
      (0x1B, "control character");
    ]
