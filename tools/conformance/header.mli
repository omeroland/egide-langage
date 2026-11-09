(** Conformance test headers (docs/testing.md §2).

    The header is the leading block of a test file: every line from the top up to (excluding) the
    first line that is neither blank nor a [#] comment. A UTF-8 byte-order mark before the first
    line is ignored, so that LEX-001 tests can start with one. Directives are lines of the form
    [# key: value]:

    - [# spec:] rule ids, comma or space separated; mandatory, repeatable (ids accumulate).
    - [# expect:] exactly one of {!expect}; mandatory.
    - [# diagnostic: CODE at L:C] repeatable; only for [*-fail]; at least one is required for
      [*-fail] so that a test cannot pass because the compiler failed for an unrelated reason.
    - [# stdout:] one expected output line, repeatable; only for [run-pass]. Alternatively, a
      sibling [<name>.stdout] file (not both).
    - [# phase: N] minimum roadmap phase, at most once; default 0.
    - [# backends:] comma-separated subset of [interp], [go], [native]; only for [run-*].
    - [# requires:] script dependencies (TOOL-011); accepted and ignored by the runner.

    Any other [# key:] directive in the header is an error, so that a misspelt directive
    ([# diagnostics:]) cannot silently weaken a test. A runner directive found after the header
    block is an error for the same reason. *)

type expect = Lex_pass | Lex_fail | Parse_pass | Parse_fail | Compile_fail | Run_pass | Run_panic
type backend = Interp | Go | Native

type diagnostic = { code : string; line : int; col : int }
(** An expected diagnostic: its code ([E0022], [W0001]) and 1-based start position. *)

type t = {
  spec : string list;  (** Cited rule ids, in order of appearance, without duplicates. *)
  expect : expect;
  diagnostics : diagnostic list;  (** In order of appearance. *)
  stdout : string list option;  (** Expected stdout lines; [None] means stdout is not checked. *)
  phase : int;
  backends : backend list;  (** Default: all three, in the order interp, go, native. *)
}

val parse : ?stdout_file:string -> string -> (t, string list) result
(** [parse ?stdout_file source] reads the header of a test whose text is [source]. [stdout_file]
    is the content of the sibling [.stdout] file when it exists. On error, every problem found is
    returned, each prefixed with its line number when it has one. *)

val is_rule_id : string -> bool
(** [is_rule_id s] holds when [s] has the shape [PREFIX-NNN] of spec/README.md. *)

val expect_to_string : expect -> string
val backend_to_string : backend -> string
val backend_of_string : string -> backend option
val diagnostic_to_string : diagnostic -> string
(** [diagnostic_to_string d] is ["E0022 at 8:3"]. *)
