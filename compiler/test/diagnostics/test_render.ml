(* Human rendering of diagnostics (TOOL-040, TOOL-041). Spans are [start, end) with 1-based lines and
   columns counted in Unicode scalar values (docs/diagnostics.md). *)

module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let sp ?(file = "t.egd") l1 c1 l2 c2 =
  Span.make ~file ~start:{ Span.line = l1; col = c1 } ~stop:{ Span.line = l2; col = c2 }

let render files d =
  print_endline (D.render_human ~sources:(fun f -> List.assoc_opt f files) d)

(* spec: TOOL-040 — the one-line form used by the conformance runner is unchanged. *)
let%expect_test "to_human without source keeps the one-line header and notes" =
  let d = D.error ~rule:"LEX-032" ~code:"E0022" ~notes:[ "blocks start at columns 1 and 5" ] (sp 4 3 4 4)
      "inconsistent dedent: no enclosing block starts at column 3" in
  print_endline (D.to_human d);
  [%expect
    {|
    t.egd:4:3: error[E0022]: inconsistent dedent: no enclosing block starts at column 3 (LEX-032)
      note: blocks start at columns 1 and 5
    |}]

(* spec: TOOL-040 — single-line primary span. *)
let%expect_test "single-line span shows the line and carets" =
  let src = "module m\nlet x = 1;\n" in
  render [ ("t.egd", src) ]
    (D.error ~rule:"LEX-061" ~code:"E0050" (sp 2 10 2 11) "`;` is not used in Égide; statements end at line breaks");
  [%expect
    {|
    t.egd:2:10: error[E0050]: `;` is not used in Égide; statements end at line breaks (LEX-061)
      |
    2 | let x = 1;
      |          ^
    |}]

(* spec: TOOL-040 — a warning, and the excerpt is omitted when the source is not available. *)
let%expect_test "warning without available source falls back to the header" =
  render [] (D.warning ~rule:"LEX-061" ~code:"W0001" (sp 2 10 2 11) "unused thing");
  [%expect {| t.egd:2:10: warning[W0001]: unused thing (LEX-061) |}]

