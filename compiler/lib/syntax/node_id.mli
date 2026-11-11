(** Unique identifiers of AST nodes (docs/architecture.md §2, invariants 3 to 5).

    Later passes (resolve, types, HIR lowering) never mutate the tree: they annotate it in side
    tables keyed by [Node_id.t]. Spans cannot serve as keys because they are not unique (an
    expression statement and its expression share one span, so do a binding pattern and its
    identifier).

    An id is only meaningful together with the tree it was allocated for. Ids are allocated from an
    explicit {!Gen.t} (no global state, invariant 5) in the order the parser builds the nodes, so
    the same source and the same generator state always give the same ids (invariant 4). Allocating
    from one generator for several files makes ids unique across them; the default of {!Parse.file}
    is a fresh generator per file, so ids are then unique within one file only and a table over
    several files is keyed by (file, id). *)

type t
(** An opaque identifier. Not an index into anything: only equality, ordering and hashing are
    meaningful. *)

val equal : t -> t -> bool
val compare : t -> t -> int
val hash : t -> int

val to_int : t -> int
(** The allocation number, for debugging output and for dense arrays owned by the pass that created
    the generator. *)

val pp : Format.formatter -> t -> unit
(** Prints [#n]. *)

(** Id allocation. *)
module Gen : sig
  type id := t

  type t
  (** A mutable counter. One per parse context. *)

  val create : unit -> t
  (** A generator whose first id is [#0]. *)

  val fresh : t -> id
  (** The next id: strictly greater (in {!compare}) than every id this generator returned before. *)

  val count : t -> int
  (** The number of ids allocated so far. *)
end
