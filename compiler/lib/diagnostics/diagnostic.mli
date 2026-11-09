(** Compiler diagnostics (spec/13-toolchain.md TOOL-040..042, catalogue in docs/diagnostics.md, JSON
    schema in docs/diagnostics.schema.json).

    Spans are [start, stop) with 1-based lines and columns counted in Unicode scalar values. *)

type severity = Error | Warning

type label = { span : Egide_source.Span.t; message : string }
(** A secondary span with an explanation, e.g. "used here". The message may be empty. *)

type edit = { span : Egide_source.Span.t; replacement : string }
(** Replace the text of [span] by [replacement]. An empty span inserts; an empty replacement deletes. *)

type fix = { message : string; edits : edit list }
(** A machine-applicable suggested fix (TOOL-040): a description and at least one edit. *)

type t = {
  code : string;  (** e.g. ["E0022"]; [E]/[W] + 4 digits, or ["ICE"] *)
  severity : severity;
  rule : string option;  (** spec rule id, e.g. [Some "LEX-032"]; [None] is reserved for internal errors *)
  message : string;  (** one line, non-empty *)
  span : Egide_source.Span.t;  (** primary span *)
  labels : label list;  (** secondary spans *)
  notes : string list;
  fixes : fix list;
}

val error :
  rule:string ->
  ?labels:label list ->
  ?notes:string list ->
  ?fixes:fix list ->
  code:string ->
  Egide_source.Span.t ->
  string ->
  t
(** [error ~rule ~code span message]. TOOL-040: every diagnostic cites the rule it enforces.
    @raise Invalid_argument (a compiler bug) unless [code] is [E] + 4 digits or ["ICE"], [rule] is a
    rule id ([LEX-032]), and the message, every note and every fix message are non-empty and every
    fix has an edit. *)

val warning :
  rule:string ->
  ?labels:label list ->
  ?notes:string list ->
  ?fixes:fix list ->
  code:string ->
  Egide_source.Span.t ->
  string ->
  t
(** As {!error}, with a [W] code. *)

val label : Egide_source.Span.t -> string -> label
val edit : Egide_source.Span.t -> string -> edit
val fix : string -> edit list -> fix
val severity_to_string : severity -> string

val to_human : t -> string
(** [file:line:col: error[E0022]: message (LEX-032)], then secondary locations, notes and fixes, one per
    line. The first line is what [tools/run-conformance.sh] matches. Free text is passed through
    {!Text.sanitize}, so control and bidi characters are shown escaped. *)

val render_human : sources:(string -> string option) -> t -> string
(** As {!to_human}, with source excerpts: [sources file] returns the contents of [file] when
    available. Primary spans are marked [^], secondary spans [-] with their message. Spans whose file
    is unavailable or which lie outside it are listed as locations instead. *)

val to_json : t -> string
(** One JSON object on one line, valid against docs/diagnostics.schema.json (TOOL-042). *)

(** A sink accumulating diagnostics in emission order. Passes report and continue (docs/architecture.md §2). *)
module Sink : sig
  type diag := t
  type t

  val create : unit -> t
  val report : t -> diag -> unit
  val to_list : t -> diag list
  val has_errors : t -> bool
end
