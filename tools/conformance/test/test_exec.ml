(* Tests of the parallel process pool: output capture, exit statuses, timeouts, parallelism. *)

open Egide_conformance

let sh script : Exec.job = { prog = "/bin/sh"; args = [ "-c"; script ] }

let show (o : Exec.outcome) =
  Printf.printf "%s stdout=%S stderr=%S\n"
    (match o.exit with
    | Exited n -> Printf.sprintf "exited %d" n
    | Signaled _ -> "signaled"
    | Timed_out t -> Printf.sprintf "timed out after %gs" t
    | Spawn_error _ -> "spawn error")
    o.stdout o.stderr

let%expect_test "captures stdout, stderr and exit status, in job order" =
  let outs, _ =
    Exec.run_all ~jobs:3 ~timeout:10.
      [|
        sh "sleep 0.2; echo late; exit 3";
        sh "echo out; echo err >&2";
        sh "kill -9 $$";
        { prog = "/nonexistent/egide"; args = [] };
      |]
  in
  Array.iter show outs;
  [%expect
    {|
    exited 3 stdout="late\n" stderr=""
    exited 0 stdout="out\n" stderr="err\n"
    signaled stdout="" stderr=""
    spawn error stdout="" stderr=""
    |}]

let%expect_test "large outputs do not deadlock" =
  let outs, _ = Exec.run_all ~jobs:2 ~timeout:10. [| sh "head -c 1000000 /dev/zero | tr '\\0' x" |] in
  Printf.printf "%d\n" (String.length outs.(0).stdout);
  [%expect {| 1000000 |}]

let%expect_test "a job over the timeout is killed" =
  let t0 = Unix.gettimeofday () in
  let outs, _ = Exec.run_all ~jobs:2 ~timeout:0.3 [| sh "sleep 5"; sh "echo fast" |] in
  Array.iter show outs;
  Printf.printf "under 3s: %b\n" (Unix.gettimeofday () -. t0 < 3.);
  [%expect
    {|
    timed out after 0.3s stdout="" stderr=""
    exited 0 stdout="fast\n" stderr=""
    under 3s: true
    |}]

let%expect_test "jobs run in parallel, bounded by ~jobs" =
  let js = Array.make 6 (sh "sleep 0.3") in
  let _, peak4 = Exec.run_all ~jobs:4 ~timeout:10. js in
  let _, peak1 = Exec.run_all ~jobs:1 ~timeout:10. (Array.sub js 0 2) in
  let _, peak0 = Exec.run_all ~jobs:0 ~timeout:10. (Array.sub js 0 2) in
  Printf.printf "jobs=4: peak %d; jobs=1: peak %d; jobs=0: peak %d\n" peak4 peak1 peak0;
  [%expect {| jobs=4: peak 4; jobs=1: peak 1; jobs=0: peak 1 |}]
