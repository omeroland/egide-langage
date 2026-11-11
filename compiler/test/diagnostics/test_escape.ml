(* LEX-006: one escaping function for every tool output (T-1039, ADR-0017 S1). Covers the escaping
   function itself, its machine-format variant, the narrow forbidden-set interface that T-1033 will
   replace, the stdout/stderr guard, and the attack cases (terminal escape sequences, bidi
   overrides, zero-width characters) through every diagnostic renderer. *)

module D = Egide_diagnostics.Diagnostic
module E = Egide_diagnostics.Escape
module F = Egide_diagnostics.Forbidden_set
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
        | '\\' ->
            Buffer.add_char b '\\';
            go (i + 2)
        | 'n' ->
            Buffer.add_char b '\n';
            go (i + 2)
        | 'r' ->
            Buffer.add_char b '\r';
            go (i + 2)
        | 't' ->
            Buffer.add_char b '\t';
            go (i + 2)
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
  let ascii =
    oneof_weighted
      [
        (4, char_range 'a' 'z');
        (2, oneof_list [ '\\'; '"'; '{'; '}'; ' ' ]);
        (4, map Char.chr (int_range 0 0x1F));
        (2, return '\x7f');
      ]
    |> map (String.make 1)
  in
  let special =
    oneof_list
      [
        0x80;
        0x85;
        0x9B;
        0x9F;
        0xA0;
        0xAD;
        0x61C;
        0x1680;
        0x200B;
        0x200D;
        0x200E;
        0x2028;
        0x2029;
        0x202A;
        0x202E;
        0x202F;
        0x2060;
        0x2065;
        0x2066;
        0x2069;
        0x3000;
        0xFEFF;
        0xFE0F;
        0xFFF0;
        0xE0001;
        0xE0041;
        0xE007F;
        0xE0100;
        0xE0FFF;
      ]
    |> map utf8
  in
  let plain = oneof_list [ 0xE9; 0x4E2D; 0x1F389; 0x10FFFF ] |> map utf8 in
  oneof_weighted [ (6, ascii); (6, special); (3, plain) ]

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
    [
      0x00;
      0x09;
      0x0A;
      0x1B;
      0x7F;
      0x85;
      0x9B;
      0xAD;
      0x61C;
      0x200B;
      0x200D;
      0x200E;
      0x2028;
      0x2029;
      0x202E;
      0x2060;
      0x2065;
      0x2066;
      0x2069;
      0xFEFF;
      0xFFF0;
      0xFE0F;
      0xE0041;
      0xE0100;
      0x17B4;
      0x3164;
      0xFDD0;
      0xFFFE;
      0x10FFFF;
    ]
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
       (fun cp -> (not (F.mem cp && Uchar.is_valid cp)) || E.is_dangerous cp)
       (List.init 0x110 (fun i -> i * 0x1000))

let read path = In_channel.with_open_bin path In_channel.input_all

let contains s sub =
  try
    ignore (Str.search_forward (Str.regexp_string sub) s 0);
    true
  with Not_found -> false

(* T-1039 Log (F3): there is no flag to flip. From phase 1, or once T-1033 is done, the generated
   table of T-1033 must exist in the neutral package compiler/lib/source/ (the syntax library depends
   on egide.diagnostics, so the table cannot live in syntax) and Forbidden_set must use it. *)
let%test "forbidden set is backed by the generated table from phase 1" =
  let phase = int_of_string (String.trim (read "../../../tasks/PHASE")) in
  let done_ =
    Array.exists
      (fun f -> String.starts_with ~prefix:"T-1033" f)
      (Sys.readdir "../../../tasks/done")
  in
  let table = Sys.file_exists "../../lib/source/forbidden_table.ml" in
  let wired = contains (read "../../lib/diagnostics/forbidden_set.ml") "Forbidden_table" in
  let ok = (phase < 1 && not done_) || (table && wired) in
  if not ok then
    print_endline
      "Forbidden_set is still the hand-written set: wire compiler/lib/source/forbidden_table.ml \
       (T-1033)";
  ok

(* ---- the stdout/stderr guard ---- *)

(* spec: LEX-006 — defence in depth: a string that reaches the output layer unescaped is neutralised
   (dangerous code points and invalid bytes escaped, LF kept as structure, backslash not doubled). *)
let%test "guard neutralises without double escaping" =
  E.neutralize "a\x1b[1Ab\n\\u{1B} \xE2\x80\xAE \xFF" = "a\\u{1B}[1Ab\n\\u{1B} \\u{202E} \\xFF"

(* ---- attack cases through every diagnostic renderer ---- *)

