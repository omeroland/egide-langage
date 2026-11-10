type status = Pass | Fail of string | Skip of string
type case = { file : string; name : string; status : status; time : float }

(* XML 1.0 Char production: #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF].
   Valid UTF-8 never encodes surrogates, so only the low controls and U+FFFE/U+FFFF remain. *)
let xml_char u = u = 0x9 || u = 0xA || u = 0xD || (u >= 0x20 && u <> 0xFFFE && u <> 0xFFFF)

let sanitize s =
  let b = Buffer.create (String.length s) in
  let rec go i =
    if i < String.length s then begin
      let d = String.get_utf_8_uchar s i in
      let len = Uchar.utf_decode_length d in
      if Uchar.utf_decode_is_valid d && xml_char (Uchar.to_int (Uchar.utf_decode_uchar d)) then
        Buffer.add_string b (String.sub s i len)
      else
        (* Escape every byte of the rejected sequence so nothing is lost. *)
        String.iter
          (fun c -> Buffer.add_string b (Printf.sprintf "\\x%02X" (Char.code c)))
          (String.sub s i len);
      go (i + len)
    end
  in
  go 0;
  Buffer.contents b

let escape ~attr s =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' when attr -> Buffer.add_string b "&quot;"
      | '\n' when attr -> Buffer.add_string b "&#10;"
      | '\r' -> Buffer.add_string b "&#13;"
      | '\t' when attr -> Buffer.add_string b "&#9;"
      | c -> Buffer.add_char b c)
    (sanitize s);
  Buffer.contents b

let attr = escape ~attr:true
let text = escape ~attr:false
let first_line s = match String.index_opt s '\n' with Some i -> String.sub s 0 i | None -> s

let counts cases =
  let count p = List.length (List.filter p cases) in
  ( List.length cases,
    count (fun c -> match c.status with Fail _ -> true | Pass | Skip _ -> false),
    count (fun c -> match c.status with Skip _ -> true | Pass | Fail _ -> false),
    List.fold_left (fun t c -> t +. c.time) 0. cases )

let to_xml cases =
  let b = Buffer.create 4096 in
  let add fmt = Printf.bprintf b fmt in
  let tests, failures, skipped, time = counts cases in
  add "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  add
    "<testsuites name=\"egide-conformance\" tests=\"%d\" failures=\"%d\" errors=\"0\" \
     skipped=\"%d\" time=\"%.3f\">\n"
    tests failures skipped time;
  let dirs =
    List.fold_left
      (fun acc c ->
        let d = Filename.dirname c.file in
        if List.mem d acc then acc else acc @ [ d ])
      [] cases
  in
  List.iter
    (fun dir ->
      let cs = List.filter (fun c -> Filename.dirname c.file = dir) cases in
      let tests, failures, skipped, time = counts cs in
      add
        "  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"0\" skipped=\"%d\" \
         time=\"%.3f\">\n"
        (attr dir) tests failures skipped time;
      let classname = String.map (function '/' -> '.' | c -> c) dir in
      List.iter
        (fun c ->
          let open_tag =
            Printf.sprintf "    <testcase classname=\"%s\" name=\"%s\" file=\"%s\" time=\"%.3f\""
              (attr classname) (attr c.name) (attr c.file) c.time
          in
          match c.status with
          | Pass -> add "%s/>\n" open_tag
          | Fail m ->
              add "%s>\n      <failure message=\"%s\">%s</failure>\n    </testcase>\n" open_tag
                (attr (first_line m))
                (text m)
          | Skip m ->
              add "%s>\n      <skipped message=\"%s\"/>\n    </testcase>\n" open_tag (attr m))
        cs;
      add "  </testsuite>\n")
    dirs;
  add "</testsuites>\n";
  Buffer.contents b
