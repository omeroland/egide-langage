(** Text helpers for rendering diagnostics: lenient UTF-8 decoding, terminal-safe display and JSON
    string escaping. Internal to [egide.diagnostics]. *)

(** One unit of source text: a Unicode scalar value, or a byte that is not part of a valid UTF-8
    sequence. Each unit is one column, as in [Source_check] (LEX-001 reports invalid bytes one by one). *)
type unit_ = Scalar of int | Byte of int

val decode : string -> int -> unit_ * int
(** [decode s i] is the unit starting at byte offset [i] of [s] and its length in bytes. *)

val units : string -> unit_ list
(** All units of a string, in order. *)

val is_unsafe : int -> bool
(** Code points that must never reach a terminal raw: the characters forbidden by LEX-003
    (bidirectional controls, zero-width and invisible characters, line and paragraph separators, all
    of category [Cc] including tab and LF). Printing them would let a diagnostic replay the attack it
    reports (Trojan Source). *)

val display : unit_ -> string * int
(** Terminal rendering of a unit in a source excerpt and its width in cells: tab becomes 4 spaces,
    unsafe code points become [<U+XXXX>], invalid bytes [<0xNN>]; East Asian wide characters and
    emoji take 2 cells, combining marks 0 (an approximation of [wcwidth]). *)

val sanitize : string -> string
(** One-line, terminal-safe copy of free text (messages, notes, file names): every unsafe code point,
    including tab and LF, becomes [<U+XXXX>] and every invalid byte [<0xNN>]. *)

val json_string : string -> string
(** A quoted JSON string literal. The result is always valid UTF-8: invalid bytes become U+FFFD.
    Control characters and the other unsafe code points are [\u]-escaped. *)
