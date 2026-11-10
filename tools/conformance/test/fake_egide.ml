(* Stand-in for `egide` in the end-to-end test of the runner. Usage: fake_egide CMD [FLAGS] FILE.
   Its behaviour is scripted by lines of FILE that start with `#> ` (outside the test header):
     #> cmd C         exit 3 unless invoked as `fake_egide C ...`
     #> json          exit 3 unless `--error-format=json` was passed
     #> stdout TEXT   print TEXT and a newline on stdout
     #> stderr TEXT   print TEXT and a newline on stderr
     #> diag CODE L:C print a JSON diagnostic (docs/diagnostics.md schema) on stderr
     #> sleep S       sleep S seconds
     #> crash         raise an uncaught exception
     #> exit N        exit with status N (default 0)
   Directives are executed in file order. *)

let fail fmt =
  Printf.ksprintf
    (fun m ->
      prerr_endline ("fake_egide: " ^ m);
      exit 3)
    fmt

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  let cmd, file =
    match args with
    | c :: (_ :: _ as rest) -> (c, List.nth rest (List.length rest - 1))
    | _ -> fail "usage"
  in
  let json = List.mem "--error-format=json" args in
  let src = In_channel.with_open_bin file In_channel.input_all in
  let code = ref 0 in
  String.split_on_char '\n' src
  |> List.iter (fun line ->
      if String.starts_with ~prefix:"#> " line then
        let d = String.sub line 3 (String.length line - 3) in
        let word, rest =
          match String.index_opt d ' ' with
          | Some i -> (String.sub d 0 i, String.sub d (i + 1) (String.length d - i - 1))
          | None -> (d, "")
        in
        match word with
        | "cmd" -> if rest <> cmd then fail "expected command %s, got %s" rest cmd
        | "json" -> if not json then fail "expected --error-format=json"
        | "stdout" -> print_endline rest
        | "stderr" -> prerr_endline rest
        | "diag" ->
            Scanf.sscanf rest "%s %d:%d" (fun c l col ->
                Printf.eprintf
                  {|{"code":"%s","severity":"error","rule":"LEX-001","message":"m","span":{"file":"%s","start":{"line":%d,"col":%d},"end":{"line":%d,"col":%d}},"notes":[]}|}
                  c file l col l (col + 1);
                prerr_newline ())
        | "sleep" -> Unix.sleepf (float_of_string rest)
        | "crash" -> raise Not_found
        | "exit" -> code := int_of_string rest
        | w -> fail "unknown directive %s" w);
  exit !code
