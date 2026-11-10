type pos = { line : int; col : int }
type t = { file : string; start : pos; stop : pos }

let make ~file ~start ~stop = { file; start; stop }
let pos_of_lexing (p : Lexing.position) = { line = p.pos_lnum; col = p.pos_cnum - p.pos_bol + 1 }

let of_lexing (s : Lexing.position) (e : Lexing.position) =
  { file = s.pos_fname; start = pos_of_lexing s; stop = pos_of_lexing e }

let dummy = { file = "<none>"; start = { line = 0; col = 0 }; stop = { line = 0; col = 0 } }
let pp fmt s = Format.fprintf fmt "%s:%d:%d" s.file s.start.line s.start.col
let to_string s = Format.asprintf "%a" pp s
