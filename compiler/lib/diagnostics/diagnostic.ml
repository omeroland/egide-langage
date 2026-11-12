module Span = Egide_source.Span

type severity = Error | Warning
type label = { span : Span.t; message : string }
type edit = { span : Span.t; replacement : string }
type fix = { message : string; edits : edit list }

(* Defined last so that unannotated [d.span] / [d.message] resolve to [t]. *)
type t = {
  code : string;
  severity : severity;
  rule : string option;
  message : string;
  span : Span.t;
  labels : label list;
  notes : string list;
  fixes : fix list;
}

(* ---- Construction (TOOL-040). Violations are compiler bugs, hence Invalid_argument. ---- *)

let bug fmt = Printf.ksprintf (fun m -> invalid_arg ("Diagnostic: " ^ m)) fmt
let is_digit c = c >= '0' && c <= '9'
let is_upper c = c >= 'A' && c <= 'Z'

let valid_code c =
  c = "ICE"
  || String.length c = 5
     && (c.[0] = 'E' || c.[0] = 'W')
     && String.for_all is_digit (String.sub c 1 4)

(* Rule ids are [A-Z]+-[0-9]{3}, e.g. LEX-032 (every id in spec/ has this shape). *)
let valid_rule r =
  match String.index_opt r '-' with
  | Some i when i > 0 ->
      let digits = String.sub r (i + 1) (String.length r - i - 1) in
      String.for_all is_upper (String.sub r 0 i)
      && String.length digits = 3
      && String.for_all is_digit digits
  | _ -> false

let make severity ~rule ?(labels = []) ?(notes = []) ?(fixes = []) ~code span message =
  if not (valid_code code) then bug "malformed code %S" code;
  (match (severity, code.[0]) with
  | Error, 'W' -> bug "an error needs an E code, got %S" code
  | Warning, ('E' | 'I') -> bug "a warning needs a W code, got %S" code
  | _ -> ());
  if not (valid_rule rule) then bug "malformed rule id %S" rule;
  if message = "" then bug "empty message";
  if List.mem "" notes then bug "empty note";
  List.iter
    (fun (f : fix) ->
      if f.message = "" then bug "empty fix message";
      if f.edits = [] then bug "fix %S has no edits" f.message)
    fixes;
  { code; severity; rule = Some rule; message; span; labels; notes; fixes }

let error = make Error
let warning = make Warning
let label span message : label = { span; message }
let edit span replacement : edit = { span; replacement }
let fix message edits : fix = { message; edits }
let severity_to_string = function Error -> "error" | Warning -> "warning"

(* ---- Human rendering ---- *)

let loc (s : Span.t) = Printf.sprintf "%s:%d:%d" (Escape.display s.file) s.start.line s.start.col

let header d =
  let rule = match d.rule with Some r -> Printf.sprintf " (%s)" r | None -> "" in
  Printf.sprintf "%s: %s[%s]: %s%s" (loc d.span) (severity_to_string d.severity) d.code
    (Escape.display d.message) rule

let location_line (l : label) =
  if l.message = "" then "  --> " ^ loc l.span
  else Printf.sprintf "  --> %s: %s" (loc l.span) (Escape.display l.message)

let edit_line (e : edit) =
  let s = e.span in
  let where =
    if s.start = s.stop then loc s else Printf.sprintf "%s-%d:%d" (loc s) s.stop.line s.stop.col
  in
  let action =
    if s.start = s.stop then "insert " ^ Escape.display_quoted e.replacement
    else if e.replacement = "" then "delete"
    else "replace with " ^ Escape.display_quoted e.replacement
  in
  Printf.sprintf "    %s: %s" where action

(* A source line prepared for display: its rendered text and, for each scalar column, its starting
   display cell (0-based). Columns past the end of the line are virtual spaces. *)
type line = { text : string; cells : int array }

let prepare_line raw =
  let units = Text.units raw in
  let n = List.length units in
  let cells = Array.make (n + 1) 0 in
  let b = Buffer.create (String.length raw) in
  List.iteri
    (fun i u ->
      let s, w = Escape.display_unit u in
      Buffer.add_string b s;
      cells.(i + 1) <- cells.(i) + w)
    units;
  { text = Buffer.contents b; cells }