let hostile =
  "\x1b[1A\x1b[2K\xC2\x9B2J \xE2\x80\xAE(RLO) a\xE2\x80\x8Bb \xF3\xA0\x81\x81 \xC2\xA0 \xC2\x85 \
   \xE2\x80\xA8 \xFF"

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
      |      ^^^^^^
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

(* ---- full sweep over every Unicode scalar value (security review of T-1039, candidate 1) ---- *)

(* Independent, hand-written oracle (not Forbidden_set): Cc, C1, Zs, bidi, the Cf and DICP groups of
   LEX-003 and the noncharacters. *)
let oracle_wide cp =
  oracle_dangerous cp || cp = 0x034F
  || (cp >= 0x0600 && cp <= 0x0605)
  || cp = 0x06DD || cp = 0x070F
  || (cp >= 0x115F && cp <= 0x1160)
  || (cp >= 0x17B4 && cp <= 0x17B5)
  || (cp >= 0x180B && cp <= 0x180F)
  || cp = 0x3164
  || (cp >= 0xFDD0 && cp <= 0xFDEF)
  || (cp >= 0xFE00 && cp <= 0xFE0F)
  || cp = 0xFFA0
  || (cp >= 0xFFF0 && cp <= 0xFFFB)
  || cp land 0xFFFE = 0xFFFE

let%test "sweep: every scalar value is escaped when the oracle says so, and never leaks" =
  let bad = ref [] in
  for cp = 0 to 0x10FFFF do
    if not (cp >= 0xD800 && cp <= 0xDFFF) then begin
      let s = utf8 cp in
      if oracle_wide cp && not (E.is_dangerous cp) then
        bad := Printf.sprintf "U+%04X missed" cp :: !bad;
      let outs = [ E.display s; E.neutralize s; E.neutralize_line s; E.json_safe s ] in
      if List.exists leaks outs then bad := Printf.sprintf "U+%04X leaks" cp :: !bad;
      (* display and neutralize_line never emit a raw LF *)
      if String.contains (E.display s) '\n' || String.contains (E.neutralize_line s) '\n' then
        bad := Printf.sprintf "U+%04X LF" cp :: !bad
    end
  done;
  if !bad <> [] then List.iter print_endline (List.filteri (fun i _ -> i < 10) !bad);
  !bad = []

(* ---- log-injection matrix (candidate 2): a separator in any field never forges an output line ---- *)

let separators =
  [
    "\n";
    "\r\n";
    "\r";
    "\xC2\x85";
    "\xE2\x80\xA8";
    "\xE2\x80\xA9";
    "\x0B";
    "\x0C";
    "\\n";
    "\\\n";
    "\x00";
    "\xE2\x80";
    "\xC0\x8A";
    "\xED\xA0\x80";
  ]

let lines s = List.length (String.split_on_char '\n' s)

let starts_fake s =
  List.exists
    (fun l -> String.starts_with ~prefix:"FAKE" (String.trim l))
    (String.split_on_char '\n' s)

let injection_diag sep =
  let p = "x" ^ sep ^ "FAKE: error[E9999]: pwned" in
  ( p,
    D.error ~rule:"LEX-003" ~code:"E0004"
      ~labels:[ D.label (sp ~file:p 1 1 1 2) p ]
      ~notes:[ p ]
      ~fixes:[ D.fix p [ D.edit (sp ~file:p 1 1 1 1) p ] ]
      (sp ~file:p 1 1 1 2) p )

let%test "injection matrix: no forged line, same line count as a benign payload" =
  let _, benign = injection_diag " " in
  let render d src = [ D.to_human d; D.render_human ~sources:(fun _ -> Some src) d; D.to_json d ] in
  let base = List.map lines (render benign "x FAKE: error[E9999]: pwned\n") in
  List.for_all
    (fun sep ->
      let p, d = injection_diag sep in
      let outs = render d (p ^ "\n") in
      let ok = List.map lines outs = base && not (List.exists starts_fake outs) in
      if not ok then Printf.printf "injection via %S\n" sep;
      ok)
    separators

let%test "neutralize_line escapes LF and keeps backslash" =
  E.neutralize_line "a\nb\\c\x1b" = "a\\nb\\c\\u{1B}"

(* ---- lint: nothing prints a source string without the escaping function ----

   A small OCaml tokenizer (comments, strings, quoted strings and char literals handled) feeds a
   check on identifier paths, so that a string such as "(*" cannot hide a call, and aliases and
   opens of the I/O modules are rejected. It is a defence in depth, not the guarantee: structural
   enforcement is T-1111. *)

