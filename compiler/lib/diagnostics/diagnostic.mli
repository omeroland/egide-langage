(** Compiler diagnostics (spec/13-toolchain.md TOOL-040..042, catalogue in docs/diagnostics.md).
    Seed version: T-0002 adds labels, fixes and rich rendering. *)

type severity = Error | Warning

type t = {
  code : string;  (** e.g. ["E0022"] *)
  severity : severity;
  rule : string option;  (** spec rule id, e.g. [Some "LEX-032"] *)
  message : string;
  span : Egide_source.Span.t;
  notes : string list;
}

val error : ?rule:string -> ?notes:string list -> code:string -> Egide_source.Span.t -> string -> t
val warning : ?rule:string -> ?notes:string list -> code:string -> Egide_source.Span.t -> string -> t

val to_human : t -> string
(** [file:line:col: error[E0022]: message (LEX-032)] followed by notes. *)

val to_json : t -> string
(** One JSON object on one line (subset of the docs/diagnostics.md format). *)

(** A sink accumulating diagnostics in emission order. Passes report and continue (docs/architecture.md §2). *)
module Sink : sig
  type diag := t
  type t

  val create : unit -> t
  val report : t -> diag -> unit
  val to_list : t -> diag list
  val has_errors : t -> bool
end
