(** The code points of the LEX-003 set, behind a narrow interface (T-1039).

    {b PROVISIONAL.} Until T-1033 lands the property-defined set (Cf ∪ Default_Ignorable_Code_Point
    ∪ Variation_Selector ∪ noncharacters ∪ \{U+2028, U+2029\} ∪ Cc, from a pinned Unicode 16.0.0
    table), this module holds a hand-written approximation that errs on the side of escaping more:
    all of [Cc], U+2028/2029, the known [Cf] characters, the bidirectional controls, the reviewer's
    gap list of ADR-0017 (U+17B4/17B5, U+2065, U+FFF0..FFF8, U+E0000..E0FFF), variation selectors,
    Hangul fillers, the combining grapheme joiner and the noncharacters. Over-escaping is safe for
    output (LEX-006); under-escaping is not.

    T-1033 replaces the body of {!mem} with a lookup in its generated table and sets {!provisional}
    to [false]; nothing else changes. A test fails when {!provisional} is still [true] once phase 1
    has started or T-1033 is in [tasks/done/]. *)

val provisional : bool
(** [true] while {!mem} is the hand-written approximation. *)

val mem : int -> bool
(** [mem cp] is [true] when [cp] is in the LEX-003 set (tab and LF included: output escaping does
    not distinguish string literals). *)
