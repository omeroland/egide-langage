(** The only way the CLI writes to stdout and stderr (LEX-006).

    Callers escape source text with {!Escape.display} when they build a line; this layer is the
    guard behind them: every string is passed through {!Escape.neutralize} (blocks) or
    {!Escape.neutralize_line} (lines) before it reaches the channel, so a missed call cannot deliver
    a terminal escape sequence, a bidirectional override or an invisible character. Nothing in
    [compiler/bin/] may use the raw channel functions (a lint test enforces it).

    Use {!line} and {!eline} by default: they also escape LF, so a source-derived string cannot
    forge a second output line. {!block} and {!eblock} keep LF as structure and are for text that is
    multi-line by construction (diagnostics with excerpts, the AST printer, usage). *)

val line : string -> unit
(** One line on stdout, then LF. LF, CR and the other controls inside the string are escaped. *)

val eline : string -> unit
(** One line on stderr, then LF. *)

val block : string -> unit
(** A multi-line text on stdout, then LF. LF is kept. *)

val eblock : string -> unit
(** A multi-line text on stderr, then LF. LF is kept. *)
