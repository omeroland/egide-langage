module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

let is_forbidden cp =
  cp = 0x061C || cp = 0x200E || cp = 0x200F
  || (cp >= 0x202A && cp <= 0x202E)
  || (cp >= 0x2066 && cp <= 0x2069)
  || (cp >= 0x200B && cp <= 0x200D)
  || cp = 0x2060 || cp = 0xFEFF || cp = 0x2028 || cp = 0x2029
  || (cp < 0x20 && cp <> 0x0A && cp <> 0x09 && cp <> 0x0D)
  || cp = 0x7F
  || (cp >= 0x80 && cp <= 0x9F)

let check ~file src =
  let diags = ref [] in
  let add d = diags := d :: !diags in
  let len = String.length src in
  let line = ref 1 and col = ref 1 in
  let span () =
    let p = { Span.line = !line; col = !col } in
    Span.make ~file ~start:p ~stop:{ p with col = !col + 1 }
  in
  if len >= 3 && String.sub src 0 3 = "\xEF\xBB\xBF" then
    add (D.error ~rule:"LEX-001" ~code:"E0002" (span ()) "byte-order mark is not allowed");
  let i = ref 0 in
  while !i < len do
    let c = Char.code src.[!i] in
    let width, cp =
      if c < 0x80 then (1, c)
      else if c land 0xE0 = 0xC0 then (2, c land 0x1F)
      else if c land 0xF0 = 0xE0 then (3, c land 0x0F)
      else if c land 0xF8 = 0xF0 then (4, c land 0x07)
      else (0, 0)
    in
    let valid = ref (width > 0 && !i + width <= len) in
    let cp = ref cp in
    if !valid then
      for k = 1 to width - 1 do
        let b = Char.code src.[!i + k] in
        if b land 0xC0 <> 0x80 then valid := false else cp := (!cp lsl 6) lor (b land 0x3F)
      done;
    (* Reject overlong encodings, surrogates and out-of-range values. *)
    let min_for = [| 0; 0; 0x80; 0x800; 0x10000 |] in
    if !valid && (!cp < min_for.(width) || (!cp >= 0xD800 && !cp <= 0xDFFF) || !cp > 0x10FFFF)
    then valid := false;
    if not !valid then begin
      add (D.error ~rule:"LEX-001" ~code:"E0001" (span ()) "invalid UTF-8 sequence");
      incr i;
      incr col
    end
    else begin
      let cp = !cp in
      if cp = 0x0D then begin
        if not (!i + 1 < len && src.[!i + 1] = '\n') then
          add (D.error ~rule:"LEX-002" ~code:"E0003" (span ()) "lone carriage return")
      end
      else if is_forbidden cp && not (cp = 0xFEFF && !i = 0) then
        add
          (D.error ~rule:"LEX-003" ~code:"E0004" (span ())
             (Printf.sprintf
                "forbidden character U+%04X — risk: hidden or reordered source text (Trojan Source)" cp));
      if cp = 0x0A then begin
        incr line;
        col := 1
      end
      else incr col;
      i := !i + width
    end
  done;
  List.rev !diags
