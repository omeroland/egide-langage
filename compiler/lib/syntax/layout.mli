(** The layout algorithm (spec/02 §2.4, LEX-030..035): converts raw tokens into a stream with
    NEWLINE / INDENT / DEDENT so the grammar is context-free.

    Seed coverage: LEX-030 (a) bracket joining, LEX-031, LEX-032, LEX-034, LEX-035.
    T-0007 adds LEX-030 (b) continuation lines and the E0023 check of LEX-033. *)

val run : Lexer.located list -> Lexer.located list * Egide_diagnostics.Diagnostic.t list
(** The output always ends with [EOF]; when the input is non-empty it ends with
    [NEWLINE; DEDENT*; EOF]. *)
