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

let path_s p = String.concat "." p.segments

let expr_s = function
  | Int (s, _) -> Printf.sprintf "(int %s)" s
  | Float (s, _) -> Printf.sprintf "(float %s)" s
  | String (s, _) -> Printf.sprintf "(string %S)" s
  | Bool (b, _) -> Printf.sprintf "(bool %b)" b
  | Name p -> Printf.sprintf "(name %s)" (path_s p)

let item_s = function
  | Import { path; alias = None; _ } -> Printf.sprintf "(import %s)" (path_s path)
  | Import { path; alias = Some a; _ } -> Printf.sprintf "(import %s as %s)" (path_s path) a
  | Let { name; value; _ } -> Printf.sprintf "(let %s %s)" name (expr_s value)

let to_sexp f =
  String.concat "\n"
    ((Printf.sprintf "(module %s)" (path_s f.module_path)) :: List.map (fun i -> "  " ^ item_s i) f.items)
