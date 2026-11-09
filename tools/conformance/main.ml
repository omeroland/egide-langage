(* Conformance runner CLI (docs/testing.md §2). Normally invoked as tools/run-conformance.sh from
   the repository root. Exit status: 0 all tests passed or were skipped, 1 some test failed,
   2 usage error. *)

open Egide_conformance

let usage =
  "usage: run-conformance [OPTIONS] [PATH...]\n\
   Runs the .egd conformance tests under PATH (files or directories; default: tests/conformance\n\
   tests/security) against the egide compiler. Options:"

let die fmt = Printf.ksprintf (fun m -> prerr_endline ("run-conformance: " ^ m); exit 2) fmt

let () =
  let egide =
    ref (Option.value (Sys.getenv_opt "EGIDE") ~default:"_build/default/compiler/bin/main.exe")
  in
  let phase = ref None and phase_file = ref "tasks/PHASE" and spec_dir = ref "spec" in
  let jobs = ref (Domain.recommended_domain_count ()) and timeout = ref 30. in
  let backends = ref "interp" and junit = ref None and verbose = ref false and paths = ref [] in
  let specs =
    Arg.align
      [
        ( "--egide",
          Arg.Set_string egide,
          "EXE compiler to test (default: $EGIDE or the dune build)" );
        ( "--phase",
          Arg.Int (fun n -> phase := Some n),
          "N current phase (default: read --phase-file)" );
        ( "--phase-file",
          Arg.Set_string phase_file,
          "FILE file holding the current phase (default: tasks/PHASE)" );
        ( "--spec-dir",
          Arg.Set_string spec_dir,
          "DIR rule ids cited by tests must be defined here (default: spec; '' disables)" );
        ("--jobs", Arg.Set_int jobs, "N parallel compiler runs (default: number of cores)");
        ("-j", Arg.Set_int jobs, "N same as --jobs");
        ("--timeout", Arg.Set_float timeout, "SECONDS per compiler run (default: 30)");
        ( "--backends",
          Arg.Set_string backends,
          "LIST backends for run-* tests, comma-separated (default, and only one supported: interp)"
        );
        ("--junit", Arg.String (fun f -> junit := Some f), "FILE also write a JUnit XML report");
        ("--verbose", Arg.Set verbose, " also list passing tests");
        ("-v", Arg.Set verbose, " same as --verbose");
      ]
  in
  Arg.parse specs (fun p -> paths := p :: !paths) usage;
  let phase =
    match !phase with
    | Some p -> p
    | None -> (
        let read () = In_channel.with_open_bin !phase_file In_channel.input_all in
        match read () |> String.trim |> int_of_string_opt with
        | Some p -> p
        | None -> die "%s does not contain a phase number" !phase_file
        | exception Sys_error m -> die "%s" m)
  in
  let backends =
    String.split_on_char ',' !backends
    |> List.map String.trim
    |> List.filter (( <> ) "")
    |> List.map (fun s ->
           match Header.backend_of_string s with
           | Some b when List.mem b Suite.supported_backends -> b
           | Some _ -> die "backend %s is not supported by the runner yet" s
           | None -> die "unknown backend %s (expected interp, go or native)" s)
  in
  let known_rules =
    if !spec_dir = "" then None
    else
      match Suite.rules_of_spec !spec_dir with
      | [] -> die "no rule ids found in %s (use --spec-dir '' to disable the check)" !spec_dir
      | ids -> Some ids
  in
  let paths =
    match List.rev !paths with [] -> [ "tests/conformance"; "tests/security" ] | ps -> ps
  in
  let files = match Suite.discover paths with Ok fs -> fs | Error m -> die "%s" m in
  if !timeout <= 0. then die "--timeout must be positive";
  let cfg =
    { Suite.egide = !egide; phase; known_rules; jobs = !jobs; timeout = !timeout; backends }
  in
  let t0 = Unix.gettimeofday () in
  let cases, peak = Suite.run cfg files in
  Suite.print_report ~verbose:!verbose ~phase cases;
  if !verbose then
    Printf.printf "finished in %.2fs, up to %d compiler runs in parallel (--jobs %d)\n"
      (Unix.gettimeofday () -. t0) peak cfg.jobs;
  Option.iter
    (fun f ->
      try Out_channel.with_open_bin f (fun oc -> output_string oc (Junit.to_xml cases))
      with Sys_error m -> die "%s" m)
    !junit;
  exit (if Suite.failed cases then 1 else 0)
