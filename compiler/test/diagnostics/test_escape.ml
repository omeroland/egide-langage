(* LEX-006: one escaping function for every tool output (T-1039, ADR-0017 S1). Covers the escaping
   function itself, its machine-format variant, the narrow forbidden-set interface that T-1033 will
   replace, the stdout/stderr guard, and the attack cases (terminal escape sequences, bidi
   overrides, zero-width characters) through every diagnostic renderer. *)

module D = Egide_diagnostics.Diagnostic
module E = Egide_diagnostics.Escape
module F = Egide_diagnostics.Forbidden_set
module O = Egide_diagnostics.Output
module Span = Egide_source.Span
module J = Json_check

let sp ?(file = "t.egd") l1 c1 l2 c2 =
  Span.make ~file ~start:{ Span.line = l1; col = c1 } ~stop:{ Span.line = l2; col = c2 }

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

(* Every class of LEX-006 with its expected rendering. *)
let classes =
  [
    ("ESC", utf8 0x1B, "\\u{1B}", "\\u001b");
    ("CSI U+009B", utf8 0x9B, "\\u{9B}", "\\u009b");
    ("NEL U+0085", utf8 0x85, "\\u{85}", "\\u0085");
    ("ZWSP", utf8 0x200B, "\\u{200B}", "\\u200b");
    ("RLO", utf8 0x202E, "\\u{202E}", "\\u202e");
    ("TAG LATIN A", utf8 0xE0041, "\\u{E0041}", "\\udb40\\udc41");
    ("DEL", utf8 0x7F, "\\u{7F}", "\\u007f");
    ("NBSP (Zs)", utf8 0xA0, "\\u{A0}", "\\u00a0");
    ("IDEOGRAPHIC SPACE (Zs)", utf8 0x3000, "\\u{3000}", "\\u3000");
    ("backslash", "\\", "\\\\", "\\\\");
    ("LF", "\n", "\\n", "\\n");
    ("CR", "\r", "\\r", "\\r");
    ("TAB", "\t", "\\t", "\\t");
    ("LINE SEPARATOR", utf8 0x2028, "\\u{2028}", "\\u2028");
    ("PARAGRAPH SEPARATOR", utf8 0x2029, "\\u{2029}", "\\u2029");
    ("NUL", "\000", "\\u{0}", "\\u0000");
    ("invalid byte", "\xFF", "\\xFF", "\\ufffd");
  ]

(* spec: LEX-006 — every class is rendered as \u{H}, \\, \n, \r, \t. *)
let%test "display renders every class" =
  List.for_all
    (fun (name, raw, shown, _) ->
      let got = E.display ("a" ^ raw ^ "b") in
      if got <> "a" ^ shown ^ "b" then (
        Printf.printf "%s: got %S want %S\n" name got ("a" ^ shown ^ "b");
        false)
      else true)
    classes

(* spec: LEX-006 — JSON uses \uXXXX (surrogate pairs above U+FFFF); the output is a quoted literal. *)
let%test "json_safe renders every class" =
  List.for_all
    (fun (name, raw, _, json) ->
      let got = E.json_safe ("a" ^ raw ^ "b") in
      if got <> "\"a" ^ json ^ "b\"" then (
        Printf.printf "%s: got %S want %S\n" name got ("\"a" ^ json ^ "b\"");
        false)
      else true)
    classes

(* spec: LEX-006 — printable text is untouched. *)
let%test "ordinary text is untouched" =
  let t = "let s = é🎉 ok # ~ {x} /" in
  E.display t = t && E.json_safe t = "\"" ^ t ^ "\""

(* ---- independent oracle for "a code point that must never reach a terminal or a viewer" ---- *)

let oracle_dangerous cp =
  (cp < 0x20 && cp <> 0x0A)
  || (cp >= 0x7F && cp <= 0x9F)
  || cp = 0xA0 || cp = 0xAD || cp = 0x061C || cp = 0x1680
  || (cp >= 0x2000 && cp <= 0x200F)
  || (cp >= 0x2028 && cp <= 0x202F)
  || (cp >= 0x205F && cp <= 0x206F)
  || cp = 0x3000 || cp = 0xFEFF
  || (cp >= 0xE0000 && cp <= 0xE0FFF)

