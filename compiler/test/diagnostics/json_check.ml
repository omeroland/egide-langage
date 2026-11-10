(* Test-only JSON parser and JSON Schema validator for the subset of draft 2020-12 used by
   docs/diagnostics.schema.json. Unknown schema keywords are rejected, so the schema cannot grow a
   constraint that this test silently ignores. *)

type json =
  | Null
  | Bool of bool
  | Num of float
  | Str of string
  | Arr of json list
  | Obj of (string * json) list

exception Parse_error of string

(* ---- Parser (RFC 8259) ---- *)

let parse (s : string) : json =
  let n = String.length s in
  let i = ref 0 in
  let fail msg = raise (Parse_error (Printf.sprintf "%s at byte %d" msg !i)) in
  let peek () = if !i < n then s.[!i] else '\000' in
  let rec ws () =
    if !i < n && (s.[!i] = ' ' || s.[!i] = '\n' || s.[!i] = '\t' || s.[!i] = '\r') then (
      incr i;
      ws ())
  in
  let expect c = if peek () = c then incr i else fail (Printf.sprintf "expected %C" c) in
  let lit word v =
    if !i + String.length word <= n && String.sub s !i (String.length word) = word then (
      i := !i + String.length word;
      v)
    else fail "bad literal"
  in
  let hex4 () =
    if !i + 4 > n then fail "short \\u escape";
    let v = int_of_string_opt ("0x" ^ String.sub s !i 4) in
    i := !i + 4;
    match v with Some v -> v | None -> fail "bad \\u escape"
  in
  let str () =
    expect '"';
    let b = Buffer.create 16 in
    let rec go () =
      if !i >= n then fail "unterminated string";
      let c = s.[!i] in
      incr i;
      match c with
      | '"' -> ()
      | '\\' ->
          let e = peek () in
          incr i;
          (match e with
          | '"' -> Buffer.add_char b '"'
          | '\\' -> Buffer.add_char b '\\'
          | '/' -> Buffer.add_char b '/'
          | 'b' -> Buffer.add_char b '\b'
          | 'f' -> Buffer.add_char b '\012'
          | 'n' -> Buffer.add_char b '\n'
          | 'r' -> Buffer.add_char b '\r'
          | 't' -> Buffer.add_char b '\t'
          | 'u' ->
              let u = hex4 () in
              let u =
                if u >= 0xD800 && u <= 0xDBFF then (
                  expect '\\';
                  expect 'u';
                  let lo = hex4 () in
                  if lo < 0xDC00 || lo > 0xDFFF then fail "bad surrogate pair";
                  0x10000 + ((u - 0xD800) lsl 10) + (lo - 0xDC00))
                else if u >= 0xDC00 && u <= 0xDFFF then fail "lone low surrogate"
                else u
              in
              Buffer.add_utf_8_uchar b (Uchar.of_int u)
          | _ -> fail "bad escape");
          go ()
      | c when Char.code c < 0x20 -> fail "raw control character in string"
      | c ->
          Buffer.add_char b c;
          go ()
    in
    go ();
    let r = Buffer.contents b in
    if not (String.is_valid_utf_8 r) then fail "string is not valid UTF-8";
    r
  in
  let num () =
    let start = !i in
    let is_num c = match c with '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' -> true | _ -> false in
    while !i < n && is_num s.[!i] do
      incr i
    done;
    match float_of_string_opt (String.sub s start (!i - start)) with
    | Some f -> f
    | None -> fail "bad number"
  in
  let rec value () =
    ws ();
    let v =
      match peek () with
      | '{' ->
          incr i;
          ws ();
          if peek () = '}' then (
            incr i;
            Obj [])
          else
            let rec members acc =
              ws ();
              let k = str () in
              ws ();
              expect ':';
              let v = value () in
              ws ();
              match peek () with
              | ',' ->
                  incr i;
                  members ((k, v) :: acc)
              | '}' ->
                  incr i;
                  Obj (List.rev ((k, v) :: acc))
              | _ -> fail "expected , or }"
            in
            members []
      | '[' ->
          incr i;
          ws ();
          if peek () = ']' then (
            incr i;
            Arr [])
          else
            let rec elems acc =
              let v = value () in
              ws ();
              match peek () with
              | ',' ->
                  incr i;
                  elems (v :: acc)
              | ']' ->
                  incr i;
                  Arr (List.rev (v :: acc))
              | _ -> fail "expected , or ]"
            in
            elems []
      | '"' -> Str (str ())
      | 't' -> lit "true" (Bool true)
      | 'f' -> lit "false" (Bool false)
      | 'n' -> lit "null" Null
      | '-' | '0' .. '9' -> Num (num ())
      | _ -> fail "unexpected character"
    in
    ws ();
    v
  in
  let v = value () in
  if !i <> n then fail "trailing data";
  v

