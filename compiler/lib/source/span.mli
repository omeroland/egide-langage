(** Source positions and spans. Lines and columns are 1-based; columns count Unicode scalar values
    (docs/diagnostics.md). *)

type pos = { line : int; col : int }

type t = { file : string; start : pos; stop : pos }

val make : file:string -> start:pos -> stop:pos -> t

val of_lexing : Lexing.position -> Lexing.position -> t
(** Build a span from a pair of lexing positions. [pos_cnum - pos_bol] must count code points, which
    holds for positions produced by sedlex. *)

val dummy : t
val pp : Format.formatter -> t -> unit
val to_string : t -> string
