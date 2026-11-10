(** The layout algorithm (spec/02 §2.4, LEX-030..035): converts raw tokens into a stream with
    NEWLINE / INDENT / DEDENT so the grammar is context-free.

    Covers LEX-030 (a) bracket joining and (b) continuation lines, LEX-031, LEX-032, LEX-033 (E0023,
    single-line blocks), LEX-034, LEX-035. *)

val run : Lexer.located list -> Lexer.located list * Egide_diagnostics.Diagnostic.t list
(** The output always ends with [EOF]; when the input is non-empty it ends with
    [NEWLINE; DEDENT*; EOF]. [INDENT] and [DEDENT] are always balanced and properly nested, even
    when diagnostics are reported (property-tested). *)