(* spec: TOOL-040 — multi-line primary span. *)
let%expect_test "multi-line span marks every covered line" =
  let src = "module m\nlet t = (\n    1,\n    2)\n" in
  render [ ("t.egd", src) ] (D.error ~rule:"SYN-001" ~code:"E0100" (sp 2 9 4 7) "syntax error: unexpected (");
  [%expect
    {|
    t.egd:2:9: error[E0100]: syntax error: unexpected ( (SYN-001)
      |
    2 | let t = (
      |         ^
    3 |     1,
      |     ^^
    4 |     2)
      |     ^^
    |}]

(* spec: TOOL-040 — long multi-line spans elide their middle lines. *)
let%expect_test "long multi-line span elides the middle" =
  let src = "fn f():\n    a\n    b\n    c\n    d\n    e\n" in
  render [ ("t.egd", src) ] (D.error ~rule:"SYN-001" ~code:"E0100" (sp 1 1 6 6) "whole block");
  [%expect
    {|
    t.egd:1:1: error[E0100]: whole block (SYN-001)
      |
    1 | fn f():
      | ^^^^^^^
    ...
    6 |     e
      |     ^
    |}]

(* spec: TOOL-040 — the docs/diagnostics.md example: primary + secondary label, note and fix. *)
let%expect_test "multi-label diagnostic with note and fix" =
  let src = String.concat "" (List.init 11 (fun _ -> "#\n")) ^ "    add(&cart, cart.lines[0])\n" in
  let file = "src/cart.egd" in
  render [ (file, src) ]
    (D.error ~rule:"MEM-021" ~code:"E0301"
       ~labels:[ D.label (sp ~file 12 16 12 29) "used here" ]
       ~notes:[ "an inout argument must be exclusively accessible during the call (MEM-021)" ]
       ~fixes:[ D.fix "copy the element first" [ D.edit (sp ~file 12 5 12 5) "let first = cart.lines[0]\n" ] ]
       (sp ~file 12 9 12 14)
       "`cart` is passed as inout and also used by another argument of the same call");
  [%expect
    {|
    src/cart.egd:12:9: error[E0301]: `cart` is passed as inout and also used by another argument of the same call (MEM-021)
       |
    12 |     add(&cart, cart.lines[0])
       |         ^^^^^  ------------- used here
      note: an inout argument must be exclusively accessible during the call (MEM-021)
      help: copy the element first
        src/cart.egd:12:5: insert "let first = cart.lines[0]\n"
    |}]

(* spec: TOOL-040 — several labels on one line stack their messages; labels on distant lines are
   separated by an ellipsis. *)
let%expect_test "stacked labels and distant lines" =
  let src = "fn f(a: int, b: int) -> int:\n    let c = 1\n    let d = 2\n    g(a, b, c)\n" in
  render [ ("t.egd", src) ]
    (D.error ~rule:"MEM-021" ~code:"E0301"
       ~labels:
         [ D.label (sp 4 7 4 8) "first use"; D.label (sp 4 10 4 11) "second use"; D.label (sp 1 6 1 12) "declared here" ]
       (sp 4 13 4 14) "conflict");
  [%expect
    {|
    t.egd:4:13: error[E0301]: conflict (MEM-021)
      |
    1 | fn f(a: int, b: int) -> int:
      |      ------ declared here
    ...
    4 |     g(a, b, c)
      |       -  -  ^
      |       |  |
      |       |  second use
      |       first use
    |}]

(* spec: TOOL-040 — a label message goes inline only when nothing is marked to its right. *)
let%expect_test "a label left of a longer mark is stacked below" =
  let src = "x = foo(bar)\n" in
  render [ ("t.egd", src) ]
    (D.error ~rule:"SYN-001" ~code:"E0100" ~labels:[ D.label (sp 1 5 1 8) "callee" ] (sp 1 9 1 12) "bad argument");
  [%expect
    {|
    t.egd:1:9: error[E0100]: bad argument (SYN-001)
      |
    1 | x = foo(bar)
      |     --- ^^^
      |     |
      |     callee
    |}]

(* spec: TOOL-040 — secondary spans may point into other files, with or without available source. *)
let%expect_test "labels in other files" =
  render
    [ ("a.egd", "use b.thing\n"); ("b.egd", "module b\npub fn thing():\n") ]
    (D.error ~rule:"SYN-001" ~code:"E0100"
       ~labels:[ D.label (sp ~file:"b.egd" 2 8 2 13) "defined here"; D.label (sp ~file:"c.egd" 3 1 3 2) "and here" ]
       (sp ~file:"a.egd" 1 5 1 12) "something about b.thing");
  [%expect
    {|
    a.egd:1:5: error[E0100]: something about b.thing (SYN-001)
      |
    1 | use b.thing
      |     ^^^^^^^
      --> b.egd
      |
    2 | pub fn thing():
      |        ----- defined here
      --> c.egd:3:1: and here
    |}]

(* spec: TOOL-040 — an empty span (insertion point, end of line) still gets one caret. *)
let%expect_test "empty span at end of line" =
  render [ ("t.egd", "fn f()\n") ] (D.error ~rule:"LEX-033" ~code:"E0023" (sp 1 7 1 7) "expected `:`");
  [%expect
    {|
    t.egd:1:7: error[E0023]: expected `:` (LEX-033)
      |
    1 | fn f()
      |       ^
    |}]

(* Columns count Unicode scalar values (docs/diagnostics.md): `é` is one column, the emoji is one
   column but two display cells, so the caret under `+` is shifted by one cell. *)
let%expect_test "columns count scalar values; carets follow display width" =
  let src = "let s = \"é🎉\" + 1\n" in
  render [ ("t.egd", src) ] (D.error ~rule:"SYN-001" ~code:"E0100" (sp 1 14 1 15) "unexpected +");
  [%expect
    {|
    t.egd:1:14: error[E0100]: unexpected + (SYN-001)
      |
    1 | let s = "é🎉" + 1
      |               ^
    |}]

(* spec: LEX-003, TOOL-041 — the excerpt must not replay a Trojan Source attack in the terminal:
   bidi controls, other invisible characters and invalid bytes are shown escaped, and carets stay
   aligned with the escaped text. *)
let%expect_test "excerpt escapes bidi controls and invalid bytes" =
  let src = "let s = \"a\xE2\x80\xAEb\" \xFF x\n" in
  render [ ("t.egd", src) ]
    (D.error ~rule:"LEX-003" ~code:"E0004" ~labels:[ D.label (sp 1 17 1 18) "x" ] (sp 1 11 1 12)
       "forbidden character U+202E — risk: hidden or reordered source text (Trojan Source)");
  [%expect
    {|
    t.egd:1:11: error[E0004]: forbidden character U+202E — risk: hidden or reordered source text (Trojan Source) (LEX-003)
      |
    1 | let s = "a<U+202E>b" <0xFF> x
      |           ^^^^^^^^          - x
    |}]

(* spec: TOOL-040 — messages are one line; control and bidi characters in free text are escaped. *)
let%expect_test "messages are sanitised" =
  print_endline
    (D.to_human (D.error ~rule:"SEC-002" ~code:"E0412" ~notes:[ "a\nb" ] (sp 1 1 1 2) "evil \xE2\x80\xAE text\x1b[31m"));
  [%expect
    {|
    t.egd:1:1: error[E0412]: evil <U+202E> text<U+001B>[31m (SEC-002)
      note: a<U+000A>b
    |}]

(* Tabs (allowed in string literals only, LEX-004) are shown as 4 spaces; CR LF line ends are not
   shown. *)
let%expect_test "tabs expand and CR LF is stripped" =
  render [ ("t.egd", "let s = \"\tx\" ;\r\n") ] (D.error ~rule:"LEX-061" ~code:"E0050" (sp 1 14 1 15) "semicolon");
  [%expect
    {|
    t.egd:1:14: error[E0050]: semicolon (LEX-061)
      |
    1 | let s = "    x" ;
      |                 ^
    |}]

(* A span outside the available source (stale or malformed) does not crash the renderer nor
   allocate a marker as wide as its column: it is listed as a location. *)
let%expect_test "span beyond the end of the source falls back to a location line" =
  render [ ("t.egd", "x\n") ]
    (D.error ~rule:"SYN-001" ~code:"E0100"
       ~labels:[ D.label (sp 9 1 9 2) "far away"; D.label (sp 1 1_000_000_000 1 1_000_000_001) "too wide" ]
       (sp 1 1 1 2) "msg");
  render [ ("t.egd", "x\n") ] (D.error ~rule:"SYN-001" ~code:"E0100" (sp 1 0 1 1) "column zero");
  [%expect
    {|
    t.egd:1:1: error[E0100]: msg (SYN-001)
      |
    1 | x
      | ^
      --> t.egd:9:1: far away
      --> t.egd:1:1000000000: too wide
    t.egd:1:0: error[E0100]: column zero (SYN-001)
    |}]

(* spec: TOOL-041 — security diagnostics state the risk; fixes are rendered as edits. *)
let%expect_test "security diagnostic with a replacement fix" =
  let src = "    sys.run(Cmd(\"ping \" + h))\n" in
  render [ ("t.egd", src) ]
    (D.error ~rule:"SEC-017" ~code:"E0410"
       ~fixes:[ D.fix "use the cmd template" [ D.edit (sp 1 13 1 29) "cmd\"ping {h}\"" ] ]
       (sp 1 13 1 29) "`Cmd` cannot be built from `str` — risk: command injection. Use the `cmd\"…\"` template");
  [%expect
    {|
    t.egd:1:13: error[E0410]: `Cmd` cannot be built from `str` — risk: command injection. Use the `cmd"…"` template (SEC-017)
      |
    1 |     sys.run(Cmd("ping " + h))
      |             ^^^^^^^^^^^^^^^^
      help: use the cmd template
        t.egd:1:13-1:29: replace with "cmd\"ping {h}\""
    |}]
