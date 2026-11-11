(** The only way the CLI writes to stdout and stderr (LEX-006).

    Callers escape source text with {!Escape.display} when they build a line; this layer is the
    guard behind them: every string is passed through {!Escape.neutralize} before it reaches the
    channel, so a missed call cannot deliver a terminal escape sequence, a bidirectional override or
    an invisible character. Nothing in [compiler/bin/] may use the raw channel functions (a lint
    test enforces it). *)

val print : string -> unit
(** Write to stdout, no newline added. *)

val println : string -> unit
(** Write to stdout, then LF. *)

val eprintln : string -> unit
(** Write to stderr, then LF. *)
