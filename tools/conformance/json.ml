type t =
  | Null
  | Bool of bool
  | Number of float
  | String of string
  | Array of t list
  | Object of (string * t) list

exception Parse_error of string * int

let parse s =
  let n = String.length s in
  let pos = ref 0 in
  let err msg = raise (Parse_error (msg, !pos)) in
  let peek () = if !pos < n then Some s.[!pos] else None in
  let rec skip_ws () =
    match peek () with
    | Some (' ' | '\t' | '\n' | '\r') ->
        incr pos;
        skip_ws ()
    | _ -> ()
  in
  let expect c =
    skip_ws ();
    if peek () = Some c then incr pos
    else if !pos >= n then err "unexpected end of input"
    else err (Printf.sprintf "expected '%c'" c)
  in
  let hex4 () =
    if !pos + 4 > n then err "unexpected end of input";
    match int_of_string_opt ("0x" ^ String.sub s !pos 4) with
    | Some v ->
        pos := !pos + 4;
        v
    | None -> err "invalid escape"
  in
  let string () =
    incr pos;
    let b = Buffer.create 16 in
    let rec go () =
      match peek () with
      | None -> err "unexpected end of input"
      | Some '"' -> incr pos
      | Some '\\' ->
          incr pos;
          let esc_pos = !pos in
          (match peek () with
          | Some (('"' | '\\' | '/') as c) -> incr pos; Buffer.add_char b c
          | Some 'n' -> incr pos; Buffer.add_char b '\n'
          | Some 't' -> incr pos; Buffer.add_char b '\t'
          | Some 'r' -> incr pos; Buffer.add_char b '\r'
          | Some 'b' -> incr pos; Buffer.add_char b '\b'
          | Some 'f' -> incr pos; Buffer.add_char b '\012'
          | Some 'u' ->
              incr pos;
              let u = hex4 () in
              let cp =
                if u >= 0xD800 && u <= 0xDBFF
                   && !pos + 6 <= n && s.[!pos] = '\\' && s.[!pos + 1] = 'u'
                then begin
                  pos := !pos + 2;
                  let lo = hex4 () in
                  if lo < 0xDC00 || lo > 0xDFFF then
                    raise (Parse_error ("unpaired surrogate", esc_pos - 1));
                  0x10000 + ((u - 0xD800) lsl 10) + (lo - 0xDC00)
                end
                else if u >= 0xD800 && u <= 0xDFFF then
                  raise (Parse_error ("unpaired surrogate", esc_pos - 1))
                else u
              in
              Buffer.add_utf_8_uchar b (Uchar.of_int cp)
          | _ -> raise (Parse_error ("invalid escape", esc_pos)));
          go ()
      | Some c ->
          incr pos;
          Buffer.add_char b c;
          go ()
    in
    go ();
    Buffer.contents b
  in
  let number () =
    let start = !pos in
    let is_num_char = function '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' -> true | _ -> false in
    while !pos < n && is_num_char s.[!pos] do incr pos done;
    match float_of_string_opt (String.sub s start (!pos - start)) with
    | Some f -> Number f
    | None -> raise (Parse_error ("invalid number", start))
  in
  let literal word v =
    let l = String.length word in
    if !pos + l <= n && String.sub s !pos l = word then begin
      pos := !pos + l;
      v
    end
    else err "invalid literal"
  in
  let rec value () =
    skip_ws ();
    match peek () with
    | None -> err "unexpected end of input"
    | Some '{' ->
        incr pos;
        skip_ws ();
        if peek () = Some '}' then (incr pos; Object [])
        else
          let rec fields acc =
            skip_ws ();
            if peek () <> Some '"' then
              if !pos >= n then err "unexpected end of input" else err "expected string";
            let k = string () in
            expect ':';
            let v = value () in
            skip_ws ();
            match peek () with
            | Some ',' -> incr pos; fields ((k, v) :: acc)
            | Some '}' -> incr pos; Object (List.rev ((k, v) :: acc))
            | None -> err "unexpected end of input"
            | Some _ -> err "expected ',' or '}'"
          in
          fields []
    | Some '[' ->
        incr pos;
        skip_ws ();
        if peek () = Some ']' then (incr pos; Array [])
        else
          let rec items acc =
            let v = value () in
            skip_ws ();
            match peek () with
            | Some ',' -> incr pos; items (v :: acc)
            | Some ']' -> incr pos; Array (List.rev (v :: acc))
            | None -> err "unexpected end of input"
            | Some _ -> err "expected ',' or ']'"
          in
          items []
    | Some '"' -> String (string ())
    | Some ('-' | '0' .. '9') -> number ()
    | Some 't' -> literal "true" (Bool true)
    | Some 'f' -> literal "false" (Bool false)
    | Some 'n' -> literal "null" Null
    | Some c -> err (Printf.sprintf "unexpected character '%c'" c)
  in
  match
    let v = value () in
    skip_ws ();
    if !pos < n then err "trailing data";
    v
  with
  | v -> Ok v
  | exception Parse_error (msg, at) -> Error (Printf.sprintf "%s at offset %d" msg at)

let objects_in_lines text =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let line = String.trim line in
         if String.starts_with ~prefix:"{" line then
           match parse line with Ok (Object _ as o) -> Some o | Ok _ | Error _ -> None
         else None)

let member key = function Object fields -> List.assoc_opt key fields | _ -> None

let rec path keys v =
  match keys with [] -> Some v | k :: rest -> Option.bind (member k v) (path rest)
