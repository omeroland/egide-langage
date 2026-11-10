type expect = Lex_pass | Lex_fail | Parse_pass | Parse_fail | Compile_fail | Run_pass | Run_panic
type backend = Interp | Go | Native
type diagnostic = { code : string; line : int; col : int }

type t = {
  spec : string list;
  expect : expect;
  diagnostics : diagnostic list;
  stdout : string list option;
  phase : int;
  backends : backend list;
}

let expect_to_string = function
  | Lex_pass -> "lex-pass"
  | Lex_fail -> "lex-fail"
  | Parse_pass -> "parse-pass"
  | Parse_fail -> "parse-fail"
  | Compile_fail -> "compile-fail"
  | Run_pass -> "run-pass"
  | Run_panic -> "run-panic"

let all_expects = [ Lex_pass; Lex_fail; Parse_pass; Parse_fail; Compile_fail; Run_pass; Run_panic ]
let expect_of_string s = List.find_opt (fun e -> expect_to_string e = s) all_expects
let backend_to_string = function Interp -> "interp" | Go -> "go" | Native -> "native"
let all_backends = [ Interp; Go; Native ]
let backend_of_string s = List.find_opt (fun b -> backend_to_string b = s) all_backends
let diagnostic_to_string d = Printf.sprintf "%s at %d:%d" d.code d.line d.col
let is_upper c = c >= 'A' && c <= 'Z'
let is_digit c = c >= '0' && c <= '9'
let all p s = s <> "" && String.for_all p s

(* spec/README.md: rule ids are PREFIX-NNN, e.g. LEX-012, CT-004. *)
let is_rule_id s =
  match String.index_opt s '-' with
  | Some i ->
      all is_upper (String.sub s 0 i)
      && String.length s - i - 1 = 3
      && all is_digit (String.sub s (i + 1) 3)
  | None -> false

(* `E0022`, `W0001`: one letter and four digits (docs/diagnostics.md). *)
let is_code s =
  String.length s = 5 && (s.[0] = 'E' || s.[0] = 'W') && all is_digit (String.sub s 1 4)

let positive s =
  match int_of_string_opt s with Some n when n >= 1 && all is_digit s -> Some n | _ -> None

let parse_diagnostic v =
  match String.split_on_char ' ' v |> List.filter (( <> ) "") with
  | [ code; "at"; pos ] when is_code code -> (
      match String.split_on_char ':' pos with
      | [ l; c ] -> (
          match (positive l, positive c) with
          | Some line, Some col -> Some { code; line; col }
          | _ -> None)
      | _ -> None)
  | _ -> None

let runner_keys = [ "spec"; "expect"; "diagnostic"; "stdout"; "phase"; "backends" ]

(* Keys of the leading comment block that belong to other tools: TOOL-011 script dependencies. *)
let other_keys = [ "requires" ]

(* A directive line is `# key:` with a lowercase key; returns the key and the raw value. *)
let directive line =
  let n = String.length line in
  if n >= 3 && line.[0] = '#' && line.[1] = ' ' then
    match String.index_opt line ':' with
    | Some i when i > 2 ->
        let key = String.sub line 2 (i - 2) in
        if String.for_all (fun c -> (c >= 'a' && c <= 'z') || c = '-') key && key.[0] <> '-' then
          Some (key, String.sub line (i + 1) (n - i - 1))
        else None
    | _ -> None
  else None

let strip_cr l =
  let n = String.length l in
  if n > 0 && l.[n - 1] = '\r' then String.sub l 0 (n - 1) else l

