open Tokens
module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let synth tok (p : Lexing.position) : Lexer.located = { tok; startp = p; endp = p }

(* An entry of the indentation stack (LEX-032). [phantom] entries are pushed only by error recovery
   after E0022: no INDENT was emitted for them, so popping them emits no DEDENT. This keeps the
   output balanced (one DEDENT per INDENT) whatever the input. *)
type level = { width : int; phantom : bool }

(* LEX-030 (b): tokens that may start a continuation line. *)
let is_continuation_start = function PIPEGT | DOT | KW_AND | KW_OR -> true | _ -> false
let column (t : Lexer.located) = t.startp.pos_cnum - t.startp.pos_bol

let run (toks : Lexer.located list) =
  let diags = ref [] in
  let report ~rule ~code (t : Lexer.located) msg =
    diags := D.error ~rule ~code (Span.of_lexing t.startp t.endp) msg :: !diags
  in
  let out = ref [] in
  let emit t = out := t :: !out in
  let stack = ref [ { width = 0; phantom = false } ] in
  let top () = (List.hd !stack).width in
  (* Bracket nesting depth, for LEX-030 (a) / LEX-035. *)
  let depth = ref 0 in
  (* Width of the first physical line of the current logical line, for LEX-030 (b). *)
  let line_width = ref 0 in
  let last : Lexer.located option ref = ref None in
  (* LEX-033: [l] is the last token of a logical line that is not followed by an INDENT. *)
  let check_block_colon (l : Lexer.located) =
    if l.tok = COLON then
      report ~rule:"LEX-033" ~code:"E0023" l "expected an indented block after `:`"
  in
  (* LEX-032: [t] is the first token of a new logical line of width [w]; [l] ends the previous one. *)
  let start_logical_line (l : Lexer.located) (t : Lexer.located) w =
    if w > top () then begin
      (* LEX-032 step 2 *)
      if l.tok <> COLON then
        report ~rule:"LEX-032" ~code:"E0020" t
          "unexpected indentation (the previous line does not end with `:`)"
      else begin
        if w <> top () + 4 then
          report ~rule:"LEX-032" ~code:"E0021" t "indentation must increase by exactly 4 spaces";
        stack := { width = w; phantom = false } :: !stack;
        emit (synth INDENT t.startp)
      end
    end
    else begin
      (* w <= t: no INDENT follows the previous logical line. *)
      check_block_colon l;
      if w = top () then emit (synth NEWLINE t.startp) (* LEX-032 step 1 *)
      else begin
        (* LEX-032 step 3 *)
        emit (synth NEWLINE t.startp);
        while top () > w do
          let lv = List.hd !stack in
          stack := List.tl !stack;
          if not lv.phantom then emit (synth DEDENT t.startp)
        done;
        if top () <> w then begin
          report ~rule:"LEX-032" ~code:"E0022" t
            (Printf.sprintf "inconsistent dedent: no enclosing block starts at column %d" (w + 1));
          (* Recovery: treat this line as opening a block at its own width, without an INDENT. *)
          stack := { width = w; phantom = true } :: !stack
        end
      end
    end
  in
  List.iter
    (fun (t : Lexer.located) ->
      (* Blank and comment-only lines produce no raw tokens, so they are skipped here (LEX-031). *)
      let new_line =
        match !last with None -> true | Some l -> t.startp.pos_lnum > l.endp.pos_lnum
      in
      (* LEX-030 (a), LEX-035: inside brackets, line breaks and indentation are not significant. *)
      if new_line && !depth = 0 then begin
        let w = column t in
        match !last with
        | None ->
            if w <> 0 then report ~rule:"LEX-032" ~code:"E0020" t "unexpected indentation";
            line_width := w
        | Some _ when w > !line_width && is_continuation_start t.tok ->
            (* LEX-030 (b): a continuation line joins the current logical line; no layout token. *)
            ()
        | Some l ->
            line_width := w;
            start_logical_line l t w
      end;
      (match t.tok with
      | LPAREN | LBRACKET | LBRACE -> incr depth
      | RPAREN | RBRACKET | RBRACE -> if !depth > 0 then decr depth
      | _ -> ());
      emit t;
      last := Some t)
    toks;
  (* LEX-034. Inside an unclosed bracket the trailing `:` is not a block colon (LEX-035). *)
  let endp = match !last with Some l -> l.endp | None -> Lexing.dummy_pos in
  (match !last with
  | Some l ->
      if !depth = 0 then check_block_colon l;
      emit (synth NEWLINE endp)
  | None -> ());
  List.iter (fun lv -> if lv.width > 0 && not lv.phantom then emit (synth DEDENT endp)) !stack;
  emit (synth EOF endp);
  (List.rev !out, List.rev !diags)
