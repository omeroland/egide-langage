let is_zs_not_space cp =
  cp = 0xA0 || cp = 0x1680
  || (cp >= 0x2000 && cp <= 0x200A)
  || cp = 0x202F || cp = 0x205F || cp = 0x3000

let is_bidi cp =
  cp = 0x061C || cp = 0x200E || cp = 0x200F
  || (cp >= 0x202A && cp <= 0x202E)
  || (cp >= 0x2066 && cp <= 0x2069)

let is_dangerous cp =
  Forbidden_set.mem cp || is_zs_not_space cp || is_bidi cp || (cp >= 0x7F && cp <= 0x9F)

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

let u_escape cp = Printf.sprintf "\\u{%X}" cp

let display_of ~guard ~keep_lf s =
  let b = Buffer.create (String.length s) in
  List.iter
    (fun u ->
      match u with
      | Text.Byte x -> Buffer.add_string b (Printf.sprintf "\\x%02X" x)
      | Scalar 0x5C -> Buffer.add_string b (if guard then "\\" else "\\\\")
      | Scalar 0x0A -> Buffer.add_string b (if keep_lf then "\n" else "\\n")
      | Scalar 0x0D when not guard -> Buffer.add_string b "\\r"
      | Scalar 0x09 when not guard -> Buffer.add_string b "\\t"
      | Scalar cp when is_dangerous cp -> Buffer.add_string b (u_escape cp)
      | Scalar cp -> Buffer.add_utf_8_uchar b (Uchar.of_int cp))
    (Text.units s);
  Buffer.contents b

let display = display_of ~guard:false ~keep_lf:false
let neutralize = display_of ~guard:true ~keep_lf:true
let neutralize_line = display_of ~guard:true ~keep_lf:false

let display_quoted s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c -> if c = '"' then Buffer.add_string b "\\\"" else Buffer.add_char b c)
    (display s);
  Buffer.add_char b '"';
  Buffer.contents b

let json_u b cp = Buffer.add_string b (Printf.sprintf "\\u%04x" cp)

let json_safe s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  List.iter
    (fun u ->
      match u with
      | Text.Byte _ -> json_u b 0xFFFD
      | Scalar 0x22 -> Buffer.add_string b "\\\""
      | Scalar 0x5C -> Buffer.add_string b "\\\\"
      | Scalar 0x0A -> Buffer.add_string b "\\n"
      | Scalar 0x0D -> Buffer.add_string b "\\r"
      | Scalar 0x09 -> Buffer.add_string b "\\t"
      | Scalar cp when is_dangerous cp ->
          if cp > 0xFFFF then (
            let c = cp - 0x10000 in
            json_u b (0xD800 lor (c lsr 10));
            json_u b (0xDC00 lor (c land 0x3FF)))
          else json_u b cp
      | Scalar cp -> Buffer.add_utf_8_uchar b (Uchar.of_int cp))
    (Text.units s);
  Buffer.add_char b '"';
  Buffer.contents b

let display_unit u =
  match u with
  | Text.Scalar cp when not (is_dangerous cp || cp = 0x5C || cp = 0x0A || cp = 0x0D || cp = 0x09) ->
      (utf8 cp, Text.cells cp)
  | _ ->
      let s =
        display_of ~guard:false ~keep_lf:false
          (match u with Text.Scalar cp -> utf8 cp | Text.Byte x -> String.make 1 (Char.chr x))
      in
      (s, String.length s)
