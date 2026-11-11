type t = int

let equal = Int.equal
let compare = Int.compare
let hash n = n
let to_int n = n
let pp fmt n = Format.fprintf fmt "#%d" n

module Gen = struct
  type nonrec t = { mutable next : int }

  let create () = { next = 0 }

  let fresh g =
    let n = g.next in
    g.next <- n + 1;
    n

  let count g = g.next
end