let length l = Array.length l.cells - 1

let cell l col =
  if col - 1 <= length l then l.cells.(max 0 (col - 1))
  else l.cells.(length l) + (col - 1 - length l)

let first_non_blank l =
  let rec go i = if i >= String.length l.text || l.text.[i] <> ' ' then i + 1 else go (i + 1) in
  min (go 0) (length l + 1)

(* LEX-002: CR LF is a line end; a lone CR stays in the line and is displayed escaped. *)
let split_lines src =
  String.split_on_char '\n' src
  |> List.map (fun l ->
      let n = String.length l in
      if n > 0 && l.[n - 1] = '\r' then String.sub l 0 (n - 1) else l)
  |> Array.of_list

(* A marked range on one line, in scalar columns [c0, c1). *)
type mark = { line : int; c0 : int; c1 : int; primary : bool; msg : string }

(* Multi-line spans longer than this many lines only show their first and last lines. *)
let max_span_lines = 4

(* The marks of [span] in [lines], or [None] if the span does not fit in the source (a stale or
   malformed span is listed as a location rather than drawn, which also bounds the marker width). *)
let marks_of lines ~primary (span : Span.t) msg =
  let n = Array.length lines in
  let a = span.start.line and b0 = span.stop.line in
  let line k = prepare_line lines.(k - 1) in
  let fits k col = col >= 1 && col <= length (line k) + 1 in
  if
    a < 1 || a > n || b0 < a || b0 > n
    || (b0 = a && span.stop.col < span.start.col)
    || (not (fits a span.start.col))
    || not (fits b0 span.stop.col)
  then None
  else
    (* A span ending at column 1 of a later line ends at the end of the previous line. *)
    let b, stop_col =
      if b0 > a && span.stop.col <= 1 then (b0 - 1, length (line (b0 - 1)) + 1)
      else (b0, span.stop.col)
    in
    let mk k c0 c1 =
      { line = k; c0; c1 = max c1 (c0 + 1); primary; msg = (if k = b then msg else "") }
    in
    if a = b then Some [ mk a span.start.col stop_col ]
    else
      let first = mk a span.start.col (length (line a) + 1) in
      let last =
        let l = line b in
        let c0 = min (first_non_blank l) (max 1 (stop_col - 1)) in
        mk b c0 stop_col
      in
      let middle =
        if b - a + 1 > max_span_lines then []
        else
          List.init (b - a - 1) (fun i -> a + 1 + i)
          |> List.filter_map (fun k ->
              let l = line k in
              if length l = 0 then None else Some (mk k (first_non_blank l) (length l + 1)))
      in
      Some ((first :: middle) @ [ last ])

let rtrim s =
  let n = ref (String.length s) in
  while !n > 0 && s.[!n - 1] = ' ' do
    decr n
  done;
  String.sub s 0 !n

