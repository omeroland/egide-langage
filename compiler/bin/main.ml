(* egide — command-line entry point (spec/13-toolchain.md). Seed: lex and parse only.
   T-0019 replaces this argv handling with cmdliner and adds the other subcommands. *)

module D = Egide_diagnostics.Diagnostic

let version = "0.0.1-seed"

let usage () =
  prerr_endline
    "usage: egide [--error-format=human|json] (lex|parse) FILE\n\
    \       egide --version\n\
     Other subcommands of spec/13 are not implemented yet.";
  exit 2

let read_file path =
  try Ok (In_channel.with_open_bin path In_channel.input_all) with Sys_error m -> Error m

let print_diags json diags =
  List.iter (fun d -> prerr_endline (if json then D.to_json d else D.to_human d)) diags

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  let json = List.mem "--error-format=json" args in
  let args = List.filter (fun a -> not (String.starts_with ~prefix:"--error-format=" a)) args in
  match args with
  | [ "--version" ] -> print_endline ("egide " ^ version)
  | [ cmd; path ] when cmd = "lex" || cmd = "parse" -> (
      match read_file path with
      | Error m ->
          prerr_endline ("egide: " ^ m);
          exit 1
      | Ok src ->
          let diags =
            if cmd = "lex" then begin
              let toks, diags = Egide_syntax.Parse.tokens ~file:path src in
              List.iter
                (fun (t : Egide_syntax.Lexer.located) ->
                  Printf.printf "%d:%d %s\n" t.startp.pos_lnum
                    (t.startp.pos_cnum - t.startp.pos_bol + 1)
                    (Egide_syntax.Parse.token_to_string t.tok))
                toks;
              diags
            end
            else begin
              let ast, diags = Egide_syntax.Parse.file ~file:path src in
              Option.iter (fun a -> print_endline (Egide_syntax.Ast.to_sexp a)) ast;
              diags
            end
          in
          print_diags json diags;
          if List.exists (fun (d : D.t) -> d.severity = D.Error) diags then exit 1)
  | _ -> usage ()
