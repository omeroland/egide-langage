module D = Egide_diagnostics.Diagnostic

let token_to_string = Token_table.to_string

let tokens ~file src =
  let raw, d1 = Lexer.tokenize ~file src in
  let toks, d2 = Layout.run raw in
  (toks, d1 @ d2)

let file ~file src =
  let toks, diags = tokens ~file src in
  let remaining = ref toks in
  let last = ref None in
  let next () =
    match !remaining with
    | [] -> (Tokens.EOF, Lexing.dummy_pos, Lexing.dummy_pos)
    | (t : Lexer.located) :: rest ->
        remaining := rest;
        last := Some t;
        (t.tok, t.startp, t.endp)
  in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Parser.file in
  match parser next with
  | ast -> (Some ast, diags)
  | exception Parser.Error ->
      let sp =
        match !last with
        | Some t -> Egide_source.Span.of_lexing t.startp t.endp
        | None -> Egide_source.Span.dummy
      in
      let found = match !last with Some t -> token_to_string t.tok | None -> "end of file" in
      let d = D.error ~rule:"SYN-001" ~code:"E0100" sp (Printf.sprintf "syntax error: unexpected %s" found) in
      (None, diags @ [ d ])
