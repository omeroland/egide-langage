(** Minimal JSON reader for the diagnostics emitted by [egide --error-format=json] (TOOL-042).

    The runner has no third-party dependency, so it carries this small RFC 8259 parser. It is only
    used to read compiler output, never to write JSON. *)

type t =
  | Null
  | Bool of bool
  | Number of float
  | String of string  (** UTF-8; [\uXXXX] escapes, including surrogate pairs, are decoded. *)
  | Array of t list
  | Object of (string * t) list

val parse : string -> (t, string) result
(** [parse s] parses exactly one JSON value; surrounding whitespace is allowed, trailing data is
    an error. *)

val objects_in_lines : string -> t list
(** [objects_in_lines text] returns, in order, every line of [text] that is a complete JSON object
    once surrounding whitespace is removed. Other lines (plain messages, OCaml backtraces...) are
    ignored: the compiler prints one diagnostic object per line (TOOL-042). *)

val member : string -> t -> t option
(** [member key v] is the value of field [key] when [v] is an object that has it. *)

val path : string list -> t -> t option
(** [path ["span"; "start"; "line"] v] follows nested object fields. *)
