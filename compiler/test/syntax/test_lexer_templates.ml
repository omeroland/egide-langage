(* T-0005 — prefixed templates with recursive interpolation (LEX-055; decisions of Q-0014 / ADR-0016 / ADR-0017).
   The tests call [Lexer.tokenize] directly (raw tokens, no layout). *)

open Egide_syntax
module D = Egide_diagnostics.Diagnostic

let show_diag (d : D.t) =
  Printf.sprintf "%s %d:%d-%d:%d %s" d.code d.span.start.line d.span.start.col d.span.stop.line
    d.span.stop.col d.message

let show src =
  let toks, diags = Lexer.tokenize ~file:"t.egd" src in
  List.iter
    (fun (t : Lexer.located) ->
      Printf.printf "%d:%d-%d:%d %s\n" t.startp.pos_lnum
        (t.startp.pos_cnum - t.startp.pos_bol + 1)
        t.endp.pos_lnum
        (t.endp.pos_cnum - t.endp.pos_bol + 1)
        (Parse.token_to_string t.tok))
    toks;
  List.iter (fun d -> print_endline (show_diag d)) diags

(* spec: LEX-055 *)
let%expect_test "literal parts and interpolations" =
  show {x|f"a{b}c"
sql"x {y} z"
f"{x}"
f""
|x};
  [%expect
    {|
    1:1-1:9 TEMPLATE("f", ["a"; {IDENT("b")}; "c"])
    2:1-2:13 TEMPLATE("sql", ["x "; {IDENT("y")}; " z"])
    3:1-3:7 TEMPLATE("f", [{IDENT("x")}])
    4:1-4:4 TEMPLATE("f", [])
    |}]

(* spec: LEX-055 (templates nest) *)
let%expect_test "nested templates" =
  show {x|f"{f"{x}"}"|x};
  [%expect {| 1:1-1:12 TEMPLATE("f", [{TEMPLATE("f", [{IDENT("x")}])}]) |}]

(* spec: LEX-055 ({{ and }} are the only lexer escapes) *)
let%expect_test "doubled braces" =
  show {x|f"{{a}}"|x};
  [%expect {| 1:1-1:9 TEMPLATE("f", ["{a}"]) |}]

(* spec: LEX-055, LEX-052, LEX-053 (r and b are not template prefixes; keywords are never prefixes) *)
let%expect_test "r, b and keywords are not prefixes" =
  show {x|r"x{y}" b"x" return"x"|x};
  [%expect
    {|
    1:1-1:8 RAW_STRING("x{y}")
    1:9-1:13 BYTES("x")
    1:14-1:20 return
    1:20-1:23 STRING("x")
    |}]