(* Render one excerpt block: the source lines touched by [marks] with their marker lines. *)
let render_block buf lines marks =
  let out s = Buffer.add_string buf (rtrim s ^ "\n") in
  let shown = List.sort_uniq compare (List.map (fun m -> m.line) marks) in
  (* Show a single skipped line rather than an ellipsis standing for one line. *)
  let rec fill = function
    | x :: (y :: _ as rest) -> if y - x = 2 then x :: (x + 1) :: fill rest else x :: fill rest
    | l -> l
  in
  let shown = fill shown in
  let w = String.length (string_of_int (List.fold_left max 0 shown)) in
  let pad = String.make (w + 1) ' ' in
  out (pad ^ "|");
  ignore
    (List.fold_left
       (fun prev k ->
         if prev > 0 && k - prev > 1 then out "...";
         let l = prepare_line lines.(k - 1) in
         out (Printf.sprintf "%*d | %s" w k l.text);
         let ms = List.filter (fun m -> m.line = k) marks in
         if ms <> [] then begin
           let span_cells m =
             let s = cell l m.c0 in
             (s, max (cell l m.c1) (s + 1))
           in
           let width = List.fold_left (fun acc m -> max acc (snd (span_cells m))) 0 ms in
           let marker = Bytes.make width ' ' in
           let paint m =
             let s, e = span_cells m in
             Bytes.fill marker s (e - s) (if m.primary then '^' else '-')
           in
           (* Primary marks are painted last so they stay visible over overlapping labels. *)
           List.iter paint (List.filter (fun m -> not m.primary) ms);
           List.iter paint (List.filter (fun m -> m.primary) ms);
           let labelled =
             List.filter (fun m -> m.msg <> "") ms
             |> List.map (fun m -> (fst (span_cells m), snd (span_cells m), Escape.display m.msg))
             |> List.stable_sort (fun (s1, _, _) (s2, _, _) -> compare s1 s2)
           in
           let inline, stacked =
             match List.rev labelled with
             | (_, e, msg) :: rest when e >= width -> (" " ^ msg, List.rev rest)
             | _ -> ("", labelled)
           in
           out (pad ^ "| " ^ Bytes.to_string marker ^ inline);
           if stacked <> [] then begin
             let bars upto =
               let b = Bytes.make width ' ' in
               List.iteri (fun i (s, _, _) -> if i < upto then Bytes.set b s '|') stacked;
               Bytes.to_string b
             in
             let k = List.length stacked in
             out (pad ^ "| " ^ bars k);
             (* Rightmost first: each message at its own column, keeping the bars of the labels to its left. *)
             List.iteri
               (fun j (s, _, msg) -> out (pad ^ "| " ^ String.sub (bars (k - 1 - j)) 0 s ^ msg))
               (List.rev stacked)
           end
         end;
         k)
       0 shown)

let render ~sources d =
  let buf = Buffer.create 256 in
  Buffer.add_string buf (header d ^ "\n");
  let cache = ref [] in
  let lines file =
    match List.assoc_opt file !cache with
    | Some l -> l
    | None ->
        let l = Option.map split_lines (sources file) in
        cache := (file, l) :: !cache;
        l
  in
  let marks_in (span : Span.t) ~primary msg =
    Option.bind (lines span.file) (fun ls -> marks_of ls ~primary span msg)
  in
  (* Blocks in order of first appearance of their file, primary file first. *)
  let blocks = ref [] and fallbacks = ref [] in
  let add file ms =
    match List.assoc_opt file !blocks with
    | Some r -> r := !r @ ms
    | None -> blocks := !blocks @ [ (file, ref ms) ]
  in
  let primary_shown =
    match marks_in d.span ~primary:true "" with
    | Some ms ->
        add d.span.file ms;
        true
    | None -> false
  in
  List.iter
    (fun (l : label) ->
      match marks_in l.span ~primary:false l.message with
      | Some ms -> add l.span.file ms
      | None -> fallbacks := !fallbacks @ [ l ])
    d.labels;
  List.iteri
    (fun i (file, ms) ->
      if not (i = 0 && primary_shown) then
        Buffer.add_string buf ("  --> " ^ Escape.display file ^ "\n");
      match lines file with Some ls -> render_block buf ls !ms | None -> ())
    !blocks;
  List.iter (fun l -> Buffer.add_string buf (location_line l ^ "\n")) !fallbacks;
  List.iter (fun n -> Buffer.add_string buf ("  note: " ^ Escape.display n ^ "\n")) d.notes;
  List.iter
    (fun (f : fix) ->
      Buffer.add_string buf ("  help: " ^ Escape.display f.message ^ "\n");
      List.iter (fun e -> Buffer.add_string buf (edit_line e ^ "\n")) f.edits)
    d.fixes;
  let s = Buffer.contents buf in
  String.sub s 0 (String.length s - 1)

let render_human = render
let to_human d = render ~sources:(fun _ -> None) d

(* ---- JSON (TOOL-042, docs/diagnostics.schema.json) ---- *)

let json_span (s : Span.t) =
  let pos (p : Span.pos) = Printf.sprintf {|{"line":%d,"col":%d}|} p.line p.col in
  Printf.sprintf {|{"file":%s,"start":%s,"end":%s}|} (Escape.json_safe s.file) (pos s.start)
    (pos s.stop)

