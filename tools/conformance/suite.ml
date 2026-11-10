type config = {
  egide : string;
  phase : int;
  known_rules : string list option;
  jobs : int;
  timeout : float;
  backends : Header.backend list;
}

let supported_backends = [ Header.Interp ]

let rec walk path acc =
  if Sys.is_directory path then
    Sys.readdir path |> Array.to_list
    |> List.fold_left (fun acc name -> walk (Filename.concat path name) acc) acc
  else path :: acc

let discover paths =
  List.fold_left
    (fun acc p ->
      match acc with
      | Error _ as e -> e
      | Ok files ->
          if not (Sys.file_exists p) then Error ("no such file or directory: " ^ p)
          else if Sys.is_directory p then
            Ok (List.filter (fun f -> Filename.check_suffix f ".egd") (walk p []) @ files)
          else if Filename.check_suffix p ".egd" then Ok (p :: files)
          else Error ("not a .egd test file: " ^ p))
    (Ok []) paths
  |> Result.map (List.sort_uniq String.compare)

(* Rule definitions are written **[PREFIX-NNN] in the spec (spec/README.md). *)
let rules_of_spec dir =
  let ids_in text =
    let n = String.length text in
    let rec go i acc =
      if i + 3 > n then acc
      else if String.sub text i 3 = "**[" then
        match String.index_from_opt text (i + 3) ']' with
        | Some j when Header.is_rule_id (String.sub text (i + 3) (j - i - 3)) ->
            go (j + 1) (String.sub text (i + 3) (j - i - 3) :: acc)
        | _ -> go (i + 3) acc
      else go (i + 1) acc
    in
    go 0 []
  in
  if not (Sys.file_exists dir && Sys.is_directory dir) then []
  else
    walk dir []
    |> List.filter (fun f -> Filename.check_suffix f ".md")
    |> List.concat_map (fun f -> ids_in (In_channel.with_open_bin f In_channel.input_all))
    |> List.sort_uniq String.compare

type run = { file : string; name : string; header : Header.t; job : Exec.job }
type planned = Decided of Junit.case | Run of run

let base file = Filename.remove_extension (Filename.basename file)
let read path =
  try Ok (In_channel.with_open_bin path In_channel.input_all) with Sys_error m -> Error m
let fail file m = Decided { file; name = base file; status = Fail m; time = 0. }
let skip file m = Decided { file; name = base file; status = Skip m; time = 0. }

let plan cfg file =
  let stdout_path = Filename.remove_extension file ^ ".stdout" in
  let stdout_file =
    if Sys.file_exists stdout_path then Result.to_option (read stdout_path) else None
  in
  match read file with
  | Error m -> [ fail file ("cannot read test: " ^ m) ]
  | Ok src -> (
      let unknown (h : Header.t) =
        match cfg.known_rules with
        | None -> []
        | Some known ->
            List.filter (fun id -> not (List.mem id known)) h.spec
            |> List.map (Printf.sprintf "rule %s is not defined in the spec")
      in
      match Header.parse ?stdout_file src with
      | Error es -> [ fail file ("invalid test header:\n  - " ^ String.concat "\n  - " es) ]
      | Ok h when unknown h <> [] ->
          [ fail file ("invalid test header:\n  - " ^ String.concat "\n  - " (unknown h)) ]
      | Ok h when h.phase > cfg.phase ->
          [ skip file (Printf.sprintf "phase %d > current phase %d" h.phase cfg.phase) ]
      | Ok h -> (
          let check_job sub =
            let job = { Exec.prog = cfg.egide; args = [ sub; "--error-format=json"; file ] } in
            [ Run { file; name = base file; header = h; job } ]
          in
          match h.expect with
          | Lex_pass | Lex_fail -> check_job "lex"
          | Parse_pass | Parse_fail -> check_job "parse"
          | Compile_fail -> check_job "check"
          | Run_pass | Run_panic -> (
              let names bs = String.concat ", " (List.map Header.backend_to_string bs) in
              match List.filter (fun b -> List.mem b h.backends) cfg.backends with
              | [] ->
                  [ skip file
                      (Printf.sprintf "no available backend (test: %s; runner: %s)"
                         (names h.backends) (names cfg.backends)) ]
              | bs ->
                  List.map
                    (fun (b : Header.backend) ->
                      let name = Printf.sprintf "%s[%s]" (base file) (Header.backend_to_string b) in
                      match b with
                      | Interp ->
                          let job = { Exec.prog = cfg.egide; args = [ "run"; file ] } in
                          Run { file; name; header = h; job }
                      | Go | Native ->
                          (* Not in [supported_backends]: the CLI rejects them before planning. *)
                          let status = Junit.Fail "the runner cannot drive this backend yet" in
                          Decided { file; name; status; time = 0. })
                    bs)))

let excerpt label s =
  match Verdict.lines s with
  | [] -> ""
  | ls ->
      let max = 20 in
      let shown = List.filteri (fun i _ -> i < max) ls in
      let more = List.length ls - max in
      String.concat "" (List.map (fun l -> Printf.sprintf "\n  %s| %s" label l) shown)
      ^ if more > 0 then Printf.sprintf "\n  %s| ... (%d more lines)" label more else ""

let run cfg files =
  let planned = List.concat_map (plan cfg) files in
  let runs =
    List.filter_map (function Run r -> Some r | Decided _ -> None) planned |> Array.of_list
  in
  let outcomes, peak =
    Exec.run_all ~jobs:cfg.jobs ~timeout:cfg.timeout (Array.map (fun r -> r.job) runs)
  in
  let ran =
    Array.to_list
      (Array.mapi
         (fun i r ->
           let (o : Exec.outcome) = outcomes.(i) in
           let status =
             match Verdict.check r.header o.exit ~stdout:o.stdout ~stderr:o.stderr with
             | Ok () -> Junit.Pass
             | Error m ->
                 Fail
                   (m
                   ^ Printf.sprintf "\n  $ %s" (String.concat " " (r.job.prog :: r.job.args))
                   ^ excerpt "stdout" o.stdout ^ excerpt "stderr" o.stderr)
           in
           { Junit.file = r.file; name = r.name; status; time = o.time })
         runs)
  in
  let decided = List.filter_map (function Decided c -> Some c | Run _ -> None) planned in
  let cases =
    List.sort
      (fun (a : Junit.case) b -> compare (a.file, a.name) (b.file, b.name))
      (decided @ ran)
  in
  (cases, peak)

let label (c : Junit.case) =
  if c.name = base c.file then c.file
  else
    let b = String.length (base c.file) in
    c.file ^ " " ^ String.sub c.name b (String.length c.name - b)

let failed cases =
  List.exists
    (fun (c : Junit.case) -> match c.status with Fail _ -> true | Pass | Skip _ -> false)
    cases

let print_report ~verbose ~phase cases =
  let p = ref 0 and f = ref 0 and s = ref 0 in
  List.iter
    (fun (c : Junit.case) ->
      match c.status with
      | Pass ->
          incr p;
          if verbose then Printf.printf "PASS %s (%.2fs)\n" (label c) c.time
      | Fail m ->
          incr f;
          Printf.printf "FAIL %s: %s\n" (label c) m
      | Skip m ->
          incr s;
          Printf.printf "SKIP %s: %s\n" (label c) m)
    cases;
  Printf.printf "conformance: %d passed, %d failed, %d skipped (phase %d)\n" !p !f !s phase