(* True when [s] holds, besides LF, an invalid UTF-8 byte or a dangerous code point. *)
let leaks s =
  let rec go i =
    if i >= String.length s then false
    else
      let d = String.get_utf_8_uchar s i in
      if not (Uchar.utf_decode_is_valid d) then true
      else if oracle_dangerous (Uchar.to_int (Uchar.utf_decode_uchar d)) then true
      else go (i + Uchar.utf_decode_length d)
  in
  go 0

(* Decoder of the \u{H} / \\ / \n / \r / \t / \xHH syntax of [display]. *)
let unescape s =
  let b = Buffer.create 16 in
  let n = String.length s in
  let rec go i =
    if i < n then
      if s.[i] <> '\\' then (
        Buffer.add_char b s.[i];
        go (i + 1))
      else
        match s.[i + 1] with
        | '\\' -> Buffer.add_char b '\\'; go (i + 2)
        | 'n' -> Buffer.add_char b '\n'; go (i + 2)
        | 'r' -> Buffer.add_char b '\r'; go (i + 2)
        | 't' -> Buffer.add_char b '\t'; go (i + 2)
        | 'x' ->
            Buffer.add_char b (Char.chr (int_of_string ("0x" ^ String.sub s (i + 2) 2)));
            go (i + 4)
        | 'u' ->
            let j = String.index_from s i '}' in
            let hex = String.sub s (i + 3) (j - i - 3) in
            Buffer.add_utf_8_uchar b (Uchar.of_int (int_of_string ("0x" ^ hex)));
            go (j + 1)
        | _ -> failwith "bad escape"
  in
  go 0;
  Buffer.contents b

let gen_scalar =
  let open QCheck2.Gen in
  frequency
    [
      (4, char_range 'a' 'z');
      (2, oneof_list [ '\\'; '"'; '{'; '}'; ' ' ]);
      (4, map Char.chr (int_range 0 0x1F) |> map (fun c -> c));
      (2, return '\x7f');
    ]
  |> map (fun c -> String.make 1 c)
  |> fun ascii ->
  frequency
    [
      (6, ascii);
      ( 6,
        oneof_list
          [ 0x80; 0x85; 0x9B; 0x9F; 0xA0; 0xAD; 0x61C; 0x1680; 0x200B; 0x200D; 0x200E; 0x2028;
            0x2029; 0x202A; 0x202E; 0x202F; 0x2060; 0x2065; 0x2066; 0x2069; 0x3000; 0xFEFF;
            0xFE0F; 0xFFF0; 0xE0001; 0xE0041; 0xE007F; 0xE0100; 0xE0FFF ]
        |> map utf8 );
      (3, oneof_list [ 0xE9; 0x4E2D; 0x1F389; 0x10FFFF ] |> map utf8);
    ]

let gen_text = QCheck2.Gen.(map (String.concat "") (list_size (int_bound 12) gen_scalar))

(* spec: LEX-006 — property: no dangerous raw code point survives, and the escaping is injective
   (decoding gives the input back) so that an escaped value cannot be mistaken for another. *)
let%test "property: display leaks nothing and round-trips" =
  QCheck2.Test.check_exn ~rand:(Random.State.make [| 1039 |])
    (QCheck2.Test.make ~count:3000 ~name:"display" gen_text (fun s ->
         let d = E.display s in
         (not (String.contains d '\n')) && (not (leaks d)) && unescape d = s));
  true

(* spec: LEX-006 — property: json_safe is one quoted JSON string that parses back to the input and
   holds no raw dangerous code point (CycloneDX / SARIF / JUnit strings are built with it). *)
let%test "property: json_safe leaks nothing and round-trips" =
  QCheck2.Test.check_exn ~rand:(Random.State.make [| 1040 |])
    (QCheck2.Test.make ~count:3000 ~name:"json_safe" gen_text (fun s ->
         let j = E.json_safe s in
         (not (leaks j)) && (not (String.contains j '\n')) && J.parse j = J.Str s));
  true