let json_list f l = "[" ^ String.concat "," (List.map f l) ^ "]"

let to_json d =
  let label (l : label) =
    Printf.sprintf {|{"span":%s,"message":%s}|} (json_span l.span) (Escape.json_safe l.message)
  in
  let edit (e : edit) =
    Printf.sprintf {|{"span":%s,"replacement":%s}|} (json_span e.span)
      (Escape.json_safe e.replacement)
  in
  let fix (f : fix) =
    Printf.sprintf {|{"message":%s,"edits":%s}|} (Escape.json_safe f.message)
      (json_list edit f.edits)
  in
  Printf.sprintf
    {|{"code":%s,"severity":%s,"rule":%s,"message":%s,"span":%s,"labels":%s,"notes":%s,"fixes":%s}|}
    (Escape.json_safe d.code)
    (Escape.json_safe (severity_to_string d.severity))
    (match d.rule with Some r -> Escape.json_safe r | None -> "null")
    (Escape.json_safe d.message) (json_span d.span) (json_list label d.labels)
    (json_list Escape.json_safe d.notes)
    (json_list fix d.fixes)

module Sink = struct
  type diag = t

  (* T-1080: [limit] bounds what is stored, not only what is printed. Past the limit a report costs O(1)
     time and memory: a counter, the span of the first dropped diagnostic and the "an error was dropped"
     flag (so [has_errors] stays true whatever the limit). *)
  type nonrec t = {
    limit : int;
    mutable kept : int;
    mutable rev : diag list;
    mutable suppressed : int;
    mutable first_suppressed : Span.t option;
    mutable errors : bool;
    by_class : int array;  (** dropped diagnostics per security-relevant code, see [classes] *)
  }

  (* T-1080 (security review of PR #36): codes whose suppression a reader of the output must be able to see,
     because they carry the Trojan Source / encoding attacks of ch. 2. Fixed order = fixed text. *)
  let classes = [| "E0001"; "E0002"; "E0003"; "E0004" |]

  let class_index code =
    let rec go i =
      if i >= Array.length classes then -1 else if classes.(i) = code then i else go (i + 1)
    in
    go 0

  let default_limit = 100

  let create ?(limit = max_int) () =
    if limit < 1 then invalid_arg "Diagnostic.Sink.create: limit must be at least 1";
    {
      limit;
      kept = 0;
      rev = [];
      suppressed = 0;
      first_suppressed = None;
      errors = false;
      by_class = Array.make (Array.length classes) 0;
    }

  let report s d =
    if d.severity = Error then s.errors <- true;
    if s.kept < s.limit then begin
      s.rev <- d :: s.rev;
      s.kept <- s.kept + 1
    end
    else begin
      s.suppressed <- s.suppressed + 1;
      let k = class_index d.code in
      if k >= 0 then s.by_class.(k) <- s.by_class.(k) + 1;
      if s.first_suppressed = None then s.first_suppressed <- Some d.span
    end

  let suppressed s = s.suppressed
  let has_errors s = s.errors

  (* E0006 (docs/diagnostics.md): fixed text, integers only, no source echo. The per-class counts name the
     security-relevant codes among the dropped ones, e.g. "(limit 100 per file; E0004: 3)". *)
  let summary s =
    match s.first_suppressed with
    | None -> []
    | Some span ->
        let per_class =
          Array.to_list classes
          |> List.mapi (fun i c -> (c, s.by_class.(i)))
          |> List.filter (fun (_, k) -> k > 0)
          |> List.map (fun (c, k) -> Printf.sprintf "; %s: %d" c k)
          |> String.concat ""
        in
        [
          error ~rule:"TOOL-040" ~code:"E0006" span
            (Printf.sprintf "%d further %s suppressed (limit %d per file%s)" s.suppressed
               (if s.suppressed = 1 then "diagnostic" else "diagnostics")
               s.limit per_class);
        ]

  let to_list s = List.rev_append s.rev (summary s)
end
