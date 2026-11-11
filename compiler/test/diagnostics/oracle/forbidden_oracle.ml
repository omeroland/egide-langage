(* T-1033 test oracle for LEX-003 (ADR-0017): the set, as the union of the Unicode 16.0.0 properties the spec
   names, as separate literal range lists.

   Independence: this file shares no code, and no parsing, with tools/gen/unicode_forbidden.py. The lists were
   computed once by a different engine (Node.js / ICU, `new RegExp("^\\p{Cf}$", "u")` over every scalar value,
   `\p{Default_Ignorable_Code_Point}`, `\p{Variation_Selector}`, `\p{Noncharacter_Code_Point}`, `\p{Cc}`, `\p{Zs}`)
   and cross-checked against the Python `regex` 2024.11.6 module (Unicode 16.0.0). Both agree with the generated
   table over all 0x110000 code points. For these properties Unicode 17 (the ICU used) equals Unicode 16.0.0.
   A regenerated table cannot change the expected set: only an edit of this file can, and it is reviewed. *)
[@@@ocamlformat "disable"]

(* general category Cf (170 code points) *)
let cf =
  [ (0xAD, 0xAD);
    (0x600, 0x605);
    (0x61C, 0x61C);
    (0x6DD, 0x6DD);
    (0x70F, 0x70F);
    (0x890, 0x891);
    (0x8E2, 0x8E2);
    (0x180E, 0x180E);
    (0x200B, 0x200F);
    (0x202A, 0x202E);
    (0x2060, 0x2064);
    (0x2066, 0x206F);
    (0xFEFF, 0xFEFF);
    (0xFFF9, 0xFFFB);
    (0x110BD, 0x110BD);
    (0x110CD, 0x110CD);
    (0x13430, 0x1343F);
    (0x1BCA0, 0x1BCA3);
    (0x1D173, 0x1D17A);
    (0xE0001, 0xE0001);
    (0xE0020, 0xE007F) ]

(* general category Cc *)
let cc =
  [ (0x0, 0x1F);
    (0x7F, 0x9F) ]

(* Default_Ignorable_Code_Point, assigned or not *)
let dicp =
  [ (0xAD, 0xAD);
    (0x34F, 0x34F);
    (0x61C, 0x61C);
    (0x115F, 0x1160);
    (0x17B4, 0x17B5);
    (0x180B, 0x180F);
    (0x200B, 0x200F);
    (0x202A, 0x202E);
    (0x2060, 0x206F);
    (0x3164, 0x3164);
    (0xFE00, 0xFE0F);
    (0xFEFF, 0xFEFF);
    (0xFFA0, 0xFFA0);
    (0xFFF0, 0xFFF8);
    (0x1BCA0, 0x1BCA3);
    (0x1D173, 0x1D17A);
    (0xE0000, 0xE0FFF) ]

(* Variation_Selector *)
let vs =
  [ (0x180B, 0x180D);
    (0x180F, 0x180F);
    (0xFE00, 0xFE0F);
    (0xE0100, 0xE01EF) ]

(* Noncharacter_Code_Point *)
let ncp =
  [ (0xFDD0, 0xFDEF);
    (0xFFFE, 0xFFFF);
    (0x1FFFE, 0x1FFFF);
    (0x2FFFE, 0x2FFFF);
    (0x3FFFE, 0x3FFFF);
    (0x4FFFE, 0x4FFFF);
    (0x5FFFE, 0x5FFFF);
    (0x6FFFE, 0x6FFFF);
    (0x7FFFE, 0x7FFFF);
    (0x8FFFE, 0x8FFFF);
    (0x9FFFE, 0x9FFFF);
    (0xAFFFE, 0xAFFFF);
    (0xBFFFE, 0xBFFFF);
    (0xCFFFE, 0xCFFFF);
    (0xDFFFE, 0xDFFFF);
    (0xEFFFE, 0xEFFFF);
    (0xFFFFE, 0xFFFFF);
    (0x10FFFE, 0x10FFFF) ]

(* general category Zs (U+0020 included) *)
let zs =
  [ (0x20, 0x20);
    (0xA0, 0xA0);
    (0x1680, 0x1680);
    (0x2000, 0x200A);
    (0x202F, 0x202F);
    (0x205F, 0x205F);
    (0x3000, 0x3000) ]

(* Zl and Zp *)
let line_and_paragraph_separators = [ (0x2028, 0x2029) ]

let in_ranges cp l = List.exists (fun (lo, hi) -> lo <= cp && cp <= hi) l

(* The LEX-003 set, tab and LF included (Cc is whole). *)
let forbidden cp =
  List.exists (in_ranges cp) [ cf; cc; dicp; vs; ncp; line_and_paragraph_separators ]

let is_scalar cp = (cp >= 0 && cp < 0xD800) || (cp > 0xDFFF && cp <= 0x10FFFF)
