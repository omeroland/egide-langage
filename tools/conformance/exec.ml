type job = { prog : string; args : string list }
type outcome = { exit : Verdict.exit; stdout : string; stderr : string; time : float }
type running = { index : int; pid : int; out_file : string; err_file : string; started : float }

let read_and_remove path =
  let s = try In_channel.with_open_bin path In_channel.input_all with Sys_error _ -> "" in
  (try Sys.remove path with Sys_error _ -> ());
  s

(* Spawn one job; its stdout and stderr are temporary files. All descriptors the runner opens are
   close-on-exec, so children never inherit each other's outputs. *)
let spawn devnull index job =
  let out_file = Filename.temp_file "egide-conf" ".out" in
  let err_file = Filename.temp_file "egide-conf" ".err" in
  let open_out f = Unix.openfile f [ O_WRONLY; O_TRUNC; O_CLOEXEC ] 0o600 in
  let out_fd = open_out out_file and err_fd = open_out err_file in
  let started = Unix.gettimeofday () in
  let result =
    match
      Unix.create_process job.prog (Array.of_list (job.prog :: job.args)) devnull out_fd err_fd
    with
    | pid -> Ok { index; pid; out_file; err_file; started }
    | exception Unix.Unix_error (e, _, _) ->
        List.iter Sys.remove [ out_file; err_file ];
        Error (Unix.error_message e)
  in
  Unix.close out_fd;
  Unix.close err_fd;
  result

let finish r exit =
  let time = Unix.gettimeofday () -. r.started in
  { exit; stdout = read_and_remove r.out_file; stderr = read_and_remove r.err_file; time }

let rec waitpid_nohang pid =
  try Unix.waitpid [ WNOHANG ] pid with Unix.Unix_error (EINTR, _, _) -> waitpid_nohang pid

let rec waitpid_block pid =
  try snd (Unix.waitpid [] pid) with Unix.Unix_error (EINTR, _, _) -> waitpid_block pid

let to_exit = function Unix.WEXITED n -> Verdict.Exited n | WSIGNALED s | WSTOPPED s -> Signaled s

let run_all ~jobs ~timeout js =
  let jobs = max 1 jobs in
  let n = Array.length js in
  let results = Array.make n None in
  let devnull = Unix.openfile "/dev/null" [ O_RDONLY; O_CLOEXEC ] 0 in
  let next = ref 0 and running = ref [] and peak = ref 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close devnull)
    (fun () ->
      while !next < n || !running <> [] do
        (* Fill the pool. *)
        while !next < n && List.length !running < jobs do
          let i = !next in
          incr next;
          match spawn devnull i js.(i) with
          | Ok r ->
              running := r :: !running;
              peak := max !peak (List.length !running)
          | Error m ->
              results.(i) <- Some { exit = Spawn_error m; stdout = ""; stderr = ""; time = 0. }
        done;
        (* Reap finished children and kill those over the timeout. *)
        let now = Unix.gettimeofday () in
        let still, progressed =
          List.fold_left
            (fun (still, progressed) r ->
              match waitpid_nohang r.pid with
              | 0, _ when now -. r.started > timeout ->
                  (try Unix.kill r.pid Sys.sigkill with Unix.Unix_error _ -> ());
                  ignore (waitpid_block r.pid);
                  results.(r.index) <- Some (finish r (Timed_out timeout));
                  (still, true)
              | 0, _ -> (r :: still, progressed)
              | _, status ->
                  results.(r.index) <- Some (finish r (to_exit status));
                  (still, true))
            ([], false) !running
        in
        running := List.rev still;
        if (not progressed) && !running <> [] then Unix.sleepf 0.002
      done;
      (Array.map (function Some o -> o | None -> invalid_arg "Exec.run_all") results, !peak))
