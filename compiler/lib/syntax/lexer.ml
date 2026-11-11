open Tokens
module D = Egide_diagnostics.Diagnostic

type located = { tok : Tokens.token; startp : Lexing.position; endp : Lexing.position }

let ident_start = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_']
let ident_char = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9']
let digit = [%sedlex.regexp? '0' .. '9']

(* Numeric literals (LEX-040..042). Sedlex only gives longest-match, with no look-ahead, so the lexer matches a
   generous "word" (a digit followed by any identifier characters, so that `5ms`, `0X1F`, `12abc` are one
   candidate) and [classify_number] validates it by hand, reporting at most one diagnostic per literal. *)
let dec_digits = [%sedlex.regexp? digit, Star (digit | '_')]
let num_word = [%sedlex.regexp? digit, Star ident_char]

(* `1.5`, `1_0.5e3`, `1.5ms`: a dot is part of a number only when a digit follows it (LEX-041). *)
let num_fraction = [%sedlex.regexp? dec_digits, '.', digit, Star ident_char]

(* The sign of an exponent is not an identifier character: `1e+9`, `2.5e-3`, `1E+9` (the last is E0031). *)
let num_signed_exp =
  [%sedlex.regexp?
    ( dec_digits,
      Opt ('.', digit, Star (digit | '_')),
      ('e' | 'E'),
      ('+' | '-'),
      digit,
      Star ident_char )]

(* A decimal integer, a dot and an identifier: a duration (LEX-042) or `INT . IDENT`; decided by [token]. *)
let num_dot_word = [%sedlex.regexp? dec_digits, '.', ident_start, Star ident_char]

(* [src] is the whole input and [bc]/[bb] a cache of the byte offset of character [bc]: a triple-quoted template
   needs the source text of its interpolations (see [byte_of_cnum]). [tdepth] counts the templates being read
   (LEX-055: at most 8). [idepth] counts the interpolations being read (a `#` there is E0044); [stop_nl] says that
   a line break ends the interpolation being read (a single-line template); [hit_nl] records that it did. *)
(* LEX-055: a `lower_snake_case` identifier directly followed by a quote. *)
let tpl_prefix = [%sedlex.regexp? 'a' .. 'z', Star ('a' .. 'z' | '0' .. '9' | '_')]

type state = {
  buf : Sedlexing.lexbuf;
  sink : D.Sink.t;
  src : string;
  mutable bc : int;
  mutable bb : int;
  mutable tdepth : int;
  mutable too_deep : bool;
  mutable idepth : int;
  mutable stop_nl : bool;
  mutable hit_nl : bool;
}

let span st =
  let s, e = Sedlexing.lexing_positions st.buf in
  Egide_source.Span.of_lexing s e

let report st ~rule ~code msg = D.Sink.report st.sink (D.error ~rule ~code (span st) msg)

(* LEX-004: one diagnostic per run of tabs, spanning the run. *)
let report_tab st =
  report st ~rule:"LEX-004" ~code:"E0005"
    "tab character outside a string literal; indent with 4 spaces"

let ret st tok =
  let startp, _ = Sedlexing.lexing_positions st.buf in
  Some (tok, startp)

let duration_units = [ "ns"; "us"; "ms"; "s"; "min"; "h" ]

type number_kind = Integer | Real

(* A malformed numeric literal: the kind (E0030 for integers, E0031 for floats), a message and notes. *)
type number_error = number_kind * string * string list

let is_digit c = c >= '0' && c <= '9'

(* LEX-040: a digit group (the digits between a prefix, a dot, an exponent sign and the next boundary) may not
   start or end with `_`, nor contain `__`. [g] is non-empty. *)
let check_group kind g : number_error option =
  let contains_double =
    let r = ref false in
    String.iteri (fun i c -> if c = '_' && i > 0 && g.[i - 1] = '_' then r := true) g;
    !r
  in
  if g.[0] = '_' then Some (kind, "a digit group may not start with `_`", [])
  else if contains_double then Some (kind, "`_` may not be doubled in a numeric literal", [])
  else if g.[String.length g - 1] = '_' then Some (kind, "a digit group may not end with `_`", [])
  else None