let parse ?stdout_file src =
  let bom = "\xEF\xBB\xBF" in
  let src =
    if String.starts_with ~prefix:bom src then String.sub src 3 (String.length src - 3) else src
  in
  let errors = ref [] in
  let error fmt = Printf.ksprintf (fun m -> errors := m :: !errors) fmt in
  let at = Printf.sprintf "line %d: " in
  let spec = ref [] and spec_seen = ref false and expect = ref None and expect_seen = ref false in
  let diagnostics = ref [] and stdout = ref [] and phase = ref None and phase_seen = ref false in
  let backends = ref None and backends_seen = ref false in
  let once seen ln key =
    if !seen then (
      error "%sduplicate `# %s:` header" (at ln) key;
      false)
    else (
      seen := true;
      true)
  in
  let in_header = ref true in
  String.split_on_char '\n' src
  |> List.iteri (fun i raw ->
      let ln = i + 1 and line = strip_cr raw in
      if !in_header && not (line = "" || line.[0] = '#') then in_header := false;
      match directive line with
      | None -> ()
      | Some (key, _) when not !in_header ->
          if List.mem key runner_keys then
            error "%s`# %s:` after the header block (headers must precede the first code line)"
              (at ln) key
      | Some (key, raw_value) -> (
          let v = String.trim raw_value in
          match key with
          | "spec" ->
              spec_seen := true;
              let ids =
                String.split_on_char ',' v
                |> List.concat_map (String.split_on_char ' ')
                |> List.filter (( <> ) "")
              in
              if ids = [] then error "%s`# spec:` cites no rule id" (at ln);
              List.iter
                (fun id ->
                  if not (is_rule_id id) then
                    error "%sinvalid rule id `%s` (expected PREFIX-NNN)" (at ln) id
                  else if not (List.mem id !spec) then spec := !spec @ [ id ])
                ids
          | "expect" ->
              if once expect_seen ln key then begin
                match expect_of_string v with
                | Some e -> expect := Some e
                | None ->
                    error
                      "%sunknown expectation `%s` (expected lex-pass, lex-fail, parse-pass, \
                       parse-fail, compile-fail, run-pass or run-panic)"
                      (at ln) v
              end
          | "diagnostic" -> (
              match parse_diagnostic v with
              | Some d -> diagnostics := d :: !diagnostics
              | None ->
                  error
                    "%smalformed diagnostic `%s` (expected `<code> at <line>:<col>`, e.g. `E0022 \
                     at 8:3`)"
                    (at ln) v)
          | "stdout" ->
              (* One expected line: drop the single space after the colon, keep the rest. *)
              let l =
                if String.starts_with ~prefix:" " raw_value then
                  String.sub raw_value 1 (String.length raw_value - 1)
                else raw_value
              in
              stdout := l :: !stdout
          | "phase" ->
              if once phase_seen ln key then begin
                match int_of_string_opt v with
                | Some p when p >= 0 && all is_digit v -> phase := Some p
                | _ -> error "%sinvalid phase `%s` (expected a non-negative integer)" (at ln) v
              end
          | "backends" ->
              ignore (once backends_seen ln key);
              let names =
                String.split_on_char ',' v |> List.map String.trim |> List.filter (( <> ) "")
              in
              if names = [] then error "%s`# backends:` lists no backend" (at ln);
              let bs =
                List.filter_map
                  (fun s ->
                    match backend_of_string s with
                    | Some b -> Some b
                    | None ->
                        error "%sunknown backend `%s` (expected interp, go or native)" (at ln) s;
                        None)
                  names
              in
              let dedup =
                List.fold_left (fun acc b -> if List.mem b acc then acc else acc @ [ b ]) [] bs
              in
              if !backends = None then backends := Some dedup
          | k when List.mem k other_keys -> ()
          | k ->
              error "%sunknown header `# %s:` (known: %s)" (at ln) k
                (String.concat ", " (runner_keys @ other_keys))));
  if not !spec_seen then error "missing `# spec:` header";
  if not !expect_seen then error "missing `# expect:` header";
  let diagnostics = List.rev !diagnostics and stdout_lines = List.rev !stdout in
  (match !expect with
  | None -> ()
  | Some e ->
      let is_fail = List.mem e [ Lex_fail; Parse_fail; Compile_fail ] in
      let is_run = List.mem e [ Run_pass; Run_panic ] in
      if is_fail && diagnostics = [] then
        error "`%s` requires at least one `# diagnostic:` header" (expect_to_string e);
      if (not is_fail) && diagnostics <> [] then
        error "`# diagnostic:` is only allowed with lex-fail, parse-fail or compile-fail";
      if e <> Run_pass && stdout_lines <> [] then error "`# stdout:` is only allowed with run-pass";
      if (not is_run) && !backends_seen then
        error "`# backends:` is only allowed with run-pass or run-panic";
      if e <> Run_pass && stdout_file <> None then
        error "a sibling .stdout file is only allowed with run-pass"
      else if stdout_lines <> [] && stdout_file <> None then
        error "both `# stdout:` headers and a sibling .stdout file; use one");
  match (!errors, !expect) with
  | [], Some expect ->
      let stdout =
        match stdout_file with
        | Some content -> Some (Text.lines content)
        | None -> if stdout_lines = [] then None else Some stdout_lines
      in
      Ok
        {
          spec = !spec;
          expect;
          diagnostics;
          stdout;
          phase = Option.value !phase ~default:0;
          backends = Option.value !backends ~default:all_backends;
        }
  | errors, _ -> Error (List.rev errors)