(* spec: LEX-055 (an unterminated interpolation is E0044) *)
let%expect_test "unterminated interpolation" =
  show {x|f"{x|x};
  [%expect {|
    1:1-1:5 TEMPLATE("f", [])
    E0044 1:3-1:5 unterminated interpolation
    |}]

(* spec: LEX-055 (the expression ends at the first `:` or `}` outside brackets; the spec is raw and may be empty) *)
let%expect_test "specs and brackets" =
  show {x|f"{x:>8} {y:} {a(b, c)} {m["k"]:x} { {1, 2} } {c == '"'}"
|x};
  [%expect
    {| 1:1-1:58 TEMPLATE("f", [{IDENT("x") : ">8"}; " "; {IDENT("y") : ""}; " "; {IDENT("a") ( IDENT("b") , IDENT("c") )}; " "; {IDENT("m") [ STRING("k") ] : "x"}; " "; {{ INT("1") , INT("2") }}; " "; {IDENT("c") == CHAR(U+0022)}]) |}]

(* spec: LEX-055 (a backslash only protects the next character; both are kept) *)
let%expect_test "backslash in literal parts" =
  show {x|f"\"{x}\n\{{y}}" f"a\\"
|x};
  [%expect
    {|
    1:1-1:17 TEMPLATE("f", ["\\\""; {IDENT("x")}; "\\n\\{"; {IDENT("y")}; "}"])
    1:18-1:24 TEMPLATE("f", ["a\\\\"])
    E0044 1:15-1:16 a `}` in template text must be doubled (`}}`) or close an interpolation
    |}]

(* spec: LEX-055 (a line break in `{}` only in a triple-quoted template; the margin is computed on all lines) *)
let%expect_test "triple-quoted templates" =
  show
    "f\"\"\"\n\
    \    a {x}\n\
    \      b {\n\
    \        y\n\
    \      } c\n\
    \    \"\"\"\n\
     sql\"\"\"\n\
    \  {a}\n\
    \  {b}\n\
    \  \"\"\"\n";
  [%expect
    {|
    1:1-6:8 TEMPLATE("f", ["a "; {IDENT("x")}; "\n  b "; {IDENT("y")}; " c\n"])
    7:1-10:6 TEMPLATE("sql", [{IDENT("a")}; "\n"; {IDENT("b")}; "\n"])
    |}];
  show "f\"\"\"\r\n  a {x}\r\n  b\r\n  \"\"\"\r\n";
  [%expect {| 1:1-4:6 TEMPLATE("f", ["a "; {IDENT("x")}; "\nb\n"]) |}]

(* spec: LEX-055 (E0044) *)
let%expect_test "malformed interpolations" =
  show "f\"{x\n";
  [%expect
    {|
    1:1-1:5 TEMPLATE("f", [])
    E0044 1:3-1:5 a line break inside an interpolation is only allowed in a triple-quoted template
    |}];
  show "f\"a}b\"\n";
  [%expect
    {|
    1:1-1:7 TEMPLATE("f", ["a}b"])
    E0044 1:4-1:5 a `}` in template text must be doubled (`}}`) or close an interpolation
    |}];
  show "f\"{x # y}\"\n";
  [%expect
    {|
    1:1-1:11 TEMPLATE("f", [{IDENT("x") IDENT("y")}])
    E0044 1:6-1:7 a `#` is not allowed inside an interpolation
    |}];
  show "f\"{}\" f\"{x:a{b}\" f\"{x:a\"b}\"\n";
  [%expect
    {|
    1:1-1:6 TEMPLATE("f", [{}])
    1:7-1:17 TEMPLATE("f", [{IDENT("x") : "ab"}])
    1:18-1:28 TEMPLATE("f", [{IDENT("x") : "ab"}])
    E0044 1:3-1:5 empty interpolation
    E0044 1:13-1:14 a format specifier may not contain `{`, `}` or `"`
    E0044 1:24-1:25 a format specifier may not contain `{`, `}` or `"`
    |}];
  show "f\"{x:\n";
  [%expect {|
    1:1-1:6 TEMPLATE("f", [])
    E0044 1:3-1:6 unterminated interpolation
    |}];
  show "f\"\"\"\n{x:a\nb}\"\"\"\n";
  [%expect
    {|
    1:1-2:5 TEMPLATE("f", [])
    3:1-3:2 IDENT("b")
    3:2-3:3 }
    3:3-4:1 STRING("")
    E0044 2:1-2:5 unterminated interpolation
    E0040 3:3-3:6 unterminated string literal
    |}]

(* spec: LEX-055 (at most 8 levels; deeper is E0044 and is not read further) *)
let%expect_test "nesting limit" =
  let rec nest n = if n = 0 then "x" else "f\"{" ^ nest (n - 1) ^ "}\"" in
  let toks, diags = Lexer.tokenize ~file:"t.egd" (nest 8) in
  Printf.printf "%d tokens, %d diagnostics\n" (List.length toks) (List.length diags);
  [%expect {| 1 tokens, 0 diagnostics |}];
  let toks, diags = Lexer.tokenize ~file:"t.egd" (nest 9) in
  Printf.printf "%d tokens, %s\n" (List.length toks) (String.concat "; " (List.map show_diag diags));
  [%expect {| 1 tokens, E0044 1:25-1:27 templates nest at most 8 levels deep |}];
  (* a hostile depth: bounded work, no stack overflow *)
  let toks, diags = Lexer.tokenize ~file:"t.egd" (nest 100_000) in
  Printf.printf "%d tokens, %d diagnostics\n" (List.length toks) (List.length diags);
  [%expect {| 1 tokens, 1 diagnostics |}]