let tokens src =
  let n = String.length src in
  let toks = ref [] in
  let is_id c =
    (c >= 'a' && c <= 'z')
    || (c >= 'A' && c <= 'Z')
    || (c >= '0' && c <= '9')
    || c = '_' || c = '\''
  in
  let rec skip_string i =
    if i >= n then i
    else match src.[i] with '"' -> i + 1 | '\\' -> skip_string (i + 2) | _ -> skip_string (i + 1)
  in
  (* a quoted string opens with an open brace, lowercase letters or underscores, then a bar *)
  let quoted_end i =
    let j = ref (i + 1) in
    while !j < n && ((src.[!j] >= 'a' && src.[!j] <= 'z') || src.[!j] = '_') do
      incr j
    done;
    if !j < n && src.[!j] = '|' then begin
      let close = "|" ^ String.sub src (i + 1) (!j - i - 1) ^ "}" in
      match Str.search_forward (Str.regexp_string close) src (!j + 1) with
      | k -> Some (k + String.length close)
      | exception Not_found -> Some n
    end
    else None
  in
  (* End of the char literal starting at [i] ('x', '"', '\n', '\"', '\''), if any; a type variable
     such as 'a is not one. *)
  let char_end i =
    if i + 2 < n && src.[i] = '\'' && src.[i + 1] <> '\\' && src.[i + 2] = '\'' then Some (i + 3)
    else if i + 3 < n && src.[i] = '\'' && src.[i + 1] = '\\' then
      Option.map (fun k -> k + 1) (String.index_from_opt src (i + 3) '\'')
    else None
  in
  let rec comment i depth =
    if i >= n then i
    else if src.[i] = '(' && i + 1 < n && src.[i + 1] = '*' then comment (i + 2) (depth + 1)
    else if src.[i] = '*' && i + 1 < n && src.[i + 1] = ')' then
      if depth = 1 then i + 2 else comment (i + 2) (depth - 1)
    else if src.[i] = '"' then comment (skip_string (i + 1)) depth
    else if src.[i] = '{' && quoted_end i <> None then comment (Option.get (quoted_end i)) depth
    else if src.[i] = '\'' && char_end i <> None then comment (Option.get (char_end i)) depth
    else comment (i + 1) depth
  in
  let rec go i =
    if i < n then
      let c = src.[i] in
      if c = '(' && i + 1 < n && src.[i + 1] = '*' then go (comment (i + 2) 1)
      else if c = '"' then (
        toks := "\"" :: !toks;
        go (skip_string (i + 1)))
      else if c = '{' && quoted_end i <> None then (
        toks := "\"" :: !toks;
        go (Option.get (quoted_end i)))
      else if c = '\'' && char_end i <> None then (
        toks := "'" :: !toks;
        go (Option.get (char_end i)))
      else if is_id c && not (c = '\'') then begin
        (* identifier path: A.B.c, dots included *)
        let j = ref i in
        let continue = ref true in
        while !continue do
          while !j < n && is_id src.[!j] do
            incr j
          done;
          if !j + 1 < n && src.[!j] = '.' && is_id src.[!j + 1] && src.[!j + 1] <> '\'' then incr j
          else continue := false
        done;
        toks := String.sub src i (!j - i) :: !toks;
        go !j
      end
      else (
        if c <> ' ' && c <> '\n' && c <> '\t' && c <> '\r' then toks := String.make 1 c :: !toks;
        go (i + 1))
  in
  go 0;
  List.rev !toks

let restricted_modules =
  [ "Format"; "Fmt"; "Unix"; "Out_channel"; "Stdlib"; "Printf"; "Logs"; "Eio" ]

let safe_printf = [ "sprintf"; "ksprintf"; "bprintf"; "asprintf" ]

let banned_values =
  [
    "print_string";
    "print_bytes";
    "print_char";
    "print_int";
    "print_float";
    "print_endline";
    "print_newline";
    "prerr_string";
    "prerr_bytes";
    "prerr_char";
    "prerr_int";
    "prerr_float";
    "prerr_endline";
    "prerr_newline";
    "stdout";
    "stderr";
    "output";
    "output_string";
    "output_bytes";
    "output_char";
    "output_substring";
    "output_byte";
    "flush";
    "flush_all";
    "printf";
    "eprintf";
    "fprintf";
    "ifprintf";
    "kfprintf";
    "pr";
    "epr";
    "std_formatter";
    "err_formatter";
  ]

(* Violations in [src]; [Printf.sprintf] and friends are the only allowed use of restricted modules. *)
let lint_violations src =
  let toks = tokens src in
  let viol = ref [] in
  let add m = viol := m :: !viol in
  let check_path p =
    match String.split_on_char '.' p with
    | [ "Printf"; f ] when List.mem f safe_printf -> ()
    | [ m ] when List.mem m restricted_modules -> add ("module " ^ m)
    | m :: _ when List.mem m restricted_modules -> add ("path " ^ p)
    | [ v ] when List.mem v banned_values -> add ("value " ^ v)
    | _ -> ()
  in
  let rec walk = function
    | ("open" | "include") :: p :: rest ->
        (* any open of a restricted module hides later unqualified uses *)
        (match String.split_on_char '.' p with
        | m :: _ when List.mem m restricted_modules -> add ("open " ^ p)
        | _ -> ());
        walk rest
    | "module" :: _ :: "=" :: p :: rest ->
        (match String.split_on_char '.' p with
        | m :: _ when List.mem m restricted_modules -> add ("alias " ^ p)
        | _ -> ());
        walk rest
    | t :: rest ->
        if
          t <> "\"" && t <> "'"
          && String.length t > 0
          && ((t.[0] >= 'A' && t.[0] <= 'z') || t.[0] = '_')
        then check_path t;
        walk rest
    | [] -> ()
  in
  walk toks;
  List.rev !viol

(* The twelve bypass snippets of the security review of T-1039 (F1): each must now be rejected. *)
let bypass_snippets =
  [
    "let _ = \"(*\"\nlet () = print_endline s\nlet _ = 1 (* x *)";
    "let () = Format.eprintf \"%s\" s";
    "let () = Format.fprintf Format.err_formatter \"%s\" s";
    "let () = prerr_char 'x'";
    "let () = prerr_bytes b";
    "let () = print_bytes b";
    "let () = print_newline ()";
    "module P = Printf\nlet () = P.eprintf \"%s\" s";
    "open Printf\nlet () = eprintf \"%s\" s";
    "let () = Fmt.pr \"%s\" s";
    "let () = Fmt.epr \"%s\" s";
    "let () = Unix.write_substring Unix.stderr s 0 1";
    "let () = Stdlib.print_endline s";
    "let () = {x|(*|x}; print_endline s";
    "let () = Out_channel.output_string stdout s";
    (* R1: a char literal holding a double quote inside a comment must not open a string *)
    "(* '\"' *) let () = print_endline s";
    "(* '\\\"' *) let () = print_endline s";
    "(* (* '\"' *) '\"' *) let () = print_endline s";
    "(* {|\"|} *) let () = print_endline s";
    "let c = '\\'' let () = print_endline s";
  ]

let%test "lint rejects every bypass snippet" =
  List.for_all
    (fun sn ->
      let v = lint_violations sn in
      if v = [] then Printf.printf "lint missed: %S\n" sn;
      v <> [])
    bypass_snippets

let%test "lint accepts comments, strings and Printf.sprintf" =
  List.for_all
    (fun sn -> lint_violations sn = [])
    [
      "(* print_endline \"(*\" *) let s = Printf.sprintf \"%d\" 1";
      "let s = \"print_endline stdout Format.eprintf\" ^ {|stderr|}";
      "let c = '\"' and d = 'a' let x : 'a list = []";
      "let () = Output.line (Escape.display m)";
    ]

let ml_files dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun f -> Filename.check_suffix f ".ml")
  |> List.sort compare
  |> List.map (fun f -> (Filename.concat dir f, f))

