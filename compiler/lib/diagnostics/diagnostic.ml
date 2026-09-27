type severity = Error | Warning

type t = {
  code : string;
  severity : severity;
  rule : string option;
  message : string;
  span : Egide_source.Span.t;
  notes : string list;
}

let error ?rule ?(notes = []) ~code span message =
  { code; severity = Error; rule; message; span; notes }

let warning ?rule ?(notes = []) ~code span message =
  { code; severity = Warning; rule; message; span; notes }

let severity_to_string = function Error -> "error" | Warning -> "warning"

let to_human d =
  let rule = match d.rule with Some r -> Printf.sprintf " (%s)" r | None -> "" in
  let head =
    Printf.sprintf "%s: %s[%s]: %s%s"
      (Egide_source.Span.to_string d.span)
      (severity_to_string d.severity) d.code d.message rule
  in
  String.concat "\n" (head :: List.map (fun n -> "  note: " ^ n) d.notes)

let json_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\t' -> Buffer.add_string b "\\t"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let json_pos (p : Egide_source.Span.pos) = Printf.sprintf {|{"line":%d,"col":%d}|} p.line p.col

let to_json d =
  let open Egide_source.Span in
  Printf.sprintf {|{"code":%s,"severity":%s,"rule":%s,"message":%s,"span":{"file":%s,"start":%s,"end":%s},"notes":[%s]}|}
    (json_string d.code)
    (json_string (severity_to_string d.severity))
    (match d.rule with Some r -> json_string r | None -> "null")
    (json_string d.message) (json_string d.span.file) (json_pos d.span.start) (json_pos d.span.stop)
    (String.concat "," (List.map json_string d.notes))

module Sink = struct
  type diag = t
  type nonrec t = { mutable rev : diag list }

  let create () = { rev = [] }
  let report s d = s.rev <- d :: s.rev
  let to_list s = List.rev s.rev
  let has_errors s = List.exists (fun d -> d.severity = Error) s.rev
end
