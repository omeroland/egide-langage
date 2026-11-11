(** Front door of the syntax library: source text → AST + diagnostics. *)

val tokens : file:string -> string -> Lexer.located list * Egide_diagnostics.Diagnostic.t list
(** Raw lexing followed by the layout pass. *)

val file :
  ?gen:Node_id.Gen.t ->
  file:string ->
  string ->
  Ast.file option * Egide_diagnostics.Diagnostic.t list
(** Parse a whole file. Returns [None] when a syntax error prevents building an AST (recovery:
    T-0013).

    Node ids are allocated from [gen] (default: a fresh generator, so the first id is [#0] and ids
    are unique within the file). Passing one generator to several calls makes ids unique across
    those files. The same source and the same generator state always give the same ids. *)

val token_to_string : Tokens.token -> string