(* spec: LEX-006 — every module of the CLI and of the diagnostics library (output.ml, which owns the
   channels, excepted) writes nothing except through Output, and uses no escaper but Escape. *)
let%test "lint: bin and diagnostics sources are clean" =
  let files = ml_files "../../bin" @ ml_files "../../lib/diagnostics" in
  let files = List.filter (fun (_, f) -> f <> "output.ml") files in
  let ok = ref (List.length files >= 5) in
  List.iter
    (fun (path, _) ->
      let src = read path in
      let v = lint_violations src in
      if v <> [] then (
        ok := false;
        Printf.printf "%s: %s\n" path (String.concat ", " v)))
    files;
  let main = read "../../bin/main.ml" in
  let calls = List.filter (fun t -> String.starts_with ~prefix:"Output." t) (tokens main) in
  (* the CLI must have no output path other than Output, and use it at least for diagnostics *)
  !ok && List.length calls >= 5

let%test "lint: Text no longer exports an escaper, diagnostic.ml uses Escape" =
  let mli = read "../../lib/diagnostics/text.mli" in
  let d = read "../../lib/diagnostics/diagnostic.ml" in
  (not (contains mli "sanitize" || contains mli "json_string"))
  && (not (contains d "<U+"))
  && List.exists (fun t -> String.starts_with ~prefix:"Escape." t) (tokens d)
