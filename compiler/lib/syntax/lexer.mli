(** Raw lexer (LEX-001..062). Produces tokens without layout information; {!Layout} adds
    NEWLINE/INDENT/DEDENT. Seed coverage: identifiers, keywords, integer and simple float literals,
    plain string literals with basic escapes, operators, comments. Numeric, string and template
    literals (LEX-040..055): a prefixed template is one [TEMPLATE] token that holds the token
    streams of its interpolations. *)

type located = { tok : Tokens.token; startp : Lexing.position; endp : Lexing.position }

val tokenize : file:string -> string -> located list * Egide_diagnostics.Diagnostic.t list
(** Never raises on any input (property-tested in T-0006/T-0018). The returned list does not include
    [EOF]; {!Layout.run} appends it. *)
