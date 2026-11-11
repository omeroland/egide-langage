(** Text helpers for rendering diagnostics: lenient UTF-8 decoding and display width. Internal to
    [egide.diagnostics]. Escaping lives in {!Escape} and nowhere else (LEX-006). *)

(** One unit of source text: a Unicode scalar value, or a byte that is not part of a valid UTF-8
    sequence. Each unit is one column, as in [Source_check] (LEX-001 reports invalid bytes one by
    one). *)
type unit_ = Scalar of int | Byte of int

val decode : string -> int -> unit_ * int
(** [decode s i] is the unit starting at byte offset [i] of [s] and its length in bytes. *)

val units : string -> unit_ list
(** All units of a string, in order. *)

val cells : int -> int
(** Width in terminal cells of a printable scalar value: East Asian wide characters and emoji take
    2, combining marks 0, everything else 1 (an approximation of [wcwidth]). *)