(* ---- Regex subset for "pattern": literals, [..] classes with ranges, ( | ), ? * + {n} {n,m},
   ^ and $ anchors. Backtracking matcher; enough for the schema's patterns. ---- *)

type re =
  | Chr of char
  | Cls of (char * char) list
  | Seq of re list
  | Alt of re list
  | Rep of re * int * int option
  | Bol
  | Eol

let parse_re (p : string) : re =
  let n = String.length p in
  let i = ref 0 in
  let fail () = failwith ("unsupported regex: " ^ p) in
  let rec alt () =
    let first = seq () in
    let rec more acc =
      if !i < n && p.[!i] = '|' then (
        incr i;
        more (seq () :: acc))
      else List.rev acc
    in
    match more [ first ] with [ x ] -> x | xs -> Alt xs
  and seq () =
    let rec go acc =
      if !i >= n || p.[!i] = '|' || p.[!i] = ')' then Seq (List.rev acc)
      else go (quant (atom ()) :: acc)
    in
    go []
  and atom () =
    let c = p.[!i] in
    incr i;
    match c with
    | '^' -> Bol
    | '$' -> Eol
    | '(' ->
        let r = alt () in
        if !i < n && p.[!i] = ')' then incr i else fail ();
        r
    | '[' ->
        let rec go acc =
          if !i >= n then fail ()
          else if p.[!i] = ']' then (
            incr i;
            Cls acc)
          else
            let a = p.[!i] in
            if !i + 2 < n && p.[!i + 1] = '-' && p.[!i + 2] <> ']' then (
              i := !i + 3;
              go ((a, p.[!i - 1]) :: acc))
            else (
              incr i;
              go ((a, a) :: acc))
        in
        go []
    | '\\' | '.' | '*' | '+' | '?' | '{' -> fail ()
    | c -> Chr c
  and quant r =
    if !i >= n then r
    else
      match p.[!i] with
      | '?' ->
          incr i;
          Rep (r, 0, Some 1)
      | '*' ->
          incr i;
          Rep (r, 0, None)
      | '+' ->
          incr i;
          Rep (r, 1, None)
      | '{' -> (
          let close = String.index_from p !i '}' in
          let body = String.sub p (!i + 1) (close - !i - 1) in
          i := close + 1;
          match String.split_on_char ',' body with
          | [ a ] -> Rep (r, int_of_string a, Some (int_of_string a))
          | [ a; "" ] -> Rep (r, int_of_string a, None)
          | [ a; b ] -> Rep (r, int_of_string a, Some (int_of_string b))
          | _ -> fail ())
      | _ -> r
  in
  let r = alt () in
  if !i <> n then fail ();
  r

(* ECMA-262 "pattern" semantics: unanchored search; anchors are explicit. Operates on bytes, which is
   exact for the ASCII patterns of the schema. *)
let re_search (r : re) (s : string) : bool =
  let n = String.length s in
  let rec m r pos k =
    match r with
    | Chr c -> pos < n && s.[pos] = c && k (pos + 1)
    | Cls rs -> pos < n && List.exists (fun (a, b) -> s.[pos] >= a && s.[pos] <= b) rs && k (pos + 1)
    | Seq rs -> ( match rs with [] -> k pos | r :: rest -> m r pos (fun p -> m (Seq rest) p k))
    | Alt rs -> List.exists (fun r -> m r pos k) rs
    | Bol -> pos = 0 && k pos
    | Eol -> pos = n && k pos
    | Rep (r, lo, hi) ->
        let rec go count pos =
          (count >= lo && k pos)
          || (match hi with Some h -> count < h | None -> true)
             && m r pos (fun p -> p > pos && go (count + 1) p)
        in
        go 0 pos
  in
  let rec from pos = pos <= n && (m r pos (fun _ -> true) || from (pos + 1)) in
  from 0

(* ---- Schema validation ---- *)

let annotations = [ "$schema"; "$id"; "title"; "description"; "$comment"; "$defs" ]

let supported =
  [
    "type";
    "enum";
    "required";
    "properties";
    "additionalProperties";
    "items";
    "pattern";
    "minimum";
    "minLength";
    "minItems";
    "$ref";
  ]

let type_name = function
  | Null -> "null"
  | Bool _ -> "boolean"
  | Num f -> if Float.is_integer f then "integer" else "number"
  | Str _ -> "string"
  | Arr _ -> "array"
  | Obj _ -> "object"

let rec utf8_length s i acc =
  if i >= String.length s then acc
  else
    let d = String.get_utf_8_uchar s i in
    utf8_length s (i + Uchar.utf_decode_length d) (acc + 1)

(** [validate ~root schema v] returns the list of violations (empty when [v] is valid). Raises
    [Failure] on a schema keyword outside the supported subset. *)
let validate ~(root : json) (schema : json) (v : json) : string list =
  let errs = ref [] in
  let err path msg =
    errs := Printf.sprintf "%s: %s" (if path = "" then "/" else path) msg :: !errs
  in
  let resolve ref_ =
    let prefix = "#/$defs/" in
    if not (String.starts_with ~prefix ref_) then failwith ("unsupported $ref " ^ ref_);
    let name = String.sub ref_ (String.length prefix) (String.length ref_ - String.length prefix) in
    match root with
    | Obj kv -> (
        match List.assoc_opt "$defs" kv with
        | Some (Obj defs) -> (
            match List.assoc_opt name defs with
            | Some s -> s
            | None -> failwith ("dangling $ref " ^ ref_))
        | _ -> failwith "no $defs")
    | _ -> failwith "schema root is not an object"
  in
  let rec check path schema v =
    match schema with
    | Obj kws -> (
        List.iter
          (fun (k, _) ->
            if not (List.mem k annotations || List.mem k supported) then
              failwith ("unsupported schema keyword " ^ k))
          kws;
        let kw k = List.assoc_opt k kws in
        Option.iter
          (function Str r -> check path (resolve r) v | _ -> failwith "$ref must be a string")
          (kw "$ref");
        Option.iter
          (fun t ->
            let allowed =
              match t with
              | Str s -> [ s ]
              | Arr l -> List.map (function Str s -> s | _ -> "?") l
              | _ -> []
            in
            let actual = type_name v in
            let ok = List.mem actual allowed || (actual = "integer" && List.mem "number" allowed) in
            if not ok then
              err path
                (Printf.sprintf "expected type %s, got %s" (String.concat "|" allowed) actual))
          (kw "type");
        Option.iter
          (function
            | Arr opts -> if not (List.mem v opts) then err path "value not in enum"
            | _ -> failwith "enum")
          (kw "enum");
        (match v with
        | Obj fields ->
            Option.iter
              (function
                | Arr req ->
                    List.iter
                      (function
                        | Str f ->
                            if not (List.mem_assoc f fields) then
                              err path ("missing required property " ^ f)
                        | _ -> failwith "required")
                      req
                | _ -> failwith "required")
              (kw "required");
            let props =
              match kw "properties" with
              | Some (Obj p) -> p
              | None -> []
              | _ -> failwith "properties"
            in
            List.iter
              (fun (f, fv) ->
                match List.assoc_opt f props with
                | Some s -> check (path ^ "/" ^ f) s fv
                | None -> (
                    match kw "additionalProperties" with
                    | Some (Bool false) -> err path ("unexpected property " ^ f)
                    | None | Some (Bool true) -> ()
                    | Some _ -> failwith "additionalProperties"))
              fields
        | _ -> ());
        (match v with
        | Arr items ->
            Option.iter
              (fun s -> List.iteri (fun i x -> check (Printf.sprintf "%s/%d" path i) s x) items)
              (kw "items");
            Option.iter
              (function
                | Num k -> if float_of_int (List.length items) < k then err path "too few items"
                | _ -> failwith "minItems")
              (kw "minItems")
        | _ -> ());
        (match v with
        | Str s ->
            Option.iter
              (function
                | Str p ->
                    if not (re_search (parse_re p) s) then
                      err path (Printf.sprintf "%S does not match %s" s p)
                | _ -> failwith "pattern")
              (kw "pattern");
            Option.iter
              (function
                | Num k -> if float_of_int (utf8_length s 0 0) < k then err path "string too short"
                | _ -> failwith "minLength")
              (kw "minLength")
        | _ -> ());
        match v with
        | Num f ->
            Option.iter
              (function Num k -> if f < k then err path "below minimum" | _ -> failwith "minimum")
              (kw "minimum")
        | _ -> ())
    | Bool true -> ()
    | Bool false -> err path "schema false"
    | _ -> failwith "schema must be an object or boolean"
  in
  check "" schema v;
  List.rev !errs

let schema_path = "../../../docs/diagnostics.schema.json"
let load_schema () = parse (In_channel.with_open_bin schema_path In_channel.input_all)
