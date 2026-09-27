(** Abstract syntax tree. Seed subset: module declaration, imports and top-level [let] of simple
    expressions. T-0008 extends it to the complete grammar of spec/grammar/egide.ebnf. *)

type span = Egide_source.Span.t
type path = { segments : string list; span : span }

type expr =
  | Int of string * span
  | Float of string * span
  | String of string * span
  | Bool of bool * span
  | Name of path

type item =
  | Import of { path : path; alias : string option; span : span }
  | Let of { name : string; value : expr; span : span }

type file = { module_path : path; items : item list }

val to_sexp : file -> string
(** Stable S-expression rendering used by [egide parse] and snapshot tests (unstable for users). *)
