(** Front door of the syntax library: source text → AST + diagnostics. *)

val tokens : file:string -> string -> Lexer.located list * Egide_diagnostics.Diagnostic.t list
(** Raw lexing followed by the layout pass. *)

val file : file:string -> string -> Ast.file option * Egide_diagnostics.Diagnostic.t list
(** Parse a whole file. Returns [None] when a syntax error prevents building an AST (recovery:
    T-0013). *)

val token_to_string : Tokens.token -> string
