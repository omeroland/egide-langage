type exit = Exited of int | Signaled of int | Timed_out of float | Spawn_error of string
type actual_diagnostic = { code : string; severity : string; line : int; col : int }

let lines = Text.lines

let diagnostics_of_stderr stderr =
  Json.objects_in_lines stderr
  |> List.filter_map (fun o ->
      let str k = match Json.member k o with Some (Json.String s) -> Some s | _ -> None in
      let int p =
        match Json.path p o with
        | Some (Json.Number f) when Float.is_integer f -> Some (int_of_float f)
        | _ -> None
      in
      match (str "code", int [ "span"; "start"; "line" ], int [ "span"; "start"; "col" ]) with
      | Some code, Some line, Some col ->
          Some { code; severity = Option.value (str "severity") ~default:""; line; col }
      | _ -> None)

let signal_name s =
  List.assoc_opt s
    Sys.
      [
        (sigsegv, "SIGSEGV");
        (sigabrt, "SIGABRT");
        (sigkill, "SIGKILL");
        (sigbus, "SIGBUS");
        (sigfpe, "SIGFPE");
        (sigill, "SIGILL");
        (sigterm, "SIGTERM");
        (sigint, "SIGINT");
        (sigpipe, "SIGPIPE");
      ]
  |> Option.value ~default:(Printf.sprintf "signal %d" s)

let show_actual (d : actual_diagnostic) = Printf.sprintf "%s at %d:%d" d.code d.line d.col

let reported ds =
  match ds with [] -> "" | ds -> "\n  reported: " ^ String.concat ", " (List.map show_actual ds)

(* A crash is a failure whatever the test expects: a compiler bug must never make a `*-fail`
   test pass. Exit 70 and `ICE` are the internal-error conventions (docs/architecture.md).
   Returns the exit status of a run that did not crash. *)
let status_unless_crash exit ds stderr =
  let contains sub s =
    let n = String.length sub and m = String.length s in
    let rec go i = i + n <= m && (String.sub s i n = sub || go (i + 1)) in
    go 0
  in
  match exit with
  | Spawn_error m -> Error ("cannot run the compiler: " ^ m)
  | Timed_out t -> Error (Printf.sprintf "timed out after %gs" t)
  | Signaled s -> Error ("compiler crash: killed by signal " ^ signal_name s)
  | Exited 70 -> Error "compiler crash: internal compiler error (exit status 70)"
  | Exited _ when List.exists (fun (d : actual_diagnostic) -> d.code = "ICE") ds ->
      Error "compiler crash: ICE diagnostic reported"
  | Exited _ when contains "Fatal error: exception " stderr ->
      Error "compiler crash: uncaught OCaml exception"
  | Exited n -> Ok n

(* Each expected diagnostic consumes one distinct reported diagnostic with the same code and
   start position (docs/testing.md §2: `<code> at <line>:<col>`, repeatable). *)
let missing_diagnostics (expected : Header.diagnostic list) actual =
  let rec go missing pool = function
    | [] -> List.rev missing
    | (e : Header.diagnostic) :: rest -> (
        let same (a : actual_diagnostic) = a.code = e.code && a.line = e.line && a.col = e.col in
        match List.find_index same pool with
        | Some i -> go missing (List.filteri (fun j _ -> j <> i) pool) rest
        | None -> go (e :: missing) pool rest)
  in
  go [] actual expected

let check (h : Header.t) exit ~stdout ~stderr =
  let ds = diagnostics_of_stderr stderr in
  match status_unless_crash exit ds stderr with
  | Error _ as e -> e
  | Ok status -> (
      let want_status code what =
        if status = code then Ok ()
        else
          Error
            (Printf.sprintf "expected exit status %d%s, got %d%s" code what status (reported ds))
      in
      match h.expect with
      | Lex_pass | Parse_pass -> want_status 0 ""
      | Lex_fail | Parse_fail | Compile_fail -> (
          match want_status 1 "" with
          | Error _ as e -> e
          | Ok () -> (
              match missing_diagnostics h.diagnostics ds with
              | [] -> Ok ()
              | missing ->
                  Error
                    (String.concat "\n  "
                       (List.map
                          (fun d -> "missing diagnostic " ^ Header.diagnostic_to_string d)
                          missing)
                    ^
                    if ds = [] then
                      "\n  reported: none (diagnostics are read from --error-format=json output)"
                    else reported ds)))
      | Run_panic -> want_status 101 " (panic)"
      | Run_pass -> (
          match want_status 0 "" with
          | Error _ as e -> e
          | Ok () -> (
              match h.stdout with
              | None -> Ok ()
              | Some expected ->
                  let actual = lines stdout in
                  if actual = expected then Ok ()
                  else
                    let show l =
                      "[" ^ String.concat ", " (List.map (Printf.sprintf "%S") l) ^ "]"
                    in
                    Error
                      (Printf.sprintf "stdout differs\n  expected: %s\n  actual:   %s"
                         (show expected) (show actual)))))
