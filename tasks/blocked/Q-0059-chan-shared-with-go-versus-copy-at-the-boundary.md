---
id: Q-0059
rule: GO-021, CON-030
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0082]
severity: medium
status: open
---
## Question

**Executive summary.** The type-mapping table of §11.3 says `chan T` ↔ `Chan[T]` is "same object, no copy", and GO-021
says slices and maps are copied at the boundary so that Go can never mutate an Égide value. For `Chan[List[int]]` both
cannot hold.

## Example

```egide fragment
let ch = Chan[List[int]](cap: 1)
gopkg.Consume(ch)        # Go receives a []int: the Égide buffer, or a copy?
```

## Core analysis

*Established*: the two texts above. *Extrapolated*: if the channel object is shared, either its element representation is
the Go one (then Égide-side sends and receives convert on every operation) or Go sees Égide's copy-on-write buffers (then
GO-021 is false and Go can mutate a buffer that Égide believes unique, which breaks MEM-001).

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | "same object" only when `T` maps identically (numbers, `bool`, `GoRef`, Go struct types); otherwise passing a `Chan[T]` to Go is an error with a hint to bridge | sound; cheap | fewer channels cross directly |
| B | the compiler inserts a bridging goroutine that converts each element | every `Chan[T]` crosses | hidden task, changes buffering and close semantics |

## Recommendations / Next Steps

A, with the bridge of B as an explicit `std` function. Amend the table row of §11.3.
