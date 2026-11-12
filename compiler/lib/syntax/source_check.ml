module D = Egide_diagnostics.Diagnostic
module Span = Egide_source.Span

(* LEX-003: the property-defined set of ADR-0017 (Forbidden_set, generated from Unicode 16.0.0). CR (LEX-002, E0003) and
   HT (LEX-004, E0005) are Cc too but have their own rules; LF is a line break. *)
let is_forbidden cp =
  Egide_diagnostics.Forbidden_set.mem cp && cp <> 0x0A && cp <> 0x09 && cp <> 0x0D

(* Unicode character names of the best-known forbidden characters (docs/diagnostics.md E0004). Others are named by
   their class, which is enough: the diagnostic always carries the code point, escaped. *)
let name cp =
  match cp with
  | 0x00AD -> "SOFT HYPHEN"
  | 0x034F -> "COMBINING GRAPHEME JOINER"
  | 0x061C -> "ARABIC LETTER MARK"
  | 0x115F -> "HANGUL CHOSEONG FILLER"
  | 0x1160 -> "HANGUL JUNGSEONG FILLER"
  | 0x17B4 -> "KHMER VOWEL INHERENT AQ"
  | 0x17B5 -> "KHMER VOWEL INHERENT AA"
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
  | 0x3164 -> "HANGUL FILLER"
  | 0xFEFF -> "ZERO WIDTH NO-BREAK SPACE"
  | 0xFFA0 -> "HALFWIDTH HANGUL FILLER"
  | _ when cp < 0x20 || (cp >= 0x7F && cp <= 0x9F) -> "control character"
  | _ when cp >= 0xE0000 && cp <= 0xE007F -> "tag character"
  | _
    when (cp >= 0xFE00 && cp <= 0xFE0F)
         || (cp >= 0xE0100 && cp <= 0xE01EF)
         || (cp >= 0x180B && cp <= 0x180F && cp <> 0x180E) ->
      "variation selector"
  | _ when cp land 0xFFFE = 0xFFFE || (cp >= 0xFDD0 && cp <= 0xFDEF) -> "noncharacter"
  | _ -> "format or default-ignorable character"

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

(* T-1080. Diagnostics go to [sink], which keeps the first [limit] and counts the rest, so memory is bounded
   whatever the input. Consecutive identical forbidden characters (E0004) or lone CRs (E0003) are one diagnostic
   with a count and a span over the run (ADR-0016, the E0005 model): a run costs one slot of the budget.
   Returns whether the input has ill-formed UTF-8 (E0001); the caller must not rely on the sink for that, since
   the diagnostic may have been dropped. *)
let check_into sink ~file src =
  let add d = D.Sink.report sink d in
  let len = String.length src in
  let line = ref 1 and col = ref 1 in
  let span c0 c1 =
    Span.make ~file ~start:{ Span.line = !line; col = c0 } ~stop:{ line = !line; col = c1 }
  in
  let invalid = ref false in
  (* Column where the current run of ill-formed bytes started, or 0. A run is reported once (E0001); each maximal
     subpart counts as one column, as if replaced by U+FFFD. *)
  let bad_start = ref 0 in
  let flush_bad () =
    if !bad_start > 0 then begin
      invalid := true;
      add (D.error ~rule:"LEX-001" ~code:"E0001" (span !bad_start !col) "invalid UTF-8 sequence");
      bad_start := 0
    end
  in
  (* Pending run of identical E0003/E0004 characters: (code point, first column, length). CR is 0x0D, which is
     never in the forbidden set, so one cp identifies the kind. Flushed before any other diagnostic and at each
     line end, so emission order is source order. *)
  let run = ref None in
  let flush_run () =
    match !run with
    | None -> ()
    | Some (cp, c0, n) ->
        run := None;
        let sp = span c0 (c0 + n) in
        let times = if n = 1 then "" else Printf.sprintf " repeated %d times" n in
        if cp = 0x0D then
          add (D.error ~rule:"LEX-002" ~code:"E0003" sp ("lone carriage return" ^ times))
        else
          add
            (D.error ~rule:"LEX-003" ~code:"E0004" sp
               (Printf.sprintf
                  "forbidden character U+%04X (%s)%s — risk: hidden or reordered source text (Trojan \
                   Source)"
                  cp (name cp) times))
  in
  let note_run cp =
    match !run with
    | Some (c, c0, n) when c = cp && c0 + n = !col -> run := Some (c, c0, n + 1)
    | _ ->
        flush_run ();
        run := Some (cp, !col, 1)
  in
  let cp_out = [| 0 |] in
  let i = ref 0 in
  while !i < len do
    let w = decode src !i cp_out in
    if w < 0 then begin
      flush_run ();
      if !bad_start = 0 then bad_start := !col;
      incr col;
      i := !i - w
    end
    else begin
      flush_bad ();
      let cp = cp_out.(0) in
      if cp = 0x0A then begin
        flush_run ();
        incr line;
        col := 1
      end
      else begin
        if cp = 0x0D then begin
          (* LEX-002: CR LF is accepted; a lone CR is not. *)
          if not (!i + 1 < len && src.[!i + 1] = '\n') then note_run cp else flush_run ()
        end
        else if cp = 0xFEFF && !i = 0 then
          add
            (D.error ~rule:"LEX-001" ~code:"E0002"
               (span !col (!col + 1))
               "byte-order mark is not allowed")
        else if is_forbidden cp then note_run cp
        else flush_run ();
        incr col
      end;
      i := !i + w
    end
  done;
  flush_bad ();
  flush_run ();
  !invalid

let check ~file src =
  let sink = D.Sink.create ~limit:D.Sink.default_limit () in
  ignore (check_into sink ~file src);
  D.Sink.to_list sink
