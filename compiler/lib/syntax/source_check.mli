(** Whole-file checks performed on raw bytes before tokenising (LEX-001..003). *)

val check : file:string -> string -> Egide_diagnostics.Diagnostic.t list
(** Reports, anywhere in the file including comments and string literals:
    - invalid UTF-8 (E0001, LEX-001): one diagnostic per run of ill-formed bytes; overlong forms,
      surrogates and values above U+10FFFF are ill-formed. Each maximal ill-formed subpart counts as
      one column;
    - a leading byte-order mark (E0002, LEX-001);
    - a CR not followed by LF (E0003, LEX-002);
    - each forbidden code point (E0004, LEX-003), with its Unicode name when it is a well-known one,
      else its class.

    Never raises. HT is not reported here: it is legal in string literals and the lexer reports it
    elsewhere (E0005, LEX-004). *)

val is_forbidden : int -> bool
(** LEX-003: membership in the property-defined set of ADR-0017
    ([Egide_diagnostics.Forbidden_set.mem]), except LF, HT (LEX-004) and CR (LEX-002), which have
    their own rules. *)
