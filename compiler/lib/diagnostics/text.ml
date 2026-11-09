type unit_ = Scalar of int | Byte of int

let decode s i =
  let d = String.get_utf_8_uchar s i in
  if Uchar.utf_decode_is_valid d then (Scalar (Uchar.to_int (Uchar.utf_decode_uchar d)), Uchar.utf_decode_length d)
  else (Byte (Char.code s.[i]), 1)

let units s =
  let rec go i acc =
    if i >= String.length s then List.rev acc
    else
      let u, len = decode s i in
      go (i + len) (u :: acc)
  in
  go 0 []

(* LEX-003 list, plus every Cc character (tab and LF included: free text is one line). U+2061..U+2065
   are invisible operators or unassigned, so the whole U+2060..U+2069 block is treated as unsafe. *)
let is_unsafe cp =
  cp < 0x20
  || (cp >= 0x7F && cp <= 0x9F)
  || cp = 0x061C
  || (cp >= 0x200B && cp <= 0x200F)
  || (cp >= 0x202A && cp <= 0x202E)
  || (cp >= 0x2060 && cp <= 0x2069)
  || cp = 0x2028 || cp = 0x2029 || cp = 0xFEFF

let is_zero_width cp =
  (cp >= 0x0300 && cp <= 0x036F)
  || (cp >= 0x1AB0 && cp <= 0x1AFF)
  || (cp >= 0x1DC0 && cp <= 0x1DFF)
  || (cp >= 0x20D0 && cp <= 0x20FF)
  || (cp >= 0xFE00 && cp <= 0xFE0F)
  || (cp >= 0xFE20 && cp <= 0xFE2F)
  || (cp >= 0xE0100 && cp <= 0xE01EF)

let is_wide cp =
  (cp >= 0x1100 && cp <= 0x115F)
  || (cp >= 0x2E80 && cp <= 0x303E)
  || (cp >= 0x3041 && cp <= 0x33FF)
  || (cp >= 0x3400 && cp <= 0x4DBF)
  || (cp >= 0x4E00 && cp <= 0x9FFF)
  || (cp >= 0xA000 && cp <= 0xA4CF)
  || (cp >= 0xAC00 && cp <= 0xD7A3)
  || (cp >= 0xF900 && cp <= 0xFAFF)
  || (cp >= 0xFE30 && cp <= 0xFE4F)
  || (cp >= 0xFF00 && cp <= 0xFF60)
  || (cp >= 0xFFE0 && cp <= 0xFFE6)
  || (cp >= 0x1F300 && cp <= 0x1F64F)
  || (cp >= 0x1F680 && cp <= 0x1F6FF)
  || (cp >= 0x1F900 && cp <= 0x1FAFF)
  || (cp >= 0x20000 && cp <= 0x3FFFD)

let utf8 cp =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int cp);
  Buffer.contents b

let escaped = function Byte b -> Printf.sprintf "<0x%02X>" b | Scalar cp -> Printf.sprintf "<U+%04X>" cp

let display u =
  match u with
  | Scalar 0x09 -> ("    ", 4)
  | Byte _ -> (escaped u, 6)
  | Scalar cp when is_unsafe cp ->
      let s = escaped u in
      (s, String.length s)
  | Scalar cp -> (utf8 cp, if is_zero_width cp then 0 else if is_wide cp then 2 else 1)

let sanitize s =
  let b = Buffer.create (String.length s) in
  List.iter
    (fun u ->
      match u with
      | Byte _ -> Buffer.add_string b (escaped u)
      | Scalar cp when is_unsafe cp -> Buffer.add_string b (escaped u)
      | Scalar cp -> Buffer.add_utf_8_uchar b (Uchar.of_int cp))
    (units s);
  Buffer.contents b

let json_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  List.iter
    (fun u ->
      match u with
      | Byte _ -> Buffer.add_string b "\\ufffd"
      | Scalar 0x22 -> Buffer.add_string b "\\\""
      | Scalar 0x5C -> Buffer.add_string b "\\\\"
      | Scalar 0x0A -> Buffer.add_string b "\\n"
      | Scalar 0x0D -> Buffer.add_string b "\\r"
      | Scalar 0x09 -> Buffer.add_string b "\\t"
      | Scalar cp when is_unsafe cp -> Buffer.add_string b (Printf.sprintf "\\u%04x" cp)
      | Scalar cp -> Buffer.add_utf_8_uchar b (Uchar.of_int cp))
    (units s);
  Buffer.add_char b '"';
  Buffer.contents b
