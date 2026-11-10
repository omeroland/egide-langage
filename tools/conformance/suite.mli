(** Discover, plan, run and report a conformance suite (docs/testing.md §2). *)

type config = {
  egide : string;  (** Compiler executable. *)
  phase : int;  (** Current roadmap phase (tasks/PHASE). *)
  known_rules : string list option;
      (** Rule ids defined by the spec; when set, a test citing another id fails. *)
  jobs : int;
  timeout : float;  (** Seconds per compiler run. *)
  backends : Header.backend list;  (** Backends this runner can execute [run-*] tests on. *)
}

val supported_backends : Header.backend list
(** Backends the runner knows how to drive: [interp] ([egide run FILE]). [go] and [native] are added
    when the corresponding [egide] commands exist. *)

val discover : string list -> (string list, string) result
(** [discover paths] lists the [.egd] files of [paths] (files or directories, recursively), sorted
    and without duplicates. A path that does not exist is an error. *)

val rules_of_spec : string -> string list
(** [rules_of_spec dir] lists the rule ids defined ([**[PREFIX-NNN]]) in the [.md] files of [dir],
    recursively. *)

val run : config -> string list -> Junit.case list * int
(** [run cfg files] checks every test file and returns one case per compiler run (one per backend
    for [run-*] tests), sorted by file then name, and the peak parallelism reached.

    Order of decisions for a file: an unreadable file or an invalid header (including no [# spec:]
    and unknown rule ids) is a failure, even when the test's phase is in the future; then a phase
    above [cfg.phase] is a skip; then, for [run-*], a test with no backend in common with
    [cfg.backends] is a skip; otherwise the compiler runs:
    [lex|parse|check --error-format=json FILE] or [run FILE]. *)

val print_report : verbose:bool -> phase:int -> Junit.case list -> unit
(** Prints [FAIL] lines (with details) and [SKIP] lines, [PASS] lines when [verbose], then the
    summary line [conformance: N passed, N failed, N skipped (phase P)]. *)

val failed : Junit.case list -> bool