let prefixed_radix s =
  if String.length s >= 2 && s.[0] = '0' then
    match s.[1] with
    | 'x' ->
        Some
          ("a hexadecimal", fun c -> is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
    | 'o' -> Some ("an octal", fun c -> c >= '0' && c <= '7')
    | 'b' -> Some ("a binary", fun c -> c = '0' || c = '1')
    | _ -> None
  else None

(* The index of the first character of [s] at or after [i] that does not satisfy [p], or [String.length s]. *)
let span_while p s i =
  let n = String.length s in
  let rec go j = if j < n && p s.[j] then go (j + 1) else j in
  go i

let first_error l = List.find_map (fun x -> x) l

(* LEX-040 and LEX-041: validates the text of a numeric-literal candidate and says whether it is an integer or a
   float. The text starts with a digit and contains only identifier characters, one `.` and an exponent sign. *)
let classify_number s : (number_kind, number_error) result =
  match prefixed_radix s with
  | Some (name, valid) -> (
      let digits = String.sub s 2 (String.length s - 2) in
      let bad = span_while (fun c -> valid c || c = '_') digits 0 in
      let err m = Error (Integer, m, []) in
      if digits = "" then err (Printf.sprintf "`%s` must be followed by digits" (String.sub s 0 2))
      else if bad < String.length digits then
        err (Printf.sprintf "`%c` is not a valid digit of %s literal" digits.[bad] name)
      else match check_group Integer digits with Some e -> Error e | None -> Ok Integer)
  | None -> (
      let n = String.length s in
      let int_end = span_while (fun c -> is_digit c || c = '_') s 0 in
      let int_part = String.sub s 0 int_end in
      let frac_end =
        if int_end < n && s.[int_end] = '.' then
          span_while (fun c -> is_digit c || c = '_') s (int_end + 1)
        else int_end
      in
      let frac =
        if frac_end > int_end then Some (String.sub s (int_end + 1) (frac_end - int_end - 1))
        else None
      in
      (* An exponent: `e` or `E`, an optional sign, digits. With no digit after the letter, the letter is a
         "number followed by an identifier" unless the word ends there (`1e`: an exponent without digits). *)
      let exp =
        if frac_end < n && (s.[frac_end] = 'e' || s.[frac_end] = 'E') then begin
          let sign =
            if frac_end + 1 < n && (s.[frac_end + 1] = '+' || s.[frac_end + 1] = '-') then 1 else 0
          in
          let d0 = frac_end + 1 + sign in
          let d1 = span_while (fun c -> is_digit c || c = '_') s d0 in
          if d1 > d0 || d0 = n then Some (s.[frac_end], String.sub s d0 (d1 - d0), d1) else None
        end
        else None
      in
      let rest_start = match exp with Some (_, _, e) -> e | None -> frac_end in
      let kind = if frac <> None || exp <> None then Real else Integer in
      let rest = String.sub s rest_start (n - rest_start) in
      let checks =
        [
          (* LEX-040: no leading zero; the hint applies to integers only *)
          (if String.length int_part > 1 && int_part.[0] = '0' then
             let tail = String.sub int_part 1 (String.length int_part - 1) in
             let octal = tail <> "" && String.for_all (fun c -> c >= '0' && c <= '7') tail in
             Some
               ( kind,
                 Printf.sprintf "leading zero in `%s`" int_part,
                 if kind = Integer && octal then [ Printf.sprintf "write 0o%s for octal" tail ]
                 else [] )
           else None);
          check_group kind int_part;
          Option.bind frac (fun g -> if g = "" then None else check_group kind g);
          (match exp with
          | Some ('E', _, _) -> Some (Real, "the exponent letter must be lowercase `e`", [])
          | Some (_, "", _) -> Some (Real, "the exponent has no digits", [])
          | Some (_, g, _) -> check_group Real g
          | None -> None);
          (if rest = "" then None
           else
             Some
               ( kind,
                 Printf.sprintf "`%s` directly follows the numeric literal `%s`" rest
                   (String.sub s 0 rest_start),
                 if int_part = "0" && frac = None && exp = None && String.contains "XOB" rest.[0]
                 then [ "integer prefixes are lowercase: 0x, 0o, 0b" ]
                 else [] ));
        ]
      in
      match first_error checks with Some e -> Error e | None -> Ok kind)

let report_number st ((kind, msg, notes) : number_error) =
  let rule, code =
    match kind with Integer -> ("LEX-040", "E0030") | Real -> ("LEX-041", "E0031")
  in
  D.Sink.report st.sink (D.error ~rule ~code ~notes (span st) msg)

(* One diagnostic per malformed literal; the token is still produced so that the parser can go on. *)
let number st lexeme =
  match classify_number lexeme with
  | Ok Integer -> ret st (INT lexeme)
  | Ok Real -> ret st (FLOAT lexeme)
  | Error ((kind, _, _) as e) ->
      report_number st e;
      ret st (match kind with Integer -> INT lexeme | Real -> FLOAT lexeme)

(* ---- String, byte-string and character literals (LEX-050..054) ----
   A literal is read in two steps. First a scanner collects the raw text between the delimiters, deciding only where
   the literal ends (a backslash protects `\\` and the quote of a cooked literal; a raw literal has no protection).
   Then [decode_escapes] turns the raw text into the value and reports every bad escape with its own span. LEX-003
   (forbidden characters, also inside literals) is checked on the raw input by [Source_check] before any token is
   read, so an escape such as `\u{202E}` is the only way a forbidden code point reaches a value (LEX-050, ADR-0017). *)

module Esc = Egide_diagnostics.Escape
module Span = Egide_source.Span

type literal_kind = Cooked | Chr | Byt

(* All text of one literal body is single-line (a triple-quoted body is split into lines first), so the scalar value
   at index [j] of a chunk that starts at [p] is at column [p.col + j]. *)

let pos_at (p : Lexing.position) j = { p with Lexing.pos_cnum = p.Lexing.pos_cnum + j }

let report_range st ~rule ~code p0 p1 msg =
  D.Sink.report st.sink (D.error ~rule ~code (Span.of_lexing p0 p1) msg)

let hex_value c =
  match c with
  | '0' .. '9' -> Some (Char.code c - 48)
  | 'a' .. 'f' -> Some (Char.code c - 87)
  | 'A' .. 'F' -> Some (Char.code c - 55)
  | _ -> None

let byte_string_escapes = "`\\\\ \\\" \\n \\t \\r \\0 \\xHH`"

(* Applies the escapes of [s] (LEX-050, LEX-053, LEX-054) and appends the value to [out] (UTF-8 for [Cooked] and
   [Chr], bytes for [Byt]). [p] is the position of the first scalar of [s]. Every bad escape is one diagnostic on
   the escape itself (E0041, or E0043 for a byte string); it is skipped and decoding goes on. Returns the number
   of bad escapes and bad characters. *)
let decode_escapes st kind (p : Lexing.position) (s : string) (out : Buffer.t) : int =
  let n = String.length s in
  let errs = ref 0 in
  let fail ~rule ~code j0 j1 msg =
    incr errs;
    report_range st ~rule ~code (pos_at p j0) (pos_at p j1) msg
  in
  let bad_escape j j1 msg = fail ~rule:"LEX-050" ~code:"E0041" j j1 msg in
  let byte_escape_not_allowed j what =
    fail ~rule:"LEX-053" ~code:"E0043" j (j + 2)
      (Printf.sprintf "escape `\\%s` is not allowed in a byte string; the escapes are %s" what
         byte_string_escapes)
  in
  (* [i]: byte index, [j]: scalar index of the same position. *)
  let rec go i j =
    if i < n then begin
      let c = s.[i] in
      if c = '\\' then escape i j
      else if Char.code c < 0x80 then begin
        if kind = Byt && (c < ' ' || c > '~') then
          fail ~rule:"LEX-053" ~code:"E0043" j (j + 1)
            (Printf.sprintf
               "character U+%04X is not allowed in a byte string (printable ASCII U+0020 to U+007E \
                only)"
               (Char.code c))
        else begin
          if kind = Chr && c = '\t' then
            (* LEX-054: a raw tab is not allowed; not counted as an error, the value stays one scalar *)
            report_range st ~rule:"LEX-004" ~code:"E0005" (pos_at p j)
              (pos_at p (j + 1))
              "tab character in a character literal; write '\\t'";
          Buffer.add_char out c
        end;
        go (i + 1) (j + 1)
      end
      else begin
        let d = String.get_utf_8_uchar s i in
        let w = Uchar.utf_decode_length d in
        if kind = Byt then
          fail ~rule:"LEX-053" ~code:"E0043" j (j + 1)
            (Printf.sprintf
               "character U+%04X is not allowed in a byte string (printable ASCII U+0020 to U+007E \
                only)"
               (Uchar.to_int (Uchar.utf_decode_uchar d)))
        else Buffer.add_substring out s i w;
        go (i + w) (j + 1)
      end
    end
  and escape i j =
    if i + 1 >= n then begin
      bad_escape j (j + 1) "invalid escape sequence: a backslash at the end of the line";
      go (i + 1) (j + 1)
    end
    else begin
      let e = s.[i + 1] in
      let simple ch =
        Buffer.add_char out ch;
        go (i + 2) (j + 2)
      in
      match e with
      | '\\' -> simple '\\'
      | '"' -> simple '"'
      | 'n' -> simple '\n'
      | 't' -> simple '\t'
      | 'r' -> simple '\r'
      | '0' -> simple '\000'
      | '\'' when kind = Chr -> simple '\''
      | ('{' | '}') when kind = Cooked -> simple e
      | ('{' | '}' | 'u') when kind = Byt ->
          byte_escape_not_allowed j (String.make 1 e);
          go (i + 2) (j + 2)
      | 'u' when kind <> Byt -> unicode i j
      | 'x' when kind = Byt -> hex_byte i j
      | _ ->
          (* an unknown escape: the backslash and the whole scalar that follows, shown escaped (LEX-006) *)
          let w = Uchar.utf_decode_length (String.get_utf_8_uchar s (i + 1)) in
          bad_escape j (j + 2)
            (Printf.sprintf "invalid escape sequence `\\%s`" (Esc.display (String.sub s (i + 1) w)));
          go (i + 1 + w) (j + 2)
    end
  and hex_byte i j =
    (* `\xHH`: exactly two hexadecimal digits (LEX-053) *)
    let digit k = if i + k < n then hex_value s.[i + k] else None in
    match (digit 2, digit 3) with
    | Some a, Some b ->
        Buffer.add_char out (Char.chr ((a * 16) + b));
        go (i + 4) (j + 4)
    | d2, _ ->
        let used = if d2 = None then 2 else 3 in
        bad_escape j (j + used) "`\\x` must be followed by exactly two hexadecimal digits";
        go (i + used) (j + used)
  and unicode i j =
    (* `\u{H…}`: 1 to 6 hexadecimal digits, a Unicode scalar value (LEX-050). Everything consumed is ASCII, so
       bytes and scalars advance together. *)
    if i + 2 >= n || s.[i + 2] <> '{' then begin
      bad_escape j (j + 2) "`\\u` must be followed by `{`, 1 to 6 hexadecimal digits and `}`";
      go (i + 2) (j + 2)
    end
    else begin
      let rec digits m acc cnt =
        match if m < n then hex_value s.[m] else None with
        | Some v -> digits (m + 1) (if cnt < 7 then (acc * 16) + v else acc) (cnt + 1)
        | None -> (m, acc, cnt)
      in
      let m, v, cnt = digits (i + 3) 0 0 in
      let closed = m < n && s.[m] = '}' in
      let stop = if closed then m + 1 else m in
      let len = stop - i in
      let err msg =
        bad_escape j (j + len) msg;
        go stop (j + len)
      in
      if not closed then err "missing `}` after the hexadecimal digits of `\\u{`"
      else if cnt = 0 then err "`\\u{}` needs 1 to 6 hexadecimal digits"
      else if cnt > 6 then err "`\\u{...}` takes at most 6 hexadecimal digits"
      else if v > 0x10FFFF then
        err (Printf.sprintf "U+%X is above U+10FFFF, so it is not a Unicode scalar value" v)
      else if v >= 0xD800 && v <= 0xDFFF then
        err (Printf.sprintf "U+%X is a surrogate, so it is not a Unicode scalar value" v)
      else begin
        Buffer.add_utf_8_uchar out (Uchar.of_int v);
        go stop (j + len)
      end
    end
  in
  go 0 0;
  !errs

(* E0040, pointing at the opening quote(s): [delim] columns ending at [opened]. *)
let unterminated st ~rule ~what opened delim =
  report_range st ~rule ~code:"E0040" (pos_at opened (-delim)) opened
    (Printf.sprintf "unterminated %s" what)

(* Scanners. Each returns [true] when it consumed the closing delimiter. At a line break or the end of the input it
   returns [false]; the line break is given back (LEX-050: a raw LF inside `"…"` is an error), so the next token
   starts on the following line and one bad literal costs one diagnostic. A lone CR is E0003 (Source_check) and is
   kept in the text, as before. *)
let rec scan_dq st raw =
  let buf = st.buf in
  match%sedlex buf with
  | '"' -> true
  | "\\\\" | "\\\"" ->
      Buffer.add_string raw (Sedlexing.Utf8.lexeme st.buf);
      scan_dq st raw
  | '\\' ->
      Buffer.add_char raw '\\';
      scan_dq st raw
  | '\n' | "\r\n" ->
      Sedlexing.rollback st.buf;
      false
  | '\r' ->
      Buffer.add_char raw '\r';
      scan_dq st raw
  | Plus (Compl ('"' | '\\' | '\n' | '\r')) ->
      Buffer.add_string raw (Sedlexing.Utf8.lexeme st.buf);
      scan_dq st raw
  | _ -> false (* end of input *)

let rec scan_raw_dq st raw =
  let buf = st.buf in
  match%sedlex buf with
  | '"' -> true
  | '\n' | "\r\n" ->
      Sedlexing.rollback st.buf;
      false
  | '\r' ->
      Buffer.add_char raw '\r';
      scan_raw_dq st raw
  | Plus (Compl ('"' | '\n' | '\r')) ->
      Buffer.add_string raw (Sedlexing.Utf8.lexeme st.buf);
      scan_raw_dq st raw
  | _ -> false

let rec scan_sq st raw =
  let buf = st.buf in
  match%sedlex buf with
  | '\'' -> true
  | "\\\\" | "\\'" ->
      Buffer.add_string raw (Sedlexing.Utf8.lexeme st.buf);
      scan_sq st raw
  | '\\' ->
      Buffer.add_char raw '\\';
      scan_sq st raw
  | '\n' | "\r\n" ->
      Sedlexing.rollback st.buf;
      false
  | '\r' ->
      Buffer.add_char raw '\r';
      scan_sq st raw
  | Plus (Compl ('\'' | '\\' | '\n' | '\r')) ->
      Buffer.add_string raw (Sedlexing.Utf8.lexeme st.buf);
      scan_sq st raw
  | _ -> false

(* The raw text of a triple-quoted literal: one buffer for all lines and two int arrays (16 bytes per line, no
   allocation per line: a literal of millions of lines stays linear with a small constant). Line [k] starts at byte
   [starts.(k)] of [text] and at character offset [cnums.(k)] of the file; the first line starts at the position after
   the opening quotes, the others at column 1. CR LF is normalised to LF (LEX-002). *)
type triple = {
  text : Buffer.t;
  mutable starts : int array;
  mutable cnums : int array;
  mutable n : int;
}

let new_line t (p : Lexing.position) =
  if t.n = Array.length t.starts then begin
    let grow a = Array.append a (Array.make (Array.length a) 0) in
    t.starts <- grow t.starts;
    t.cnums <- grow t.cnums
  end;
  t.starts.(t.n) <- Buffer.length t.text;
  t.cnums.(t.n) <- p.Lexing.pos_cnum;
  t.n <- t.n + 1

let rec scan_triple_cooked st t =
  let buf = st.buf in
  match%sedlex buf with
  | "\"\"\"" -> true
  | "\\\\" | "\\\"" ->
      Buffer.add_string t.text (Sedlexing.Utf8.lexeme st.buf);
      scan_triple_cooked st t
  | '\\' ->
      Buffer.add_char t.text '\\';
      scan_triple_cooked st t
  | '\n' | "\r\n" ->
      new_line t (snd (Sedlexing.lexing_positions st.buf));
      scan_triple_cooked st t
  | '\r' ->
      Buffer.add_char t.text '\r';
      scan_triple_cooked st t
  | Plus (Compl ('"' | '\\' | '\n' | '\r')) ->
      Buffer.add_string t.text (Sedlexing.Utf8.lexeme st.buf);
      scan_triple_cooked st t
  | '"' ->
      Buffer.add_char t.text '"';
      scan_triple_cooked st t
  | _ -> false

let rec scan_triple_raw st t =
  let buf = st.buf in
  match%sedlex buf with
  | "\"\"\"" -> true
  | '\n' | "\r\n" ->
      new_line t (snd (Sedlexing.lexing_positions st.buf));
      scan_triple_raw st t
  | '\r' ->
      Buffer.add_char t.text '\r';
      scan_triple_raw st t
  | Plus (Compl ('"' | '\n' | '\r')) ->
      Buffer.add_string t.text (Sedlexing.Utf8.lexeme st.buf);
      scan_triple_raw st t
  | '"' ->
      Buffer.add_char t.text '"';
      scan_triple_raw st t
  | _ -> false

(* Number of leading spaces and tabs of the byte range [i, j) of [s]. *)
let leading_ws s i j =
  let rec go k = if k < j && (s.[k] = ' ' || s.[k] = '\t') then go (k + 1) else k - i in
  go i

(* LEX-051. The dedent of Python's [textwrap.dedent], on the raw lines (before escapes are read):
   1. the line break right after the opening quotes is dropped (only when it directly follows them);
   2. the margin is the fewest leading whitespace characters among the lines that are not blank (blank = only
      spaces and tabs);
   3. a tab inside the margin, or on a blank line, is E0005 (LEX-004), one diagnostic per run of tabs; a tab beyond
      the margin is text;
   4. blank lines become empty, the others lose the margin. The line break before the closing quotes stays: the
      last line is the (blank) text before them. *)
(* The common part of [triple_value] and of a triple-quoted template: the first line to keep and the margin, with the
   tab diagnostics of step 3. *)
let triple_margin st (opened : Lexing.position) t =
  let all = Buffer.contents t.text in
  let n = t.n in
  let start k = t.starts.(k) in
  let stop k = if k + 1 < n then t.starts.(k + 1) else String.length all in
  let pos k =
    if k = 0 then opened
    else
      let c = t.cnums.(k) in
      { opened with Lexing.pos_lnum = opened.Lexing.pos_lnum + k; pos_bol = c; pos_cnum = c }
  in
  let lead k = leading_ws all (start k) (stop k) in
  let blank k = lead k = stop k - start k in
  let first = if n > 1 && stop 0 = start 0 then 1 else 0 in
  let margin = ref max_int in
  for k = first to n - 1 do
    if not (blank k) then margin := min !margin (lead k)
  done;
  let margin = !margin in
  for k = first to n - 1 do
    let l = lead k in
    let limit = if blank k then l else min l margin in
    let i = ref 0 in
    while !i < limit do
      if all.[start k + !i] = '\t' then begin
        let j = ref !i in
        while !j < limit && all.[start k + !j] = '\t' do
          incr j
        done;
        report_range st ~rule:"LEX-004" ~code:"E0005"
          (pos_at (pos k) !i)
          (pos_at (pos k) !j)
          "tab character in the margin of a triple-quoted string; indent with spaces";
        i := !j
      end
      else incr i
    done
  done;
  (all, start, stop, pos, blank, first, margin)

let triple_value st (opened : Lexing.position) ~cooked t out =
  let all, start, stop, pos, blank, first, margin = triple_margin st opened t in
  let n = t.n in
  for k = first to n - 1 do
    if k > first then Buffer.add_char out '\n';
    if not (blank k) then begin
      let len = stop k - start k - margin in
      if cooked then
        ignore
          (decode_escapes st Cooked
             (pos_at (pos k) margin)
             (String.sub all (start k + margin) len)
             out)
      else Buffer.add_substring out all (start k + margin) len
    end
  done

(* Each reader is called right after its opening delimiter was matched. *)
let single_line_string st ~kind ~scan =
  let _, opened = Sedlexing.lexing_positions st.buf in
  let raw = Buffer.create 32 in
  let closed = scan st raw in
  if not closed then unterminated st ~rule:"LEX-050" ~what:"string literal" opened 1;
  match kind with
  | None -> Buffer.contents raw
  | Some k ->
      let out = Buffer.create (Buffer.length raw) in
      ignore (decode_escapes st k opened (Buffer.contents raw) out);
      Buffer.contents out

let triple_string st ~cooked =
  let _, opened = Sedlexing.lexing_positions st.buf in
  let t = { text = Buffer.create 64; starts = Array.make 16 0; cnums = Array.make 16 0; n = 0 } in
  new_line t opened;
  let closed = if cooked then scan_triple_cooked st t else scan_triple_raw st t in
  if not closed then unterminated st ~rule:"LEX-050" ~what:"string literal" opened 3;
  let out = Buffer.create (Buffer.length t.text) in
  triple_value st opened ~cooked t out;
  Buffer.contents out

let replacement = Uchar.of_int 0xFFFD

(* LEX-054. A literal with a bad escape or no closing quote is E0041 / E0040 only, so that one mistake costs one
   diagnostic; its value is U+FFFD. *)
let char_literal st =
  let _, opened = Sedlexing.lexing_positions st.buf in
  let raw = Buffer.create 8 in
  if not (scan_sq st raw) then begin
    unterminated st ~rule:"LEX-054" ~what:"character literal" opened 1;
    replacement
  end
  else begin
    let _, closing = Sedlexing.lexing_positions st.buf in
    let out = Buffer.create 8 in
    let errs = decode_escapes st Chr opened (Buffer.contents raw) out in
    let value = Buffer.contents out in
    let count =
      let rec go i k =
        if i >= String.length value then k
        else go (i + Uchar.utf_decode_length (String.get_utf_8_uchar value i)) (k + 1)
      in
      go 0 0
    in
    if errs > 0 then replacement
    else if count <> 1 then begin
      report_range st ~rule:"LEX-054" ~code:"E0042" (pos_at opened (-1)) closing
        (Printf.sprintf "character literal must contain exactly one character, found %d" count);
      replacement
    end
    else Uchar.utf_decode_uchar (String.get_utf_8_uchar value 0)
  end

(* ---- Prefixed templates (LEX-055) ---- *)

let max_template_depth = 8

(* The byte offset of character [c] of the input. Characters are counted as sedlex counts them (one per scalar value);
   the input is valid UTF-8 here (E0001 stops the lexer before). Walking from the last answer keeps a sequence of
   queries linear. *)
let byte_of_cnum st c =
  while st.bc < c && st.bb < String.length st.src do
    st.bb <- st.bb + Uchar.utf_decode_length (String.get_utf_8_uchar st.src st.bb);
    st.bc <- st.bc + 1
  done;
  (* an outer interpolation asks for a position before the inner ones: walk back, at the cost of the distance *)
  while st.bc > c do
    st.bb <- st.bb - 1;
    while st.bb > 0 && Char.code st.src.[st.bb] land 0xC0 = 0x80 do
      st.bb <- st.bb - 1
    done;
    st.bc <- st.bc - 1
  done;
  st.bb

(* LEX-055, reading left to right: a backslash keeps the next character as it is, then `{{` and `}}` stand for one
   brace. A lone `}` was reported by the scanner and is kept. *)
let collapse_braces s =
  let n = String.length s in
  let b = Buffer.create n in
  let rec go i =
    if i < n then
      match s.[i] with
      | '\\' when i + 1 < n ->
          Buffer.add_char b '\\';
          Buffer.add_char b s.[i + 1];
          go (i + 2)
      | '{' when i + 1 < n && s.[i + 1] = '{' ->
          Buffer.add_char b '{';
          go (i + 2)
      | '}' when i + 1 < n && s.[i + 1] = '}' ->
          Buffer.add_char b '}';
          go (i + 2)
      | c ->
          Buffer.add_char b c;
          go (i + 1)
  in
  go 0;
  Buffer.contents b

(* What the scanner collects: ranges of [t.text] that are literal text, and interpolations (with their range, which
   holds their source text so that the margin of a triple-quoted template sees their lines too). *)
type titem = TLit of int * int | TInterp of int * int * Tokens.part

(* Appends the source text [s] of an interpolation to [t.text], line by line; [p] is the position of its first
   character. *)
let add_interp_text t (p : Lexing.position) s =
  let cp = ref 0 in
  String.iter
    (fun c ->
      if c = '\n' then begin
        incr cp;
        new_line t { p with Lexing.pos_cnum = p.Lexing.pos_cnum + !cp }
      end
      else begin
        if Char.code c land 0xC0 <> 0x80 then incr cp;
        if c <> '\r' then Buffer.add_char t.text c
      end)
    s

(* LEX-051 applied to a template: the margin is computed on all the lines of the raw text (interpolations included),
   then removed from the lines that start in literal text; the line breaks that lie in literal text come back as LF.
   [lit a b] is the dedented text of the literal range [a, b). *)
let triple_literals st opened t =
  let _, start, stop, _, blank, first, margin = triple_margin st opened t in
  let all = Buffer.contents t.text in
  fun a b ->
    let out = Buffer.create (b - a) in
    for k = first to t.n - 1 do
      let s = start k and e = stop k in
      (* the line break before line [k] sits at offset [s]: it is literal text when [s] is in [a, b] *)
      if k > first && s >= a && s <= b then Buffer.add_char out '\n';
      let lo = max a s and hi = min b e in
      if lo < hi then begin
        let lo = if lo = s then if blank k then hi else min hi (lo + margin) else lo in
        if lo < hi then Buffer.add_substring out all lo (hi - lo)
      end
    done;
    Buffer.contents out

let rec token st =
  let buf = st.buf in
  match%sedlex buf with
  | ' ' -> token st
  | '\n' | "\r\n" ->
      if st.stop_nl then begin
        (* inside the interpolation of a single-line template (LEX-055): give the line break back *)
        Sedlexing.rollback buf;
        st.hit_nl <- true;
        None
      end
      else token st (* sedlex tracks line numbers itself *)
  | '\r' -> token st (* lone CR: reported by Source_check (E0003) *)
  | Plus '\t' ->
      report_tab st;
      token st
  | '#' ->
      if st.idepth > 0 then
        (* LEX-055: there are no comments inside `{...}`, so that a comment can never hide a `}` *)
        report st ~rule:"LEX-055" ~code:"E0044" "a `#` is not allowed inside an interpolation"
      else comment st;
      token st
  | ident_start, Star ident_char -> (
      let s = Sedlexing.Utf8.lexeme buf in
      match Token_table.keyword s with Some kw -> ret st kw | None -> ret st (IDENT s))
  | num_signed_exp | num_fraction | num_word -> number st (Sedlexing.Utf8.lexeme buf)
  | num_dot_word ->
      (* LEX-042: [5.ms] is one DURATION token only if the unit is a whole identifier. Otherwise the dot is a
         separate token ([5.msg] is [INT . IDENT]): give the lexeme back and re-match the integer alone. *)
      let lexeme = Sedlexing.Utf8.lexeme buf in
      let dot = String.index lexeme '.' in
      let amount = String.sub lexeme 0 dot in
      let unit = String.sub lexeme (dot + 1) (String.length lexeme - dot - 1) in
      if List.mem unit duration_units then (
        (match classify_number amount with Ok _ -> () | Error e -> report_number st e);
        ret st (DURATION (amount, unit)))
      else begin
        Sedlexing.rollback buf;
        match%sedlex buf with dec_digits -> number st (Sedlexing.Utf8.lexeme buf) | _ -> None
      end
  | "r\"\"\"" ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (RAW_STRING (triple_string st ~cooked:false), startp)
  | "r\"" ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (RAW_STRING (single_line_string st ~kind:None ~scan:scan_raw_dq), startp)
  | "b\"\"\"" ->
      (* LEX-053 has no triple-quoted byte string (Q-0051.6): E0043 on the three quotes, the body is read as a
         triple-quoted string so that one mistake costs one diagnostic, and the value is kept as bytes. *)
      let startp, endp0 = Sedlexing.lexing_positions buf in
      report_range st ~rule:"LEX-053" ~code:"E0043" (pos_at endp0 (-3)) endp0
        "a byte string has no triple-quoted form; use b\"...\" with escapes";
      Some (BYTES (triple_string st ~cooked:true), startp)
  | "b\"" ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (BYTES (single_line_string st ~kind:(Some Byt) ~scan:scan_dq), startp)
  | tpl_prefix, "\"\"\"" -> template st ~triple:true
  | tpl_prefix, '"' -> template st ~triple:false
  | "\"\"\"" ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (STRING (triple_string st ~cooked:true), startp)
  | '"' ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (STRING (single_line_string st ~kind:(Some Cooked) ~scan:scan_dq), startp)
  | '\'' ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (CHAR (char_literal st), startp)
  | "**" -> ret st STARSTAR
  | "==" -> ret st EQEQ
  | "!=" -> ret st NEQ
  | "<=" -> ret st LE
  | ">=" -> ret st GE
  | "+=" -> ret st PLUSEQ
  | "-=" -> ret st MINUSEQ
  | "*=" -> ret st STAREQ
  | "/=" -> ret st SLASHEQ
  | "%=" -> ret st PERCENTEQ
  | "&=" -> ret st AMPEQ
  | "|=" -> ret st PIPEEQ
  | "^=" -> ret st CARETEQ
  | "<<=" -> ret st SHLEQ
  | ">>=" -> ret st SHREQ
  | "<<" -> ret st SHL
  | ">>" -> ret st SHR
  | "->" -> ret st ARROW
  | "=>" -> ret st FATARROW
  | "|>" -> ret st PIPEGT
  | "..=" -> ret st DOTDOTEQ
  | ".." -> ret st DOTDOT
  | '+' -> ret st PLUS
  | '-' -> ret st MINUS
  | '*' -> ret st STAR
  | '/' -> ret st SLASH
  | '%' -> ret st PERCENT
  | '<' -> ret st LT
  | '>' -> ret st GT
  | '=' -> ret st EQ
  | '&' -> ret st AMP
  | '|' -> ret st PIPE
  | '^' -> ret st CARET
  | '~' -> ret st TILDE
  | '?' -> ret st QUESTION
  | '.' -> ret st DOT
  | ',' -> ret st COMMA
  | ':' -> ret st COLON
  | '@' -> ret st AT
  | '(' -> ret st LPAREN
  | ')' -> ret st RPAREN
  | '[' -> ret st LBRACKET
  | ']' -> ret st RBRACKET
  | '{' -> ret st LBRACE
  | '}' -> ret st RBRACE
  | ';' ->
      report st ~rule:"LEX-061" ~code:"E0050"
        "`;` is not used in Égide; statements end at line breaks";
      token st
  | eof -> None
  | any ->
      let cp = Uchar.to_int (Sedlexing.lexeme_char buf 0) in
      (* A forbidden code point or a byte-order mark was already reported by Source_check (E0004/E0002). *)
      if not (Source_check.is_forbidden cp) then
        report st ~rule:"LEX-060" ~code:"E0051"
          (Printf.sprintf "unexpected character `%s`" (Sedlexing.Utf8.lexeme buf));
      token st
  | _ -> None

(* LEX-010/011/012: a comment, doc comment or shebang runs to the end of the line (the LF is left to [token]).
   LEX-003/004: only string literals may contain HT, so a tab inside a comment is still E0005. *)
and comment st =
  let buf = st.buf in
  match%sedlex buf with
  | Plus (Compl ('\n' | '\t')) -> comment st
  | Plus '\t' ->
      report_tab st;
      comment st
  | _ -> () (* at LF or end of file: nothing matched, so nothing is consumed *)

(* LEX-055. Called right after the prefix and its opening quote(s). A keyword is never a prefix: `return"x"` is the keyword and
   a string, so the lexeme is given back and the identifier is read alone. *)
and template st ~triple =
  let buf = st.buf in
  let startp, opened = Sedlexing.lexing_positions buf in
  let lexeme = Sedlexing.Utf8.lexeme buf in
  let prefix = String.sub lexeme 0 (String.length lexeme - if triple then 3 else 1) in
  match Token_table.keyword prefix with
  | Some kw ->
      Sedlexing.rollback buf;
      (match%sedlex buf with ident_start, Star ident_char -> () | _ -> ());
      Some (kw, startp)
  | None ->
      let t =
        { text = Buffer.create 64; starts = Array.make 16 0; cnums = Array.make 16 0; n = 0 }
      in
      new_line t opened;
      let items = ref [] in
      let outcome =
        if st.tdepth >= max_template_depth then begin
          (* one diagnostic per outermost template, however deep it goes *)
          if not st.too_deep then
            report_range st ~rule:"LEX-055" ~code:"E0044" startp opened
              (Printf.sprintf "templates nest at most %d levels deep" max_template_depth);
          st.too_deep <- true;
          (* not read any further: the body is skipped as plain text, so that the depth stays bounded *)
          if triple then ignore (scan_triple_cooked st t)
          else ignore (scan_dq st (Buffer.create 16));
          `Reported
        end
        else begin
          st.tdepth <- st.tdepth + 1;
          let r = template_body st ~triple t items in
          st.tdepth <- st.tdepth - 1;
          if st.tdepth = 0 then st.too_deep <- false;
          r
        end
      in
      if outcome = `Unterminated then
        report_range st ~rule:"LEX-055" ~code:"E0040" startp opened "unterminated template literal";
      let lit =
        if triple then triple_literals st opened t else fun a b -> Buffer.sub t.text a (b - a)
      in
      let parts =
        List.filter_map
          (function
            | TInterp (_, _, part) -> Some part
            | TLit (a, b) ->
                let text = collapse_braces (lit a b) in
                if text = "" then None else Some (Tpl_lit text))
          (List.rev !items)
      in
      Some (TEMPLATE { prefix; parts }, startp)

(* Reads the body of a template up to its closing quote(s). [t.text] receives the raw text (an interpolation
   contributes its source text, a literal its text with `{{` and `}}` still doubled) and [items] the ranges. Returns
   [`Closed], [`Unterminated] (end of line or of input) or [`Reported] (an interpolation failed and said why). A
   backslash keeps the next character, so an escaped quote does not close the literal and an escaped brace does not
   open an interpolation. *)
and template_body st ~triple t items =
  let buf = st.buf in
  let lit_start = ref 0 in
  let add s = Buffer.add_string t.text s in
  let flush () =
    let a = Buffer.length t.text in
    (* in a triple-quoted template an empty range may still hold a line break between two interpolations *)
    if a > !lit_start || (triple && t.n > 1) then items := TLit (!lit_start, a) :: !items
  in
  let finish r =
    flush ();
    r
  in
  let rec go () =
    if triple then
      match%sedlex buf with
      | "\"\"\"" -> finish `Closed
      | '\n' | "\r\n" ->
          new_line t (snd (Sedlexing.lexing_positions buf));
          go ()
      | Plus (Compl ('"' | '\\' | '{' | '}' | '\n' | '\r'))
      | '"' | '\r'
      | "\\", Compl ('\n' | '\r')
      | '\\' | "{{" | "}}" ->
          add (Sedlexing.Utf8.lexeme buf);
          go ()
      | '{' -> opening ()
      | '}' -> lone_close ()
      | _ -> finish `Unterminated
    else
      match%sedlex buf with
      | '"' -> finish `Closed
      | '\n' | "\r\n" ->
          Sedlexing.rollback buf;
          finish `Unterminated
      | Plus (Compl ('"' | '\\' | '{' | '}' | '\n' | '\r'))
      | '\r'
      | "\\", Compl ('\n' | '\r')
      | '\\' | "{{" | "}}" ->
          add (Sedlexing.Utf8.lexeme buf);
          go ()
      | '{' -> opening ()
      | '}' -> lone_close ()
      | _ -> finish `Unterminated
  and opening () =
    flush ();
    let a = Buffer.length t.text in
    match interpolation st ~triple t with
    | Some part ->
        items := TInterp (a, Buffer.length t.text, part) :: !items;
        lit_start := Buffer.length t.text;
        go ()
    | None ->
        lit_start := Buffer.length t.text;
        finish `Reported
  and lone_close () =
    report st ~rule:"LEX-055" ~code:"E0044"
      "a `}` in template text must be doubled (`}}`) or close an interpolation";
    add "}";
    go ()
  in
  go ()

(* An interpolation `{expr[:spec]}`, called right after its `{`. The expression is read by [token], the lexer itself:
   it ends at the first `:` or `}` outside brackets, and strings, characters and nested templates are tokens, so they
   are tracked. [None] when the interpolation is unterminated (E0044, reported here). *)
and interpolation st ~triple t =
  let buf = st.buf in
  let open_s, _ = Sedlexing.lexing_positions buf in
  let idepth, stop_nl, hit_nl = (st.idepth, st.stop_nl, st.hit_nl) in
  st.idepth <- idepth + 1;
  st.stop_nl <- not triple;
  st.hit_nl <- false;
  let toks = ref [] and depth = ref 0 in
  let rec expr () =
    match token st with
    | None -> `Fail
    | Some (tok, s) -> (
        let _, e = Sedlexing.lexing_positions buf in
        match tok with
        | RBRACE when !depth = 0 -> `Close
        | COLON when !depth = 0 -> `Spec e
        | _ ->
            (match tok with
            | LPAREN | LBRACKET | LBRACE -> incr depth
            | RPAREN | RBRACKET | RBRACE -> if !depth > 0 then decr depth
            | _ -> ());
            toks := (tok, s, e) :: !toks;
            expr ())
  in
  let ended = expr () in
  let broke_on_newline = st.hit_nl in
  st.idepth <- idepth;
  st.stop_nl <- stop_nl;
  st.hit_nl <- hit_nl;
  let fail msg =
    report_range st ~rule:"LEX-055" ~code:"E0044" open_s (snd (Sedlexing.lexing_positions buf)) msg;
    None
  in
  (* the spec is raw text up to the closing brace: no brace, double quote or line break *)
  let read_spec spec_pos =
    let text = Buffer.create 8 in
    let rec go () =
      match%sedlex buf with
      | '}' -> Some { text = Buffer.contents text; spec_pos }
      | Plus (Compl ('}' | '{' | '"' | '\n' | '\r')) | '\r' ->
          Buffer.add_string text (Sedlexing.Utf8.lexeme buf);
          go ()
      | '{' | '"' ->
          report st ~rule:"LEX-055" ~code:"E0044"
            "a format specifier may not contain `{`, `}` or `\"`";
          go ()
      | _ -> None
    in
    go ()
  in
  let unterminated () =
    fail
      (if broke_on_newline then
         "a line break inside an interpolation is only allowed in a triple-quoted template"
       else "unterminated interpolation")
  in
  let finish spec =
    let _, close_e = Sedlexing.lexing_positions buf in
    if !toks = [] then
      report_range st ~rule:"LEX-055" ~code:"E0044" open_s close_e "empty interpolation";
    if triple then begin
      let b0 = byte_of_cnum st open_s.Lexing.pos_cnum
      and b1 = byte_of_cnum st close_e.Lexing.pos_cnum in
      add_interp_text t open_s (String.sub st.src b0 (b1 - b0))
    end;
    Some (Tpl_interp { open_pos = open_s; close_pos = close_e; toks = List.rev !toks; spec })
  in
  match ended with
  | `Fail -> unterminated ()
  | `Close -> finish None
  | `Spec spec_pos -> (
      match read_spec spec_pos with Some sp -> finish (Some sp) | None -> unterminated ())

let tokenize ~file src =
  let pre = Source_check.check ~file src in
  if List.exists (fun (d : D.t) -> d.code = "E0001") pre then ([], pre)
  else begin
    let buf = Sedlexing.Utf8.from_string src in
    Sedlexing.set_filename buf file;
    let st =
      {
        buf;
        sink = D.Sink.create ();
        src;
        bc = 0;
        bb = 0;
        tdepth = 0;
        too_deep = false;
        idepth = 0;
        stop_nl = false;
        hit_nl = false;
      }
    in
    let rec loop acc =
      match token st with
      | None -> List.rev acc
      | Some (tok, startp) ->
          let _, endp = Sedlexing.lexing_positions buf in
          loop ({ tok; startp; endp } :: acc)
    in
    let toks = loop [] in
    (toks, pre @ D.Sink.to_list st.sink)
  end
