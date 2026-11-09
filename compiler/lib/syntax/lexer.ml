open Tokens
module D = Egide_diagnostics.Diagnostic

type located = { tok : Tokens.token; startp : Lexing.position; endp : Lexing.position }

let ident_start = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_']
let ident_char = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9']
let digit = [%sedlex.regexp? '0' .. '9']
let hex = [%sedlex.regexp? '0' .. '9' | 'a' .. 'f' | 'A' .. 'F']
let dec_int = [%sedlex.regexp? digit, Star (digit | '_')]
let exponent = [%sedlex.regexp? ('e' | 'E'), Opt ('+' | '-'), Plus digit]

type state = { buf : Sedlexing.lexbuf; sink : D.Sink.t }

let span st = let s, e = Sedlexing.lexing_positions st.buf in Egide_source.Span.of_lexing s e
let report st ~rule ~code msg = D.Sink.report st.sink (D.error ~rule ~code (span st) msg)

(* LEX-004: one diagnostic per run of tabs, spanning the run. *)
let report_tab st =
  report st ~rule:"LEX-004" ~code:"E0005" "tab character outside a string literal; indent with 4 spaces"

let ret st tok =
  let startp, _ = Sedlexing.lexing_positions st.buf in
  Some (tok, startp)

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
  | "0x", Plus (hex | '_') | "0o", Plus ('0' .. '7' | '_') | "0b", Plus ('0' | '1' | '_') ->
      ret st (INT (Sedlexing.Utf8.lexeme buf))
  | dec_int, '.', Plus digit, Opt exponent | dec_int, exponent -> ret st (FLOAT (Sedlexing.Utf8.lexeme buf))
  | dec_int -> ret st (INT (Sedlexing.Utf8.lexeme buf))
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
      report st ~rule:"LEX-061" ~code:"E0050" "`;` is not used in Égide; statements end at line breaks";
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
  | "\\\\" -> Buffer.add_char acc '\\'; string st acc
  | "\\\"" -> Buffer.add_char acc '"'; string st acc
  | "\\n" -> Buffer.add_char acc '\n'; string st acc
  | "\\t" -> Buffer.add_char acc '\t'; string st acc
  | "\\r" -> Buffer.add_char acc '\r'; string st acc
  | "\\0" -> Buffer.add_char acc '\000'; string st acc
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
