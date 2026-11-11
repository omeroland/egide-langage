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

type state = { buf : Sedlexing.lexbuf; sink : D.Sink.t }

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

let rec token st =
  let buf = st.buf in
  match%sedlex buf with
  | ' ' -> token st
  | '\n' | "\r\n" -> token st (* sedlex tracks line numbers itself *)
  | '\r' -> token st (* lone CR: reported by Source_check (E0003) *)
  | Plus '\t' ->
      report_tab st;
      token st
  | '#' ->
      comment st;
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
  | '"' ->
      let startp, _ = Sedlexing.lexing_positions buf in
      Some (string st (Buffer.create 16), startp)
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

(* LEX-050 (seed subset): plain strings with the escapes backslash, quote, n, t, r and 0. *)
and string st acc =
  let buf = st.buf in
  match%sedlex buf with
  | '"' -> STRING (Buffer.contents acc)
  | "\\\\" ->
      Buffer.add_char acc '\\';
      string st acc
  | "\\\"" ->
      Buffer.add_char acc '"';
      string st acc
  | "\\n" ->
      Buffer.add_char acc '\n';
      string st acc
  | "\\t" ->
      Buffer.add_char acc '\t';
      string st acc
  | "\\r" ->
      Buffer.add_char acc '\r';
      string st acc
  | "\\0" ->
      Buffer.add_char acc '\000';
      string st acc
  | '\\', any ->
      report st ~rule:"LEX-050" ~code:"E0041"
        (Printf.sprintf "invalid escape sequence `%s`" (Sedlexing.Utf8.lexeme buf));
      string st acc
  | '\n' ->
      report st ~rule:"LEX-050" ~code:"E0040" "unterminated string literal";
      STRING (Buffer.contents acc)
  | eof ->
      report st ~rule:"LEX-050" ~code:"E0040" "unterminated string literal";
      STRING (Buffer.contents acc)
  | any ->
      Buffer.add_string acc (Sedlexing.Utf8.lexeme buf);
      string st acc
  | _ -> STRING (Buffer.contents acc)

let tokenize ~file src =
  let pre = Source_check.check ~file src in
  if List.exists (fun (d : D.t) -> d.code = "E0001") pre then ([], pre)
  else begin
    let buf = Sedlexing.Utf8.from_string src in
    Sedlexing.set_filename buf file;
    let st = { buf; sink = D.Sink.create () } in
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