(* spec: LEX-055 (interpolation tokens carry their exact source positions, also after a line break and with
   multi-byte characters before them) *)
let%expect_test "interpolation positions" =
  let toks, diags =
    Lexer.tokenize ~file:"t.egd" "f\"é{ab + 1}\" sql\"\"\"\n  {\n    cd:s}\n  \"\"\"\n"
  in
  assert (diags = []);
  let pos (p : Lexing.position) = Printf.sprintf "%d:%d" p.pos_lnum (p.pos_cnum - p.pos_bol + 1) in
  let rec dump (toks : (Tokens.token * Lexing.position * Lexing.position) list) =
    List.iter
      (fun (tok, s, e) ->
        match tok with
        | Tokens.TEMPLATE t ->
            List.iter
              (function
                | Tokens.Tpl_lit _ -> ()
                | Tokens.Tpl_interp i ->
                    Printf.printf "interp %s-%s spec=%s\n" (pos i.open_pos) (pos i.close_pos)
                      (match i.spec with None -> "-" | Some sp -> pos sp.spec_pos ^ " " ^ sp.text);
                    dump i.toks)
              t.parts
        | _ -> Printf.printf "%s-%s %s\n" (pos s) (pos e) (Parse.token_to_string tok))
      toks
  in
  dump (List.map (fun (t : Lexer.located) -> (t.tok, t.startp, t.endp)) toks);
  [%expect
    {|
    interp 1:4-1:12 spec=-
    1:5-1:7 IDENT("ab")
    1:8-1:9 +
    1:10-1:11 INT("1")
    interp 2:3-3:10 spec=3:8 s
    3:5-3:7 IDENT("cd")
    |}]

(* spec: LEX-055 (the lexer never raises, whatever the template-like input; every interpolation token lies inside the
   interpolation it belongs to) *)
let alphabet =
  [|
    'f'; 'x'; '"'; '"'; '{'; '}'; ':'; '\\'; '\''; '#'; '\n'; ' '; '('; ')'; '['; ']'; 'r'; 'b'; 'a';
  |]

let gen_template_soup =
  QCheck.Gen.(
    string_size (0 -- 80) ~gen:(map (fun i -> alphabet.(i)) (0 -- (Array.length alphabet - 1))))

let rec inside (toks : (Tokens.token * Lexing.position * Lexing.position) list)
    (lo : Lexing.position) (hi : Lexing.position) =
  List.for_all
    (fun (tok, (s : Lexing.position), (e : Lexing.position)) ->
      s.pos_cnum >= lo.pos_cnum && e.pos_cnum <= hi.pos_cnum && s.pos_cnum <= e.pos_cnum
      && match tok with Tokens.TEMPLATE t -> template_ok t | _ -> true)
    toks

and template_ok (t : Tokens.template) =
  List.for_all
    (function
      | Tokens.Tpl_lit _ -> true | Tokens.Tpl_interp i -> inside i.toks i.open_pos i.close_pos)
    t.parts

let%test "template soup: no exception, interpolation tokens inside their braces" =
  QCheck.Test.check_exn
    (QCheck.Test.make ~name:"template soup" ~count:3000 (QCheck.make gen_template_soup) (fun src ->
         let toks, _ = Lexer.tokenize ~file:"t.egd" src in
         inside
           (List.map (fun (t : Lexer.located) -> (t.tok, t.startp, t.endp)) toks)
           Lexing.dummy_pos
           { Lexing.dummy_pos with pos_cnum = max_int }));
  true

(* spec: LEX-055, LEX-051 (nested triple-quoted templates with multi-byte characters: the source text of an
   interpolation is found by character position) *)
let%expect_test "nested triple-quoted templates" =
  show "f\"\"\"\n  é {f\"\"\"\n    ü {x}\n    \"\"\"} ö\n  \"\"\"\n";
  [%expect
    {| 1:1-5:6 TEMPLATE("f", ["\195\169 "; {TEMPLATE("f", ["\195\188 "; {IDENT("x")}; "\n"])}; " \195\182\n"]) |}]
