let provisional = true

(* Inclusive ranges, sorted by start; see the .mli for the provenance of each group. *)
let ranges =
  [|
    (0x0000, 0x001F) (* Cc *);
    (0x007F, 0x009F) (* DEL and C1: Cc *);
    (0x00AD, 0x00AD) (* soft hyphen: Cf *);
    (0x034F, 0x034F) (* combining grapheme joiner: DICP *);
    (0x0600, 0x0605) (* Arabic number signs: Cf *);
    (0x061C, 0x061C) (* Arabic letter mark: Cf, bidi *);
    (0x06DD, 0x06DD) (* Arabic end of ayah: Cf *);
    (0x070F, 0x070F) (* Syriac abbreviation mark: Cf *);
    (0x0890, 0x0891) (* Arabic pound/piastre marks: Cf *);
    (0x08E2, 0x08E2) (* Arabic disputed end of ayah: Cf *);
    (0x115F, 0x1160) (* Hangul choseong/jungseong fillers: DICP *);
    (0x17B4, 0x17B5) (* Khmer inherent vowels: DICP *);
    (0x180B, 0x180F) (* Mongolian free variation selectors, vowel separator: Cf/VS *);
    (0x200B, 0x200F) (* zero-width characters, LRM, RLM: Cf *);
    (0x2028, 0x202E) (* line/paragraph separators, bidi embeddings and overrides *);
    (0x2060, 0x206F) (* word joiner, invisible operators, bidi isolates, deprecated formats *);
    (0x3164, 0x3164) (* Hangul filler: DICP *);
    (0xFDD0, 0xFDEF) (* noncharacters *);
    (0xFE00, 0xFE0F) (* variation selectors *);
    (0xFEFF, 0xFEFF) (* BOM / zero-width no-break space: Cf *);
    (0xFFA0, 0xFFA0) (* halfwidth Hangul filler: DICP *);
    (0xFFF0, 0xFFFB) (* reserved DICP, interlinear annotation: Cf *);
    (0x110BD, 0x110BD) (* Kaithi number sign: Cf *);
    (0x110CD, 0x110CD) (* Kaithi number sign above: Cf *);
    (0x13430, 0x1343F) (* Egyptian hieroglyph format controls: Cf *);
    (0x1BCA0, 0x1BCA3) (* shorthand format controls: Cf *);
    (0x1D173, 0x1D17A) (* musical symbol format controls: Cf *);
    (0xE0000, 0xE0FFF) (* tags, variation selectors supplement, reserved DICP *);
  |]

let is_noncharacter_plane_end cp = cp land 0xFFFE = 0xFFFE

let mem cp =
  is_noncharacter_plane_end cp
  ||
  let rec search lo hi =
    lo <= hi
    &&
    let mid = (lo + hi) / 2 in
    let a, b = ranges.(mid) in
    if cp < a then search lo (mid - 1) else if cp > b then search (mid + 1) hi else true
  in
  search 0 (Array.length ranges - 1)