(* spec: LEX-006 — arbitrary bytes (invalid UTF-8) never leak either. *)
let%test "property: arbitrary bytes" =
  QCheck2.Test.check_exn ~rand:(Random.State.make [| 1041 |])
    (QCheck2.Test.make ~count:2000 ~name:"bytes"
       QCheck2.Gen.(string_size ~gen:char (int_bound 24))
       (fun s -> (not (leaks (E.display s))) && not (leaks (E.json_safe s))));
  true

(* ---- the narrow forbidden-set interface (T-1033 replaces the provisional implementation) ---- *)

(* spec: LEX-003 — the provisional set covers at least Cc, U+2028/2029, known Cf, bidi, the
   reviewer's gap list; it does not reject neighbours. T-1033 must keep these true. *)
let%test "forbidden set: members and neighbours" =
  let members =
    [ 0x00; 0x09; 0x0A; 0x1B; 0x7F; 0x85; 0x9B; 0xAD; 0x61C; 0x200B; 0x200D; 0x200E; 0x2028;
      0x2029; 0x202E; 0x2060; 0x2065; 0x2066; 0x2069; 0xFEFF; 0xFFF0; 0xFE0F; 0xE0041; 0xE0100;
      0x17B4; 0x3164; 0xFDD0; 0xFFFE; 0x10FFFF ]
  in
  let neighbours = [ 0x20; 0x41; 0xAC; 0xAE; 0xE9; 0x2764; 0xFE10; 0x1F389; 0xE1000 ] in
  List.for_all F.mem members && not (List.exists F.mem neighbours)

(* spec: LEX-006 — the escaping function is a superset of the forbidden set, plus Zs, bidi, DEL. *)
let%test "escape covers the forbidden set, Zs, bidi and DEL" =
  let cps = [ 0xA0; 0x1680; 0x2000; 0x200A; 0x202F; 0x205F; 0x3000; 0x7F; 0x61C; 0x2066 ] in
  List.for_all (fun cp -> E.is_dangerous cp) cps
  && (not (E.is_dangerous 0x20))
  && (not (E.is_dangerous 0x41))
  && List.for_all
       (fun cp ->
         (not (F.mem cp && Uchar.is_valid cp)) || E.is_dangerous cp)
       (List.init 0x110 (fun i -> i * 0x1000))

let read path = In_channel.with_open_bin path In_channel.input_all

(* T-1039 Log: the forbidden set is provisional until T-1033 embeds the property-defined table. This
   test fails once phase 1 has started or T-1033 is done while the provisional set is still wired. *)
let%test "provisional forbidden set is replaced by T-1033 after phase 0" =
  let phase = int_of_string (String.trim (read "../../../tasks/PHASE")) in
  let done_ =
    Array.exists
      (fun f -> String.starts_with ~prefix:"T-1033" f)
      (Sys.readdir "../../../tasks/done")
  in
  let ok = (not F.provisional) || (phase < 1 && not done_) in
  if not ok then
    print_endline "Forbidden_set is still provisional: wire the T-1033 table (LEX-003) behind Forbidden_set.mem";
  ok

(* ---- the stdout/stderr guard ---- *)

(* spec: LEX-006 — defence in depth: a string that reaches the output layer unescaped is neutralised
   (dangerous code points and invalid bytes escaped, LF kept as structure, backslash not doubled). *)
let%test "guard neutralises without double escaping" =
  O.neutralize "a\x1b[1Ab\n\\u{1B} \xE2\x80\xAE \xFF" = "a\\u{1B}[1Ab\n\\u{1B} \\u{202E} \\xFF"

(* ---- attack cases through every diagnostic renderer ---- *)

let hostile =
  "\x1b[1A\x1b[2K\xC2\x9B2J \xE2\x80\xAE(RLO) a\xE2\x80\x8Bb \xF3\xA0\x81\x81 \xC2\xA0 \xC2\x85 \xE2\x80\xA8 \xFF"

let hostile_diag =
  D.error ~rule:"LEX-003" ~code:"E0004"
    ~labels:[ D.label (sp ~file:hostile 1 2 1 4) hostile ]
    ~notes:[ hostile ]
    ~fixes:[ D.fix hostile [ D.edit (sp ~file:hostile 1 1 1 1) hostile ] ]
    (sp ~file:hostile 1 1 1 3) hostile

let hostile_src = "x = \"" ^ hostile ^ "\"\n" ^ hostile ^ "\n"

(* spec: LEX-006 — human output: message, notes, labels, file names, fix text and the excerpt. *)
let%test "human renderers leak nothing" =
  let a = D.to_human hostile_diag in
  let b = D.render_human ~sources:(fun _ -> Some hostile_src) hostile_diag in
  (not (leaks a)) && not (leaks b)

(* spec: LEX-006 — machine output: the JSON line holds no raw code point of the set. *)
let%test "json renderer leaks nothing" =
  let j = D.to_json hostile_diag in
  (not (leaks j)) && not (String.contains j '\n')

(* spec: LEX-006, LEX-003 — the terminal replay attack: ESC[1A and CSI in a string, RLO and ZWSP in
   a comment, in the excerpt. The escape sequence is visible text, carets stay aligned. *)
let%expect_test "excerpt shows ESC[1A, CSI, RLO and ZWSP escaped" =
  let src = "s = \"\x1b[1A\xC2\x9B2J\"\n# \xE2\x80\xAE x\xE2\x80\x8By\n" in
  let render d = print_endline (D.render_human ~sources:(fun _ -> Some src) d) in
  render (D.error ~rule:"LEX-003" ~code:"E0004" (sp 1 6 1 7) "forbidden character U+001B");
  render (D.error ~rule:"LEX-003" ~code:"E0004" (sp 2 3 2 4) "forbidden character U+202E");
  [%expect
    {|
    t.egd:1:6: error[E0004]: forbidden character U+001B (LEX-003)
      |
    1 | s = "\u{1B}[1A\u{9B}2J"
      |      ^^^^^^^^
    t.egd:2:3: error[E0004]: forbidden character U+202E (LEX-003)
      |
    2 | # \u{202E} x\u{200B}y
      |   ^^^^^^^^
    |}]

(* spec: LEX-006 — a message that echoes a string value prints it escaped, backslash included. *)
let%expect_test "messages escape values and backslashes" =
  print_endline
    (D.to_human
       (D.error ~rule:"SEC-002" ~code:"E0412" ~notes:[ "a\nb \\u{1B}[2K" ] (sp 1 1 1 2)
          "reason \x1b[31m\xE2\x80\xAE"));
  [%expect
    {|
    t.egd:1:1: error[E0412]: reason \u{1B}[31m\u{202E} (SEC-002)
      note: a\nb \\u{1B}[2K
    |}]

(* ---- lint: nothing prints a source string without the escaping function ---- *)

let strip_comments s =
  (* Remove OCaml comments (non-nested enough for this code base) so documentation may mention the names. *)
  Str.global_replace (Str.regexp "(\\*\\([^*]\\|\\*[^)]\\)*\\*)") "" s

let forbidden_primitives =
  [ "print_string"; "print_endline"; "print_char"; "prerr_endline"; "prerr_string"; "printf";
    "eprintf"; "output_string"; "Out_channel.output"; "Out_channel.output_string"; "stdout";
    "stderr"; "Format.print" ]

let contains s sub =
  try ignore (Str.search_forward (Str.regexp_string sub) s 0); true with Not_found -> false

(* spec: LEX-006 — the CLI writes to stdout/stderr only through Output (which neutralises); the
   renderers of the diagnostics library use Escape and never the raw primitives or the old Text
   escapers. Output.ml and its test are the only places allowed to touch the channels. *)
let%test "lint: main.ml prints only through Output" =
  let src = strip_comments (read "../../bin/main.ml") in
  let bad = List.filter (contains src) forbidden_primitives in
  if bad <> [] then Printf.printf "main.ml uses raw primitives: %s\n" (String.concat ", " bad);
  bad = [] && contains src "Output."

let%test "lint: diagnostic.ml renders through Escape only" =
  let src = strip_comments (read "../../lib/diagnostics/diagnostic.ml") in
  let bad =
    List.filter (contains src)
      ("Text.sanitize" :: "Text.json_string" :: "<U+" :: forbidden_primitives)
  in
  if bad <> [] then Printf.printf "diagnostic.ml: %s\n" (String.concat ", " bad);
  bad = [] && contains src "Escape."

let%test "lint: Text no longer exports an escaper" =
  let src = read "../../lib/diagnostics/text.mli" in
  not (contains src "sanitize" || contains src "json_string")
