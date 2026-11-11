(** The one escaping function of every tool output (LEX-006, ADR-0017 S1).

    Every output of the toolchain that includes source text or the value of a string literal passes
    it through {!display} (terminals, plain text) or {!json_safe} (JSON, SARIF, JUnit, CycloneDX
    strings). Nothing else in the code base may print such text. A terminal escape sequence, an
    invisible character or a right-to-left override in a value can therefore never reach a terminal
    or a viewer.

    The escaped set is: the LEX-003 set ({!Forbidden_set.mem}), every [Zs] other than U+0020, every
    bidirectional control, DEL, the C1 controls, backslash and the line breaks. *)

val is_dangerous : int -> bool
(** [is_dangerous cp]: [cp] is escaped by {!display} (backslash excepted: it is escaped for
    injectivity, not because it is dangerous). *)

val display : string -> string
(** Plain-text rendering. A dangerous code point becomes [\u{H}] (uppercase hexadecimal, no padding),
    backslash [\\], LF [\n], CR [\r], tab [\t], and a byte that is not part of valid UTF-8 [\xHH].
    The result contains no byte below 0x20, no byte 0x7F and no dangerous code point; it is
    injective, so an escaped value cannot be confused with another. *)

val display_quoted : string -> string
(** {!display} between double quotes, with every quote inside prefixed by a backslash. For values
    shown in human output where the boundaries matter (replacement texts of fixes). *)

val json_safe : string -> string
(** A quoted JSON string literal (RFC 8259). Backslash, quote and the dangerous set are written with
    JSON's own escapes: backslash, quote, [\n], [\r], [\t], [\uXXXX] (lowercase, surrogate pairs
    above U+FFFF); an invalid byte becomes U+FFFD. No raw code point of the dangerous set appears in
    the result and it is valid UTF-8, on one line. *)

val display_unit : Text.unit_ -> string * int
(** [display_unit u] is the {!display} form of one unit of a source excerpt and its width in
    terminal cells (East Asian wide characters and emoji take 2, combining marks 0: an approximation
    of [wcwidth]). Used by excerpt rendering so that carets stay aligned. *)

val neutralize : string -> string
(** Last-resort guard for the output layer ({!Output}): escapes the dangerous set and invalid bytes
    as {!display} does, but leaves LF (the line structure) and backslash alone, so that text which
    already went through {!display} is not escaped twice. Not an alternative to {!display}. *)
