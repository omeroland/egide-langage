open Tokens
module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let synth tok (p : Lexing.position) : Lexer.located = { tok; startp = p; endp = p }

let run (toks : Lexer.located list) =
  let diags = ref [] in
  let report ~rule ~code (t : Lexer.located) msg =
    diags := D.error ~rule ~code (Span.of_lexing t.startp t.endp) msg :: !diags
  in
  let out = ref [] in
  let emit t = out := t :: !out in
  let stack = ref [ 0 ] in
  let depth = ref 0 in
  let last : Lexer.located option ref = ref None in
  List.iter
    (fun (t : Lexer.located) ->
      let new_line =
        match !last with None -> true | Some l -> t.startp.pos_lnum > l.endp.pos_lnum
      in
      (* LEX-035: inside brackets, indentation is not significant. *)
      if new_line && !depth = 0 then begin
        let w = t.startp.pos_cnum - t.startp.pos_bol in
        match !last with
        | None -> if w <> 0 then report ~rule:"LEX-032" ~code:"E0020" t "unexpected indentation"
        | Some l ->
            let top = List.hd !stack in
            if w = top then emit (synth NEWLINE t.startp) (* LEX-032 step 1 *)
            else if w > top then begin
              (* LEX-032 step 2 *)
              if l.tok <> COLON then
                report ~rule:"LEX-032" ~code:"E0020" t
                  "unexpected indentation (the previous line does not end with `:`)"
              else begin
                if w <> top + 4 then
                  report ~rule:"LEX-032" ~code:"E0021" t "indentation must increase by exactly 4 spaces";
                stack := w :: !stack;
                emit (synth INDENT t.startp)
              end
            end
            else begin
              (* LEX-032 step 3 *)
              emit (synth NEWLINE t.startp);
              while List.hd !stack > w do
                stack := List.tl !stack;
                emit (synth DEDENT t.startp)
              done;
              if List.hd !stack <> w then begin
                report ~rule:"LEX-032" ~code:"E0022" t
                  (Printf.sprintf "inconsistent dedent: no enclosing block starts at column %d" (w + 1));
                (* Recovery: treat this line as opening a block at its own width. *)
                stack := w :: !stack
              end
            end
      end;
      (match t.tok with
      | LPAREN | LBRACKET | LBRACE -> incr depth
      | RPAREN | RBRACKET | RBRACE -> if !depth > 0 then decr depth
      | _ -> ());
      emit t;
      last := Some t)
    toks;
  (* LEX-034 *)
  let endp = match !last with Some l -> l.endp | None -> Lexing.dummy_pos in
  if !last <> None then emit (synth NEWLINE endp);
  List.iter (fun w -> if w > 0 then emit (synth DEDENT endp)) !stack;
  emit (synth EOF endp);
  (List.rev !out, List.rev !diags)
