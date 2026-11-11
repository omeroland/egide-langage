(* T-0004 — string, raw, triple-quoted, byte and character literals (LEX-050..054; decisions of Q-0015 / Q-0014 /
   ADR-0016 / ADR-0017). The tests call [Lexer.tokenize] directly (raw tokens, no layout). *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show_diag (d : D.t) =
  Printf.sprintf "%s %d:%d-%d:%d %s" d.code d.span.start.line d.span.start.col d.span.stop.line
    d.span.stop.col d.message

let tokens src =
  let toks, diags = Lexer.tokenize ~file:"t.egd" src in
  (toks, diags)

let show src =
  let toks, diags = tokens src in
  List.iter
    (fun (t : Lexer.located) ->
      Printf.printf "%d:%d-%d:%d %s\n" t.startp.pos_lnum
        (t.startp.pos_cnum - t.startp.pos_bol + 1)
        t.endp.pos_lnum
        (t.endp.pos_cnum - t.endp.pos_bol + 1)
        (Parse.token_to_string t.tok))
    toks;
  List.iter (fun d -> print_endline (show_diag d)) diags

(* spec: LEX-050 *)
let%expect_test "string escapes" =
  show {x|"a\\b"
"q\"q"
"\n\t\r\0"
"\{\}"
""
"é日本"
|x};
  [%expect
    {|
    1:1-1:7 STRING("a\\b")
    2:1-2:7 STRING("q\"q")
    3:1-3:11 STRING("\n\t\r\000")
    4:1-4:7 STRING("{}")
    5:1-5:3 STRING("")
    6:1-6:6 STRING("\195\169\230\151\165\230\156\172")
    |}]

(* spec: LEX-050 (ADR-0017: any scalar value, including the code points of LEX-003) *)
let%expect_test "unicode escapes accept every scalar value" =
  show {x|"\u{41}"
"\u{e9}\u{E9}"
"\u{10FFFF}"
"\u{0}"
"\u{202E}"
"\u{D7FF}\u{E000}"
|x};
  [%expect
    {|
    1:1-1:9 STRING("A")
    2:1-2:15 STRING("\195\169\195\169")
    3:1-3:13 STRING("\244\143\191\191")
    4:1-4:8 STRING("\000")
    5:1-5:11 STRING("\226\128\174")
    6:1-6:19 STRING("\237\159\191\238\128\128")
    |}]

(* spec: LEX-050; acceptance criterion: invalid escape -> E0041 at the backslash *)
let%expect_test "invalid escapes are E0041 at the backslash" =
  show {x|"\q"
"a\x41"
"\'"
"\u41"
"\u{}"
"\u{110000}"
"\u{D800}"
"\u{1234567}"
"\u{41"
|x};
  [%expect
    {|
    1:1-1:5 STRING("")
    2:1-2:8 STRING("a41")
    3:1-3:5 STRING("")
    4:1-4:7 STRING("41")
    5:1-5:7 STRING("")
    6:1-6:13 STRING("")
    7:1-7:11 STRING("")
    8:1-8:14 STRING("")
    9:1-9:8 STRING("")
    E0041 1:2-1:4 invalid escape sequence `\q`
    E0041 2:3-2:5 invalid escape sequence `\x`
    E0041 3:2-3:4 invalid escape sequence `\'`
    E0041 4:2-4:4 `\u` must be followed by `{`, 1 to 6 hexadecimal digits and `}`
    E0041 5:2-5:6 `\u{}` needs 1 to 6 hexadecimal digits
    E0041 6:2-6:12 U+110000 is above U+10FFFF, so it is not a Unicode scalar value
    E0041 7:2-7:10 U+D800 is a surrogate, so it is not a Unicode scalar value
    E0041 8:2-8:13 `\u{...}` takes at most 6 hexadecimal digits
    E0041 9:2-9:7 missing `}` after the hexadecimal digits of `\u{`
    |}]

(* spec: LEX-050; the message never carries a raw forbidden character (LEX-006) *)
let%expect_test "the offending character of an invalid escape is shown escaped" =
  show "\"\\\xE2\x80\xAE\"\n";
  [%expect
    {|
    1:1-1:5 STRING("")
    E0004 1:3-1:4 forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    E0041 1:2-1:4 invalid escape sequence `\\u{202E}`
    |}]

(* spec: LEX-050; acceptance criterion: unterminated literal -> E0040 at the opening quote *)
let%expect_test "unterminated strings" =
  show "\"abc\nx";
  [%expect
    {|
    1:1-1:5 STRING("abc")
    2:1-2:2 IDENT("x")
    E0040 1:1-1:2 unterminated string literal
    |}];
  show "\"abc";
  [%expect {|
    1:1-1:5 STRING("abc")
    E0040 1:1-1:2 unterminated string literal
    |}];
  show "\"ab\\\nx";
  [%expect
    {|
    1:1-1:5 STRING("ab")
    2:1-2:2 IDENT("x")
    E0040 1:1-1:2 unterminated string literal
    E0041 1:4-1:5 invalid escape sequence: a backslash at the end of the line
    |}];
  show "\"ab\r\nx";
  [%expect
    {|
    1:1-1:4 STRING("ab")
    2:1-2:2 IDENT("x")
    E0040 1:1-1:2 unterminated string literal
    |}]

(* spec: LEX-050 (a tab is allowed inside a string, LEX-004) *)
let%expect_test "a raw tab is part of a plain string" =
  show "\"a\tb\"";
  [%expect {| 1:1-1:6 STRING("a\tb") |}]

(* spec: LEX-052 *)
let%expect_test "raw strings process no escape" =
  show {x|r"C:\dir\"
r"\n\u{zz}"
r""
r"""a\"""
rb"x"
|x};
  [%expect
    {|
    1:1-1:11 RAW_STRING("C:\\dir\\")
    2:1-2:12 RAW_STRING("\\n\\u{zz}")
    3:1-3:4 RAW_STRING("")
    4:1-4:10 RAW_STRING("a\\")
    5:1-5:6 TEMPLATE("rb", ["x"])
    |}];
  show "r\"abc\nx";
  [%expect
    {|
    1:1-1:6 RAW_STRING("abc")
    2:1-2:2 IDENT("x")
    E0040 1:2-1:3 unterminated string literal
    |}]

(* spec: LEX-051 *)
let%expect_test "triple-quoted strings" =
  show {x|"""one"""
"""
    hello
      world
    """
""""""
|x};
  [%expect
    {|
    1:1-1:10 STRING("one")
    2:1-5:8 STRING("hello\n  world\n")
    6:1-6:7 STRING("")
    |}]

(* spec: LEX-051 — expected values computed with Python's textwrap.dedent on the same text. The source is a
   triple-quoted string whose content is [content], after the line break that follows the opening quotes. *)
let dedent_cases =
  [
    ("    a\n    b\n    ", "a\nb\n");
    ("  a\n    b\n  ", "a\n  b\n");
    ("    a\n  b\n", "  a\nb\n");
    ("a\n  b\n", "a\n  b\n");
    ("  a\n\n  b\n", "a\n\nb\n");
    ("  a\n    \n  b", "a\n\nb");
    ("      a\n  \n    b\n", "  a\n\nb\n");
    ("   \n   \n", "\n\n");
    ("  a  \n  b", "a  \nb");
    ("    x\n      y\n        z\n  ", "x\n  y\n    z\n");
    ("  abc", "abc");
    ("  \xC3\xA9\n   \xC3\xBC\n  ", "\xC3\xA9\n \xC3\xBC\n");
    ("\n  a\n\n  b\n  ", "\na\n\nb\n");
    ("  \"q\" \"\"x\n   y\n", "\"q\" \"\"x\n y\n");
  ]

let%expect_test "triple-quoted dedent agrees with textwrap.dedent" =
  List.iteri
    (fun i (content, expected) ->
      let toks, diags = tokens ("\"\"\"\n" ^ content ^ "\"\"\"") in
      match (toks, diags) with
      | [ { tok = Tokens.STRING s; _ } ], [] when s = expected ->
          Printf.printf "case %d ok\n" (i + 1)
      | _ -> Printf.printf "case %d FAILED\n" (i + 1))
    dedent_cases;
  [%expect
    {|
    case 1 ok
    case 2 ok
    case 3 ok
    case 4 ok
    case 5 ok
    case 6 ok
    case 7 ok
    case 8 ok
    case 9 ok
    case 10 ok
    case 11 ok
    case 12 ok
    case 13 ok
    case 14 ok
    |}]

(* spec: LEX-051 (Q-0015: dedent on raw lines before escapes; first line break dropped only right after the quotes) *)
let%expect_test "triple-quoted details" =
  show "\"\"\"  \nx\"\"\"";
  [%expect {| 1:1-2:5 STRING("\nx") |}];
  show "\"\"\"  abc\"\"\"";
  [%expect {| 1:1-1:12 STRING("abc") |}];
  (* the escape \n is processed after dedent: it adds a line break, it is not a line *)
  show "\"\"\"\n  a\n  \\n\n  \"\"\"";
  [%expect {| 1:1-4:6 STRING("a\n\n\n") |}];
  show "\"\"\"\r\n  a\r\n  b\r\n  \"\"\"";
  [%expect {| 1:1-4:6 STRING("a\nb\n") |}];
  show "\"\"\"a\\\"\"\"\"";
  [%expect {| 1:1-1:10 STRING("a\"") |}];
  (* the literal closes at the first unescaped triple quote; the fourth quote opens a new string *)
  show "\"\"\"a\"\"\"\"\n";
  [%expect
    {|
    1:1-1:8 STRING("a")
    1:8-1:9 STRING("")
    E0040 1:8-1:9 unterminated string literal
    |}];
  show "\"\"\"abc\n  def";
  [%expect {|
    1:1-2:6 STRING("abc\n  def")
    E0040 1:1-1:4 unterminated string literal
    |}];
  show "\"\"\"\n    a\\q\n    \"\"\"";
  [%expect {|
    1:1-3:8 STRING("a\n")
    E0041 2:6-2:8 invalid escape sequence `\q`
    |}];
  (* raw triple-quoted: dedent applies, escapes do not *)
  show "r\"\"\"\n    a\\n\n    \"\"\"";
  [%expect {| 1:1-3:8 RAW_STRING("a\\n\n") |}]

(* spec: LEX-051, LEX-004: a tab in the margin is E0005 *)
let%expect_test "a tab in the margin of a triple-quoted string" =
  show "\"\"\"\n\tx\n    y\n    \"\"\"";
  [%expect
    {|
    1:1-4:8 STRING("x\n   y\n")
    E0005 2:1-2:2 tab character in the margin of a triple-quoted string; indent with spaces
    |}];
  (* a tab that is not in the margin is text *)
  show "\"\"\"\n  a\tb\n  \"\"\"";
  [%expect {| 1:1-3:6 STRING("a\tb\n") |}];
  (* review of PR #26: a tab in the indentation but beyond the margin is content, not E0005 *)
  show "\"\"\"\n  a\n    \tb\n  \"\"\"";
  [%expect {| 1:1-4:6 STRING("a\n  \tb\n") |}];
  (* extrapolated (Q-0051.3): a tab on a blank line is E0005 *)
  show "\"\"\"\n  a\n\t\n  b\n  \"\"\"";
  [%expect
    {|
    1:1-5:6 STRING("a\n\nb\n")
    E0005 3:1-3:2 tab character in the margin of a triple-quoted string; indent with spaces
    |}]

(* spec: LEX-053 *)
let%expect_test "byte strings" =
  show {x|b"abc \x00\xFF\xff"
b"\\ \" \n \t \r \0"
b""
b"~ !"
|x};
  [%expect
    {|
    1:1-1:20 BYTES("abc \000\255\255")
    2:1-2:21 BYTES("\\ \" \n \t \r \000")
    3:1-3:4 BYTES("")
    4:1-4:7 BYTES("~ !")
    |}]

(* spec: LEX-053 *)
let%expect_test "byte strings reject non-ASCII, controls and the other escapes" =
  show
    "b\"\xC3\xA9\"\n\
     b\"\t\"\n\
     b\"\\u{41}\"\n\
     b\"\\{\"\n\
     b\"\\}\"\n\
     b\"\\x4\"\n\
     b\"\\q\"\n\
     b\"\\'\"\n\
     b\"\\xZZ\"\n";
  [%expect
    {|
    1:1-1:5 BYTES("")
    2:1-2:5 BYTES("")
    3:1-3:10 BYTES("{41}")
    4:1-4:6 BYTES("")
    5:1-5:6 BYTES("")
    6:1-6:7 BYTES("")
    7:1-7:6 BYTES("")
    8:1-8:6 BYTES("")
    9:1-9:8 BYTES("ZZ")
    E0043 1:3-1:4 character U+00E9 is not allowed in a byte string (printable ASCII U+0020 to U+007E only)
    E0043 2:3-2:4 character U+0009 is not allowed in a byte string (printable ASCII U+0020 to U+007E only)
    E0043 3:3-3:5 escape `\u` is not allowed in a byte string; the escapes are `\\ \" \n \t \r \0 \xHH`
    E0043 4:3-4:5 escape `\{` is not allowed in a byte string; the escapes are `\\ \" \n \t \r \0 \xHH`
    E0043 5:3-5:5 escape `\}` is not allowed in a byte string; the escapes are `\\ \" \n \t \r \0 \xHH`
    E0041 6:3-6:6 `\x` must be followed by exactly two hexadecimal digits
    E0041 7:3-7:5 invalid escape sequence `\q`
    E0041 8:3-8:5 invalid escape sequence `\'`
    E0041 9:3-9:5 `\x` must be followed by exactly two hexadecimal digits
    |}];
  (* there is no raw byte string rb"...": LEX-053 gives no meaning to r or b before another prefix, and by LEX-055 `rb` is
     an ordinary template prefix (a template with one literal part). Open question Q-0052 (tasks/blocked) asks whether
     `rb"..."` should instead be an error; this expectation follows the current lexer, not a decision *)
  show "rb\"x\"\n";
  [%expect {| 1:1-1:6 TEMPLATE("rb", ["x"]) |}];
  (* b"""...""" is E0043 on the three quotes (Q-0051.6); the body is read as a triple-quoted string *)
  show "b\"\"\"\n  a\n  \"\"\"\n";
  [%expect
    {|
    1:1-3:6 BYTES("a\n")
    E0043 1:2-1:5 a byte string has no triple-quoted form; use b"..." with escapes
    |}]

(* spec: LEX-003 (raw input check): a forbidden character written in a literal is E0004 in every literal form, and
   the literal still lexes. U+202E, then NUL. *)
let%expect_test "raw bidi and NUL characters in every literal form" =
  show
    "'\xE2\x80\xAE'\n\
     b\"\xE2\x80\xAE\"\n\
     \"\"\"\n\
    \ a\xE2\x80\xAE\n\
    \ \"\"\"\n\
     '\000'\n\
     b\"\000\"\n\
     \"\"\"\n\
    \ \000\n\
     \"\"\"\n";
  [%expect
    {|
    1:1-1:4 CHAR(U+202E)
    2:1-2:5 BYTES("")
    3:1-5:5 STRING("a\226\128\174\n")
    6:1-6:4 CHAR(U+0000)
    7:1-7:5 BYTES("")
    8:1-10:4 STRING("\000\n")
    E0004 1:2-1:3 forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    E0004 2:3-2:4 forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    E0004 4:3-4:4 forbidden character U+202E (RIGHT-TO-LEFT OVERRIDE) — risk: hidden or reordered source text (Trojan Source)
    E0004 6:2-6:3 forbidden character U+0000 (control character) — risk: hidden or reordered source text (Trojan Source)
    E0004 7:3-7:4 forbidden character U+0000 (control character) — risk: hidden or reordered source text (Trojan Source)
    E0004 9:2-9:3 forbidden character U+0000 (control character) — risk: hidden or reordered source text (Trojan Source)
    E0043 2:3-2:4 character U+202E is not allowed in a byte string (printable ASCII U+0020 to U+007E only)
    E0043 7:3-7:4 character U+0000 is not allowed in a byte string (printable ASCII U+0020 to U+007E only)
    |}]

(* spec: LEX-054 *)
let%expect_test "character literals" =
  show "'a'\n'\\n'\n'\\u{E9}'\n'\\''\n'\"'\n'\\\\'\n'\xC3\xA9'\n'\\u{202E}'\n'\\\"'\n'\\0'\n";
  [%expect
    {|
    1:1-1:4 CHAR(U+0061)
    2:1-2:5 CHAR(U+000A)
    3:1-3:9 CHAR(U+00E9)
    4:1-4:5 CHAR(U+0027)
    5:1-5:4 CHAR(U+0022)
    6:1-6:5 CHAR(U+005C)
    7:1-7:4 CHAR(U+00E9)
    8:1-8:11 CHAR(U+202E)
    9:1-9:5 CHAR(U+0022)
    10:1-10:5 CHAR(U+0000)
    |}]

(* spec: LEX-054 *)
let%expect_test "character literal errors" =
  show "''\n'ab'\n'\\n\\n'\n'\\{'\n'\\}'\n'\\x41'\n'\\u{D800}'\n'\t'\n";
  [%expect
    {|
    1:1-1:3 CHAR(U+FFFD)
    2:1-2:5 CHAR(U+FFFD)
    3:1-3:7 CHAR(U+FFFD)
    4:1-4:5 CHAR(U+FFFD)
    5:1-5:5 CHAR(U+FFFD)
    6:1-6:7 CHAR(U+FFFD)
    7:1-7:11 CHAR(U+FFFD)
    8:1-8:4 CHAR(U+0009)
    E0042 1:1-1:3 character literal must contain exactly one character, found 0
    E0042 2:1-2:5 character literal must contain exactly one character, found 2
    E0042 3:1-3:7 character literal must contain exactly one character, found 2
    E0041 4:2-4:4 invalid escape sequence `\{`
    E0041 5:2-5:4 invalid escape sequence `\}`
    E0041 6:2-6:4 invalid escape sequence `\x`
    E0041 7:2-7:10 U+D800 is a surrogate, so it is not a Unicode scalar value
    E0005 8:2-8:3 tab character in a character literal; write '\t'
    |}];
  show "'a\nx";
  [%expect
    {|
    1:1-1:3 CHAR(U+FFFD)
    2:1-2:2 IDENT("x")
    E0040 1:1-1:2 unterminated character literal
    |}];
  show "'";
  [%expect {|
    1:1-1:2 CHAR(U+FFFD)
    E0040 1:1-1:2 unterminated character literal
    |}]

(* Sizes: a literal of millions of characters or lines must lex without stack growth and in linear time. *)
let%expect_test "very large literals" =
  let n = 3_000_000 in
  let count src =
    match tokens src with
    | [ { tok = Tokens.STRING s; _ } ], [] -> String.length s
    | [ { tok = Tokens.BYTES s; _ } ], [] | [ { tok = Tokens.RAW_STRING s; _ } ], [] ->
        String.length s
    | _ -> -1
  in
  Printf.printf "%d\n" (count ("\"" ^ String.make n 'a' ^ "\""));
  Printf.printf "%d\n" (count ("r\"" ^ String.make n 'a' ^ "\""));
  Printf.printf "%d\n" (count ("\"" ^ String.concat "" (List.init (n / 2) (fun _ -> "\\n")) ^ "\""));
  Printf.printf "%d\n"
    (count ("b\"" ^ String.concat "" (List.init (n / 4) (fun _ -> "\\xFF")) ^ "\""));
  Printf.printf "%d\n"
    (count ("\"\"\"\n" ^ String.concat "" (List.init 300_000 (fun _ -> "  line\n")) ^ "\"\"\""));
  [%expect {|
    3000000
    3000000
    1500000
    750000
    1500000
    |}]

(* ---- properties ---- *)

let seeded t = QCheck2.Test.check_exn ~rand:(Random.State.make [| 4 |]) t
let hex = Printf.sprintf "%X"

let utf8 cps =
  let b = Buffer.create 16 in
  List.iter (fun cp -> Buffer.add_utf_8_uchar b (Uchar.of_int cp)) cps;
  Buffer.contents b

let scalar =
  QCheck2.Gen.(
    oneof
      [
        int_range 0 0x7F;
        int_range 0x80 0xD7FF;
        int_range 0xE000 0x10FFFF;
        oneof_list [ 0x202E; 0x22; 0x5C; 0x0A; 0x7B; 0x27 ];
      ])

let single tok_src = match tokens tok_src with [ { tok; _ } ], [] -> Some tok | _ -> None

let%test_unit "never raises, tokens are ordered and inside the source" =
  seeded
    (QCheck2.Test.make ~name:"literal soup" ~count:20000
       QCheck2.Gen.(
         list_size (int_range 0 40)
           (oneof_list
              [
                "\"";
                "'";
                "\\";
                "r";
                "b";
                "\n";
                "\r\n";
                " ";
                "\t";
                "u";
                "{";
                "}";
                "x";
                "0";
                "a";
                "\xC3\xA9";
                "\xF0\x9F\x98\x80";
                "\"\"\"";
                "\\u{";
                "\\x";
              ])
         |> map (String.concat ""))
       (fun src ->
         let toks, _ = tokens src in
         let rec ordered prev = function
           | [] -> true
           | (t : Lexer.located) :: rest ->
               t.startp.pos_cnum >= prev
               && t.endp.pos_cnum >= t.startp.pos_cnum
               && ordered t.endp.pos_cnum rest
         in
         ordered 0 toks))

let%test_unit "a plain string written with escapes lexes back to its value" =
  seeded
    (QCheck2.Test.make ~name:"string roundtrip" ~count:5000
       QCheck2.Gen.(list_size (int_range 0 30) scalar)
       (fun cps ->
         let lit = String.concat "" (List.map (fun cp -> Printf.sprintf "\\u{%s}" (hex cp)) cps) in
         single ("\"" ^ lit ^ "\"") = Some (Tokens.STRING (utf8 cps))))

let%test_unit "a character written with an escape lexes back to its scalar value" =
  seeded
    (QCheck2.Test.make ~name:"char roundtrip" ~count:5000 scalar (fun cp ->
         single (Printf.sprintf "'\\u{%s}'" (hex cp)) = Some (Tokens.CHAR (Uchar.of_int cp))))

let%test_unit "a byte string written with \\xHH lexes back to its bytes" =
  seeded
    (QCheck2.Test.make ~name:"bytes roundtrip" ~count:5000
       QCheck2.Gen.(string_size (int_range 0 40))
       (fun s ->
         let lit =
           String.concat ""
             (List.map
                (fun c -> Printf.sprintf "\\x%02X" (Char.code c))
                (List.of_seq (String.to_seq s)))
         in
         single ("b\"" ^ lit ^ "\"") = Some (Tokens.BYTES s)))

let%test_unit "a raw string keeps every character but the quote and the line break" =
  seeded
    (QCheck2.Test.make ~name:"raw roundtrip" ~count:5000
       QCheck2.Gen.(
         string_size
           ~gen:(oneof [ char_range 'a' 'z'; return '\\'; return '{'; return '\t'; return ' ' ])
           (int_range 0 40))
       (fun s -> single ("r\"" ^ s ^ "\"") = Some (Tokens.RAW_STRING s)))

(* The reference model of LEX-051: margin = fewest leading spaces among non-blank lines. *)
let model_dedent content =
  let lines = String.split_on_char '\n' content in
  let lead l =
    let n = String.length l in
    let rec go i = if i < n && l.[i] = ' ' then go (i + 1) else i in
    go 0
  in
  let blank l = lead l = String.length l in
  let margin = List.fold_left (fun m l -> if blank l then m else min m (lead l)) max_int lines in
  String.concat "\n"
    (List.map
       (fun l -> if blank l then "" else String.sub l margin (String.length l - margin))
       lines)

let%test_unit "triple-quoted dedent agrees with the reference model" =
  seeded
    (QCheck2.Test.make ~name:"dedent model" ~count:5000
       QCheck2.Gen.(
         list_size (int_range 1 8)
           (map2
              (fun n t -> String.make n ' ' ^ t)
              (int_range 0 6)
              (oneof_list [ ""; "a"; "bc d"; "x  " ]))
         |> map (String.concat "\n"))
       (fun content ->
         let src = "\"\"\"\n" ^ content ^ "\"\"\"" in
         single src = Some (Tokens.STRING (model_dedent content))))

(* A value that holds a forbidden or bidirectional code point (only possible through `\u{H}`) is printed with an escape,
   so that the printed AST is safe to display (LEX-006) and lexes back to the same value (LEX-003 would reject it). *)
let%test_unit "a printed string literal lexes back to the same value" =
  seeded
    (QCheck2.Test.make ~name:"print then lex" ~count:5000
       QCheck2.Gen.(list_size (int_range 0 20) scalar)
       (fun cps ->
         let v = utf8 cps in
         let sp = Egide_source.Span.dummy in
         let gen = Node_id.Gen.create () in
         let e = { Ast.id = Node_id.Gen.fresh gen; expr = Ast.Lit (Ast.String v); span = sp } in
         (* the printer shows [(string "...")]: take the quoted atom *)
         let printed = Print.expr e in
         let q = String.index printed '"' in
         let lit = String.sub printed q (String.rindex printed '"' - q + 1) in
         single lit = Some (Tokens.STRING v)))

(* Every diagnostic span of a literal-shaped input is well formed (start not after stop, on an existing line). *)
let%test_unit "diagnostic spans are well formed" =
  seeded
    (QCheck2.Test.make ~name:"spans" ~count:20000
       QCheck2.Gen.(
         list_size (int_range 0 40)
           (oneof_list
              [
                "\"";
                "'";
                "\\";
                "r";
                "b";
                "\n";
                "\r\n";
                " ";
                "\t";
                "u";
                "{";
                "}";
                "x";
                "0";
                "a";
                "\xC3\xA9";
                "\"\"\"";
                "\\u{";
                "\\x";
                "\xE2\x80\xAE";
              ])
         |> map (String.concat ""))
       (fun src ->
         let lines = 1 + List.length (String.split_on_char '\n' src) in
         let _, diags = tokens src in
         List.for_all
           (fun (d : D.t) ->
             let a = d.span.start and b = d.span.stop in
             a.line >= 1 && a.col >= 1 && b.line <= lines
             && (a.line < b.line || (a.line = b.line && a.col <= b.col)))
           diags))
