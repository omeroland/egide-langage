(** Whole-file checks performed on raw bytes before tokenising (LEX-001..003). *)

val check : file:string -> string -> Egide_diagnostics.Diagnostic.t list
(** Reports invalid UTF-8 (E0001), a byte-order mark (E0002), lone CR (E0003) and forbidden code
    points (E0004) anywhere in the file, including comments and string literals. *)

val is_forbidden : int -> bool
(** LEX-003: bidirectional controls, invisible characters, separators and C0/C1 controls except LF
    and HT. (HT outside strings is rejected by the lexer, LEX-004.) *)
