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
    several files is keyed by (file, id).

    {b Ids need not be contiguous.} A parse that fails ([None]), error recovery (T-0013) and
    cover-grammar conversions (SYN-065, a parsed expression reinterpreted as lambda parameters) all
    discard nodes whose ids were already allocated. Rely only on uniqueness and on
    [to_int id < Gen.count g] (so [Gen.count] sizes a dense array that can hold every id, with
    holes), never on "every number below the count is used".

    {b Not domain-safe.} A {!Gen.t} is a plain mutable counter: [fresh] is a non-atomic
    read-modify-write. Two parses sharing one generator on different [Domain]s can hand out the same
    id, and even without a race the numbering would depend on scheduling (invariant 4). Share a
    generator only within one domain, parsing files in a fixed order; otherwise use one generator
    per file and key tables on (file, id).

    {b Not persistable.} Ids depend on the grammar (the order in which productions are reduced), not
    only on the source: changing a production renumbers everything. They are valid for one compiler
    build and one in-memory tree; never write them to a cache, a lockfile or a snapshot. *)

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
