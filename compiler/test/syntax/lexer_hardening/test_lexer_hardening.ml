(* T-0006 — lexer hardening: source-text checks (LEX-001..004), non-ASCII identifiers (LEX-020) and the
   "never raises" property. Every test cites the rules it covers. The tests call [Lexer.tokenize] directly (raw
   tokens, no layout) so that they depend only on the lexer and [Source_check]. *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let lex src = Lexer.tokenize ~file:"t.egd" src

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

let show_diag (d : D.t) =
  Printf.sprintf "%s %d:%d-%d:%d %s" d.code d.span.start.line d.span.start.col d.span.stop.line
    d.span.stop.col d.message

let show_tokens toks =
  String.concat " "
    (List.map
       (fun (t : Lexer.located) ->
         Printf.sprintf "%d:%d:%s" t.startp.pos_lnum
           (t.startp.pos_cnum - t.startp.pos_bol + 1)
           (Parse.token_to_string t.tok))
       toks)

let show src =
  let toks, diags = lex src in
  print_endline (show_tokens toks);
  List.iter (fun d -> print_endline (show_diag d)) diags

let hex s =
  String.concat " "
    (List.map (fun c -> Printf.sprintf "%02X" (Char.code c)) (List.of_seq (String.to_seq s)))

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-001: invalid UTF-8 (E0001). One diagnostic per run of ill-formed bytes; each maximal subpart of an
   ill-formed subsequence (Unicode §3.9, Table 3-7) counts as one column. Lexing stops: no tokens. *)

let invalid_utf8_cases =
  [
    "\x80" (* lone continuation byte *);
    "\xBF";
    "\xC0\xAF" (* overlong '/' : C0 is never a lead byte *);
    "\xC1\xBF";
    "\xE0\x80\xAF" (* overlong 3-byte *);
    "\xF0\x80\x80\xAF" (* overlong 4-byte *);
    "\xED\xA0\x80" (* UTF-16 surrogate U+D800 *);
    "\xED\xBF\xBF" (* surrogate U+DFFF *);
    "\xF4\x90\x80\x80" (* U+110000, above the Unicode range *);
    "\xF5\x80\x80\x80";
    "\xF8\x88\x80\x80\x80" (* obsolete 5-byte form *);
    "\xFE";
    "\xFF";
    "\xE2\x82" (* truncated 3-byte sequence, followed by a space *);
    "\xF0\x9F\x98" (* truncated 4-byte sequence *);
    "\xFF\xFE\xFD" (* a run of three ill-formed bytes: one diagnostic *);
  ]

(* spec: LEX-001 *)
let%expect_test "invalid UTF-8 sequences report one E0001 per ill-formed run and stop lexing" =
  List.iter
    (fun bytes ->
      let toks, diags = lex ("module m\n# " ^ bytes ^ " z\n") in
      Printf.printf "%-15s tokens=%d %s\n" (hex bytes) (List.length toks)
        (String.concat "; " (List.map show_diag diags)))
    invalid_utf8_cases;
  [%expect
    {|
    80              tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    BF              tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    C0 AF           tokens=0 E0001 2:3-2:5 invalid UTF-8 sequence
    C1 BF           tokens=0 E0001 2:3-2:5 invalid UTF-8 sequence
    E0 80 AF        tokens=0 E0001 2:3-2:6 invalid UTF-8 sequence
    F0 80 80 AF     tokens=0 E0001 2:3-2:7 invalid UTF-8 sequence
    ED A0 80        tokens=0 E0001 2:3-2:6 invalid UTF-8 sequence
    ED BF BF        tokens=0 E0001 2:3-2:6 invalid UTF-8 sequence
    F4 90 80 80     tokens=0 E0001 2:3-2:7 invalid UTF-8 sequence
    F5 80 80 80     tokens=0 E0001 2:3-2:7 invalid UTF-8 sequence
    F8 88 80 80 80  tokens=0 E0001 2:3-2:8 invalid UTF-8 sequence
    FE              tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    FF              tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    E2 82           tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    F0 9F 98        tokens=0 E0001 2:3-2:4 invalid UTF-8 sequence
    FF FE FD        tokens=0 E0001 2:3-2:6 invalid UTF-8 sequence
    |}]

