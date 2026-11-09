(** Run external commands in parallel, with a per-command timeout.

    Single-threaded scheduler: up to [jobs] children run at once ([Unix.create_process], which uses
    [posix_spawn]); stdout and stderr go to temporary files so that a chatty child can never block
    on a full pipe. Children get [/dev/null] as stdin. *)

type job = { prog : string; args : string list  (** Without [prog] itself. *) }

type outcome = {
  exit : Verdict.exit;
  stdout : string;
  stderr : string;
  time : float;  (** Wall-clock seconds. *)
}

val run_all : jobs:int -> timeout:float -> job array -> outcome array * int
(** [run_all ~jobs ~timeout js] runs every job and returns their outcomes (same index as [js]) and
    the peak number of children that were running at the same time. A job still running after
    [timeout] seconds is killed with SIGKILL and reported as [Timed_out]. [jobs] is clamped to at
    least 1. *)
