module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

(* LEX-003. CR (LEX-002, E0003) and HT (LEX-004, E0005) are Cc too but have their own rules. *)
let is_forbidden cp =
  cp = 0x061C || cp = 0x200E || cp = 0x200F
  || (cp >= 0x202A && cp <= 0x202E)
  || (cp >= 0x2066 && cp <= 0x2069)
  || (cp >= 0x200B && cp <= 0x200D)
  || cp = 0x2060 || cp = 0xFEFF || cp = 0x2028 || cp = 0x2029
  || (cp < 0x20 && cp <> 0x0A && cp <> 0x09 && cp <> 0x0D)
  || (cp >= 0x7F && cp <= 0x9F)

(* Unicode character names of the forbidden format characters; all others are Cc (docs/diagnostics.md E0004). *)
let name cp =
  match cp with
  | 0x061C -> "ARABIC LETTER MARK"
  | 0x200B -> "ZERO WIDTH SPACE"
  | 0x200C -> "ZERO WIDTH NON-JOINER"
  | 0x200D -> "ZERO WIDTH JOINER"
  | 0x200E -> "LEFT-TO-RIGHT MARK"
  | 0x200F -> "RIGHT-TO-LEFT MARK"
  | 0x202A -> "LEFT-TO-RIGHT EMBEDDING"
  | 0x202B -> "RIGHT-TO-LEFT EMBEDDING"
  | 0x202C -> "POP DIRECTIONAL FORMATTING"
  | 0x202D -> "LEFT-TO-RIGHT OVERRIDE"
  | 0x202E -> "RIGHT-TO-LEFT OVERRIDE"
  | 0x2028 -> "LINE SEPARATOR"
  | 0x2029 -> "PARAGRAPH SEPARATOR"
  | 0x2060 -> "WORD JOINER"
  | 0x2066 -> "LEFT-TO-RIGHT ISOLATE"
  | 0x2067 -> "RIGHT-TO-LEFT ISOLATE"
  | 0x2068 -> "FIRST STRONG ISOLATE"
  | 0x2069 -> "POP DIRECTIONAL ISOLATE"
  | 0xFEFF -> "ZERO WIDTH NO-BREAK SPACE"
  | _ -> "control character"

(* LEX-001. Decodes the UTF-8 sequence starting at byte [i] (requires [i < String.length src]).
   Returns [w > 0] with the code point in [cp_out.(0)] for a well-formed sequence of [w] bytes, or [-n] where
   [n >= 1] is the length of the maximal subpart of an ill-formed subsequence (Unicode §3.9, Table 3-7: the
   second-byte bounds exclude overlong forms, surrogates and values above U+10FFFF). *)
let decode src i cp_out =
  let len = String.length src in
  let b0 = Char.code src.[i] in
  let width, lo, hi =
    if b0 < 0x80 then (1, 0, 0)
    else if b0 >= 0xC2 && b0 <= 0xDF then (2, 0x80, 0xBF)
    else if b0 = 0xE0 then (3, 0xA0, 0xBF)
    else if b0 = 0xED then (3, 0x80, 0x9F)
    else if b0 >= 0xE1 && b0 <= 0xEF then (3, 0x80, 0xBF)
    else if b0 = 0xF0 then (4, 0x90, 0xBF)
    else if b0 >= 0xF1 && b0 <= 0xF3 then (4, 0x80, 0xBF)
    else if b0 = 0xF4 then (4, 0x80, 0x8F)
    else (0, 0, 0)
    (* 80..C1 and F5..FF never start a sequence *)
  in
  if width = 1 then begin
    cp_out.(0) <- b0;
    1
  end
  else if width = 0 then -1
  else begin
    let rec go k cp =
      if k = width then begin
        cp_out.(0) <- cp;
        width
      end
      else if i + k >= len then -k
      else
        let b = Char.code src.[i + k] in
        let lo, hi = if k = 1 then (lo, hi) else (0x80, 0xBF) in
        if b < lo || b > hi then -k else go (k + 1) ((cp lsl 6) lor (b land 0x3F))
    in
    go 1 (b0 land (0xFF lsr (width + 1)))
  end

let check ~file src =
  let diags = ref [] in
  let add d = diags := d :: !diags in
  let len = String.length src in
  let line = ref 1 and col = ref 1 in
  let span c0 c1 =
    Span.make ~file ~start:{ Span.line = !line; col = c0 } ~stop:{ line = !line; col = c1 }
  in
  (* Column where the current run of ill-formed bytes started, or 0. A run is reported once (E0001); each maximal
     subpart counts as one column, as if replaced by U+FFFD. *)
  let bad_start = ref 0 in
  let flush_bad () =
    if !bad_start > 0 then begin
      add (D.error ~rule:"LEX-001" ~code:"E0001" (span !bad_start !col) "invalid UTF-8 sequence");
      bad_start := 0
    end
  in
  let cp_out = [| 0 |] in
  let i = ref 0 in
  while !i < len do
    let w = decode src !i cp_out in
    if w < 0 then begin
      if !bad_start = 0 then bad_start := !col;
      incr col;
      i := !i - w
    end
    else begin
      flush_bad ();
      let cp = cp_out.(0) in
      if cp = 0x0A then begin
        incr line;
        col := 1
      end
      else begin
        if cp = 0x0D then begin
          (* LEX-002: CR LF is accepted; a lone CR is not. *)
          if not (!i + 1 < len && src.[!i + 1] = '\n') then
            add
              (D.error ~rule:"LEX-002" ~code:"E0003" (span !col (!col + 1)) "lone carriage return")
        end
        else if cp = 0xFEFF && !i = 0 then
          add
            (D.error ~rule:"LEX-001" ~code:"E0002"
               (span !col (!col + 1))
               "byte-order mark is not allowed")
        else if is_forbidden cp then
          add
            (D.error ~rule:"LEX-003" ~code:"E0004"
               (span !col (!col + 1))
               (Printf.sprintf
                  "forbidden character U+%04X (%s) — risk: hidden or reordered source text (Trojan \
                   Source)"
                  cp (name cp)));
        incr col
      end;
      i := !i + w
    end
  done;
  flush_bad ();
  List.rev !diags