(* spec: LEX-001 *)
let%expect_test "separate ill-formed runs are reported separately, with correct positions" =
  show "module m\n# \xFF a \xFE\nlet s = \"\xC3\"\n";
  show "module m\n# truncated at end of file \xE2\x82";
  [%expect
    {|

    E0001 2:3-2:4 invalid UTF-8 sequence
    E0001 2:7-2:8 invalid UTF-8 sequence
    E0001 3:10-3:11 invalid UTF-8 sequence

    E0001 2:28-2:29 invalid UTF-8 sequence
    |}]

(* spec: LEX-001 — boundary values of every well-formed byte pattern are accepted. U+FFFF and U+10FFFF are
   well-formed UTF-8 (no E0001) but noncharacters, so each is one E0004 per occurrence (LEX-003, ADR-0017):
   diags=2 is the comment and the string. *)
let%expect_test "well-formed UTF-8 boundary values are accepted" =
  List.iter
    (fun bytes ->
      let toks, diags = lex ("# " ^ bytes ^ "\nlet s = \"" ^ bytes ^ "\"\n") in
      Printf.printf "%-12s tokens=%d diags=%d\n" (hex bytes) (List.length toks) (List.length diags))
    [
      "\xC2\xA0";
      "\xDF\xBF";
      "\xE0\xA0\x80";
      "\xED\x9F\xBF";
      "\xEE\x80\x80";
      "\xEF\xBF\xBF";
      "\xF0\x90\x80\x80";
      "\xF4\x8F\xBF\xBF";
    ];
  [%expect
    {|
    C2 A0        tokens=4 diags=0
    DF BF        tokens=4 diags=0
    E0 A0 80     tokens=4 diags=0
    ED 9F BF     tokens=4 diags=0
    EE 80 80     tokens=4 diags=0
    EF BF BF     tokens=4 diags=2
    F0 90 80 80  tokens=4 diags=0
    F4 8F BF BF  tokens=4 diags=2
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-001: byte-order mark (E0002). *)

(* spec: LEX-001 *)
let%expect_test "a byte-order mark is reported once as E0002 and lexing continues" =
  show "\xEF\xBB\xBFmodule m\n";
  [%expect {|
    1:2:module 1:9:IDENT("m")
    E0002 1:1-1:2 byte-order mark is not allowed
    |}]

(* spec: LEX-001, LEX-003 — only a leading U+FEFF is a byte-order mark; any other is a forbidden character. *)
let%expect_test "a second U+FEFF after the byte-order mark is E0004" =
  show "\xEF\xBB\xBF\xEF\xBB\xBFmodule m\n";
  [%expect
    {|
    1:3:module 1:10:IDENT("m")
    E0002 1:1-1:2 byte-order mark is not allowed
    E0004 1:2-1:3 forbidden character U+FEFF (ZERO WIDTH NO-BREAK SPACE) — risk: hidden or reordered source text (Trojan Source)
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-002: line terminators (E0003). *)

(* spec: LEX-002 *)
let%expect_test "CR LF is accepted and normalised to LF" =
  show "module m\r\nlet x = 1\r\n# c\r\nlet s = \"a\"\r\n";
  [%expect
    {| 1:1:module 1:8:IDENT("m") 2:1:let 2:5:IDENT("x") 2:7:= 2:9:INT("1") 4:1:let 4:5:IDENT("s") 4:7:= 4:9:STRING("a") |}]

(* spec: LEX-002 *)
let%expect_test "a lone CR is E0003 in code, comments, strings and at end of file" =
  show "module m\rlet x = 1\n";
  show "# a\rb\n";
  show "let s = \"a\rb\"\n";
  show "module m\r";
  show "x\r\r\n";
  [%expect
    {|
    1:1:module 1:8:IDENT("m") 1:10:let 1:14:IDENT("x") 1:16:= 1:18:INT("1")
    E0003 1:9-1:10 lone carriage return

    E0003 1:4-1:5 lone carriage return
    1:1:let 1:5:IDENT("s") 1:7:= 1:9:STRING("a\rb")
    E0003 1:11-1:12 lone carriage return
    1:1:module 1:8:IDENT("m")
    E0003 1:9-1:10 lone carriage return
    1:1:IDENT("x")
    E0003 1:2-1:3 lone carriage return
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-003: forbidden code points (E0004), anywhere: in code, in comments and in string literals. The list below
   is transcribed from the spec, independently of [Source_check.is_forbidden]. CR is governed by LEX-002 (E0003)
   and HT by LEX-004 (E0005); both are tested separately. *)

let forbidden_ranges =
  [
    (* bidirectional controls *)
    (0x061C, 0x061C);
    (0x200E, 0x200F);
    (0x202A, 0x202E);
    (0x2066, 0x2069);
    (* zero-width and invisible characters *)
    (0x200B, 0x200D);
    (0x2060, 0x2060);
    (0xFEFF, 0xFEFF);
    (* line and paragraph separators *)
    (0x2028, 0x2029);
    (* general category Cc, except LF, HT (LEX-004) and CR (LEX-002) *)
    (0x00, 0x08);
    (0x0B, 0x0C);
    (0x0E, 0x1F);
    (0x7F, 0x9F);
  ]

let forbidden_cps =
  List.concat_map (fun (lo, hi) -> List.init (hi - lo + 1) (fun k -> lo + k)) forbidden_ranges

(* (name, source with the character inserted, line, column of the character) *)
let contexts c =
  [
    ("code", "module m\nlet x = " ^ c ^ "1\n", 2, 9);
    ("comment", "module m\n# a" ^ c ^ "b\n", 2, 4);
    ("string", "module m\nlet s = \"a" ^ c ^ "b\"\n", 2, 11);
  ]

let toks_only src = List.map (fun (t : Lexer.located) -> t.tok) (fst (lex src))

(* spec: LEX-003 *)
let%expect_test "every forbidden code point is E0004 in code, comments and strings" =
  let ok = Hashtbl.create 3 in
  List.iter
    (fun cp ->
      List.iter
        (fun (ctx, src, line, col) ->
          let toks, diags = lex src in
          let expected_prefix = Printf.sprintf "forbidden character U+%04X (" cp in
          let good =
            match diags with
            | [ d ] ->
                d.code = "E0004" && d.rule = Some "LEX-003"
                && (d.span.start = Egide_source.Span.{ line; col })
                && (d.span.stop = Egide_source.Span.{ line; col = col + 1 })
                && String.starts_with ~prefix:expected_prefix d.message
            | _ -> false
          in
          (* Outside strings the forbidden character must not disturb the token stream (no extra E0051). *)
          let _, clean, _, _ = List.find (fun (c, _, _, _) -> c = ctx) (contexts "") in
          let good =
            good
            && (ctx = "string" || List.map (fun (t : Lexer.located) -> t.tok) toks = toks_only clean)
          in
          if good then Hashtbl.replace ok ctx (1 + Option.value ~default:0 (Hashtbl.find_opt ok ctx))
          else
            Printf.printf "FAIL U+%04X in %s: %s\n" cp ctx
              (String.concat "; " (List.map show_diag diags)))
        (contexts (utf8 cp)))
    forbidden_cps;
  Printf.printf "forbidden code points: %d\n" (List.length forbidden_cps);
  List.iter
    (fun ctx -> Printf.printf "%s: %d ok\n" ctx (Option.value ~default:0 (Hashtbl.find_opt ok ctx)))
    [ "code"; "comment"; "string" ];
  [%expect
    {|
    forbidden code points: 81
    code: 81 ok
    comment: 81 ok
    string: 81 ok
    |}]

(* spec: LEX-003 — the message names the character (docs/diagnostics.md, E0004). *)
let%expect_test "E0004 messages name the forbidden character" =
  List.iter
    (fun cp ->
      match snd (lex ("# " ^ utf8 cp ^ "\n")) with
      | [ d ] -> print_endline d.message
      | ds -> Printf.printf "U+%04X: %d diagnostics\n" cp (List.length ds))
    [
      0x061C;
      0x200B;
      0x200C;
      0x200D;
      0x200E;
      0x200F;
      0x202A;
      0x202B;
      0x202C;
      0x202D;
      0x202E;
      0x2028;
      0x2029;
      0x2060;
      0x2066;
      0x2067;
      0x2068;
      0x2069;
      0x00;
      0x1B;
      0x7F;
      0x85;
    ];
  [%expect
    {|
    forbidden character U+061C (ARABIC LETTER MARK) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+200B (ZERO WIDTH SPACE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+200C (ZERO WIDTH NON-JOINER) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+200D (ZERO WIDTH JOINER) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+200E (LEFT-TO-RIGHT MARK) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+200F (RIGHT-TO-LEFT MARK) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+202A (LEFT-TO-RIGHT EMBEDDING) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+202B (RIGHT-TO-LEFT EMBEDDING) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+202C (POP DIRECTIONAL FORMATTING) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+202D (LEFT-TO-RIGHT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2028 (LINE SEPARATOR) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2029 (PARAGRAPH SEPARATOR) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2060 (WORD JOINER) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2066 (LEFT-TO-RIGHT ISOLATE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2067 (RIGHT-TO-LEFT ISOLATE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2068 (FIRST STRONG ISOLATE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+2069 (POP DIRECTIONAL ISOLATE) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+0000 (control character) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+001B (control character) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+007F (control character) — risk: hidden or reordered source text (Trojan Source)
    forbidden character U+0085 (control character) — risk: hidden or reordered source text (Trojan Source)
    |}]

(* spec: LEX-003 — neighbours of the forbidden ranges, and ordinary non-ASCII text, are allowed in comments and
   strings. (Whether further invisible characters should be forbidden is spec-question Q-0001.) *)
let%expect_test "code points next to the forbidden ranges are accepted in comments and strings" =
  let allowed =
    [
      0x20;
      0x7E;
      0xA0;
      0xE9;
      0x061B;
      0x061D;
      0x200A;
      0x2010;
      0x2027;
      0x202F;
      0x2030;
      0x2054;
      0xFEFE;
      0xFF01;
      0x1F600;
      0x10FFFD;
    ]
  in
  let bad =
    List.filter
      (fun cp ->
        List.exists
          (fun (ctx, src, _, _) -> ctx <> "code" && snd (lex src) <> [])
          (contexts (utf8 cp)))
      allowed
  in
  Printf.printf "allowed: %d, rejected: [%s]\n" (List.length allowed)
    (String.concat " " (List.map (Printf.sprintf "U+%04X") bad));
  [%expect {| allowed: 16, rejected: [] |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-004: horizontal tab (E0005). HT is allowed inside string literals only (LEX-003, LEX-004). *)

(* spec: LEX-004, LEX-003 *)
let%expect_test "a tab inside a string literal is accepted" =
  show "let s = \"a\tb\"\n";
  [%expect {| 1:1:let 1:5:IDENT("s") 1:7:= 1:9:STRING("a\tb") |}]

(* spec: LEX-004 *)
let%expect_test "a tab used as indentation is E0005" =
  show "fn f():\n\tx\n";
  [%expect
    {|
    1:1:fn 1:4:IDENT("f") 1:5:( 1:6:) 1:7:: 2:2:IDENT("x")
    E0005 2:1-2:2 tab character outside a string literal; indent with 4 spaces
    |}]

(* spec: LEX-004 — a run of tabs is one diagnostic covering the run. *)
let%expect_test "a run of tabs is one E0005" =
  show "let x =\t\t1\n";
  [%expect
    {|
    1:1:let 1:5:IDENT("x") 1:7:= 1:10:INT("1")
    E0005 1:8-1:10 tab character outside a string literal; indent with 4 spaces
    |}]

(* spec: LEX-004, LEX-010, LEX-011, LEX-012 — comments are not string literals. *)
let%expect_test
    "a tab inside a comment, doc comment or shebang is E0005 and the comment still ends at the \
     line end" =
  show "#!/bin/egide\trun\nx # a\tb c\n## doc\tcomment\ny\n";
  [%expect
    {|
    2:1:IDENT("x") 4:1:IDENT("y")
    E0005 1:13-1:14 tab character outside a string literal; indent with 4 spaces
    E0005 2:6-2:7 tab character outside a string literal; indent with 4 spaces
    E0005 3:7-3:8 tab character outside a string literal; indent with 4 spaces
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* LEX-020: identifiers are ASCII only. The seed reports the first non-ASCII character as an unexpected
   character (E0051), which tests/security/lexical/homoglyph_identifier.egd pins; switching to the catalogue's
   E0010 is follow-up T-0025. Either way the identifier is rejected. *)

(* spec: LEX-020 *)
let%expect_test "non-ASCII letters are not part of identifiers" =
  show "let café = 1\n";
  show "let \xD0\xB0dmin = 1\n" (* Cyrillic a, U+0430 *);
  [%expect
    {|
    1:1:let 1:5:IDENT("caf") 1:10:= 1:12:INT("1")
    E0051 1:8-1:9 unexpected character `é`
    1:1:let 1:6:IDENT("dmin") 1:11:= 1:13:INT("1")
    E0051 1:5-1:6 unexpected character `а`
    |}]

(* ---------------------------------------------------------------------------------------------------------- *)
(* Robustness: large inputs do not overflow the stack, and the lexer never raises (property tests). *)

let%expect_test "very long runs of spaces, comments, strings and tabs do not raise" =
  let n = 1_000_000 in
  List.iter
    (fun (name, src) ->
      let toks, diags = lex src in
      Printf.printf "%s: tokens=%d diags=%d\n" name (List.length toks) (List.length diags))
    [
      ("spaces", String.make n ' ' ^ "x");
      ("comment", "#" ^ String.make n 'a');
      ("string", "\"" ^ String.make n 'a' ^ "\"");
      ("tabs", String.make n '\t');
      ("newlines", String.make n '\n');
      ("invalid", String.make n '\xFF');
    ];
  [%expect
    {|
    spaces: tokens=1 diags=0
    comment: tokens=0 diags=0
    string: tokens=1 diags=0
    tabs: tokens=0 diags=1
    newlines: tokens=0 diags=0
    invalid: tokens=0 diags=1
    |}]

(* Oracles written from the spec, independent of the implementation. *)

(* ADR-0017: the set is property-defined; the oracle (compiler/test/diagnostics/oracle) lists the properties. LF, HT
   and CR have their own rules. *)
let is_forbidden_spec cp = Forbidden_oracle.forbidden cp && cp <> 0x0A && cp <> 0x09 && cp <> 0x0D

(* Number of forbidden code points (LEX-003) in a well-formed UTF-8 string, excluding a leading BOM (LEX-001). *)
let count_forbidden src =
  let n = ref 0 and i = ref 0 in
  while !i < String.length src do
    let d = String.get_utf_8_uchar src !i in
    let cp = Uchar.to_int (Uchar.utf_decode_uchar d) in
    if is_forbidden_spec cp && not (cp = 0xFEFF && !i = 0) then incr n;
    i := !i + Uchar.utf_decode_length d
  done;
  !n

(* Number of CRs not followed by LF (LEX-002). *)
let count_lone_cr src =
  let n = ref 0 in
  String.iteri
    (fun i c -> if c = '\r' && not (i + 1 < String.length src && src.[i + 1] = '\n') then incr n)
    src;
  !n

let count code diags = List.length (List.filter (fun (d : D.t) -> d.code = code) diags)

(* T-1080: a run of identical characters is one diagnostic spanning the run, so the number of characters reported
   under [code] is the sum of the span widths (single-line spans). *)
let count_chars code diags =
  List.fold_left
    (fun acc (d : D.t) -> if d.code = code then acc + (d.span.stop.col - d.span.start.col) else acc)
    0 diags

(* Zero-width spans are legitimate (e.g. "unterminated string literal" at end of file). *)
let well_formed_span (d : D.t) =
  let s = d.span.start and e = d.span.stop in
  s.line >= 1 && s.col >= 1 && (e.line > s.line || (e.line = s.line && e.col >= s.col))

(* The property checked on every input: no exception; E0001 exactly when the input is not UTF-8; on UTF-8
   input, every forbidden code point is in an E0004 and every lone CR in an E0003 (runs collapse, T-1080); every span is well formed. *)
let property src =
  let toks, diags = lex src in
  let valid = String.is_valid_utf_8 src in
  List.for_all well_formed_span diags
  && count "E0001" diags > 0 = not valid
  && ((not valid)
     ||
     (* below the per-file cap (E0006 absent) every character is accounted for; above it, never more than exist *)
     if count "E0006" diags = 0 then
       count_chars "E0004" diags = count_forbidden src && count_chars "E0003" diags = count_lone_cr src
     else
       count_chars "E0004" diags <= count_forbidden src
       && count_chars "E0003" diags <= count_lone_cr src
       && List.length diags = 101)
  && (valid || toks = [])

let seed = 0x0E61DE

let run test =
  QCheck.Test.check_exn ~rand:(Random.State.make [| seed |]) test;
  print_endline "ok"

let byte_gen = QCheck.Gen.(map Char.chr (int_range 0 255))

(* spec: LEX-001 *)
let%expect_test "property: the lexer never raises on 10 000 arbitrary byte strings" =
  run
    (QCheck.Test.make ~count:10_000 ~name:"arbitrary bytes"
       (QCheck.make ~print:String.escaped QCheck.Gen.(string_size ~gen:byte_gen (int_range 0 256)))
       property);
  [%expect {| ok |}]

(* Fragments chosen to reach every lexer state: keywords, layout-relevant whitespace, comments, strings and their
   escapes, numbers, operators, forbidden and ill-formed sequences. *)
let fragments =
  [|
    "module";
    "fn";
    "let";
    "x";
    "_";
    " ";
    "    ";
    "\n";
    "\r\n";
    "\r";
    "\t";
    "#";
    "##";
    "#!";
    "\"";
    "\\";
    "\\n";
    "\\u{";
    "1";
    "0x";
    "1.5";
    "e9";
    "_1";
    ":";
    "(";
    ")";
    "[";
    "]";
    "{";
    "}";
    ";";
    "..";
    "..=";
    "**";
    "|>";
    "->";
    "==";
    "<<=";
    "é";
    "日本";
    "\xF0\x9F\x98\x80";
    "\xE2\x80\xAE";
    "\xEF\xBB\xBF";
    "\xE2\x80\xA8";
    "\x00";
    "\x1B";
    "\x7F";
    "\xC2\x85";
    "\xFF";
    "\xE2\x82";
    "\xED\xA0\x80";
    "\xF4\x90\x80\x80";
    "\xC0\xAF";
    "\xD0\xB0";
  |]

(* spec: LEX-001, LEX-002, LEX-003, LEX-004 *)
let%expect_test "property: the lexer never raises on 10 000 strings of lexer fragments" =
  let gen =
    QCheck.Gen.(map (String.concat "") (list_size (int_range 0 64) (oneof_array fragments)))
  in
  run
    (QCheck.Test.make ~count:10_000 ~name:"fragments"
       (QCheck.make ~print:String.escaped gen)
       property);
  [%expect {| ok |}]

(* spec: LEX-001, LEX-003 — every Unicode scalar value, so that the sedlex decoder sees the whole range. *)
let%expect_test "property: the lexer never raises on 10 000 strings of arbitrary scalar values" =
  let scalar =
    QCheck.Gen.(
      oneof_weighted
        [
          (3, int_range 0 0x7F);
          (1, int_range 0x80 0xD7FF);
          (1, int_range 0xE000 0xFFFF);
          (1, int_range 0x10000 0x10FFFF);
        ])
  in
  let gen =
    QCheck.Gen.(
      map (fun cps -> String.concat "" (List.map utf8 cps)) (list_size (int_range 0 128) scalar))
  in
  run
    (QCheck.Test.make ~count:10_000 ~name:"scalar values"
       (QCheck.make ~print:String.escaped gen)
       property);
  [%expect {| ok |}]
