(** Pure decision: did one run of the compiler meet a test's expectation?

    Exit-status conventions (tooling-engineer rules; ERR-040 for 101): 0 success, 1 user error
    (diagnostics), 2 usage error, 70 internal compiler error, 101 panic. *)

type exit =
  | Exited of int
  | Signaled of int  (** OCaml signal number, as in [Unix.WSIGNALED]. *)
  | Timed_out of float  (** Killed after this many seconds. *)
  | Spawn_error of string  (** The compiler could not be started at all. *)

type actual_diagnostic = { code : string; severity : string; line : int; col : int }

val diagnostics_of_stderr : string -> actual_diagnostic list
(** Diagnostics printed by [--error-format=json] (one object per line, schema in
    docs/diagnostics.md). Objects without a [code] or a [span.start] position are ignored. *)

val check : Header.t -> exit -> stdout:string -> stderr:string -> (unit, string) result
(** [check h exit ~stdout ~stderr] is [Ok ()] when the run satisfies [h]:

    - any run: not a crash (no [ICE] diagnostic, no exit 70, no signal, no timeout, no uncaught
      OCaml exception on stderr);
    - [lex-pass], [parse-pass]: exit 0;
    - [lex-fail], [parse-fail], [compile-fail]: exit 1 and every [# diagnostic:] matched by a
      distinct reported diagnostic (same code, same start line and column). Additional reported
      diagnostics are allowed;
    - [run-pass]: exit 0 and, when [h.stdout] is set, stdout lines equal to it;
    - [run-panic]: exit 101.

    Otherwise [Error msg] explains the first mismatch on one or more lines. *)

val lines : string -> string list
(** [lines s] splits on ['\n'], dropping one final empty element so that ["a\nb\n"] and
    ["a\nb"] both give [["a"; "b"]]. A trailing ['\r'] is kept: CRLF output is a mismatch. *)
