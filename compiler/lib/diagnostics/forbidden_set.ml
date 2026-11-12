(* LEX-003 (ADR-0017): a binary search in the generated table. The table is flat: [lo0; hi0; lo1; hi1; ...],
   sorted, disjoint. O(log n) per code point, no allocation. *)
let ranges = Egide_source.Forbidden_table.ranges

let mem cp =
  let n = Array.length ranges / 2 in
  let rec search lo hi =
    lo <= hi
    &&
    let mid = (lo + hi) / 2 in
    if cp < ranges.(2 * mid) then search lo (mid - 1)
    else if cp > ranges.((2 * mid) + 1) then search (mid + 1) hi
    else true
  in
  search 0 (n - 1)
