---
id: Q-0056
rule: MEM-001, MEM-021, MEM-030, SYN-060
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0011, T-0061]
severity: high
status: open
---
## Question

**Executive summary.** MEM-001 says a lambda captures by logical copy. Every block-like construct of the standard library
(`scope`, `lock`, `map.update`, `retry`, route handlers) is a trailing-block lambda. The spec does not say what an
assignment to a captured `var` means inside such a block, so the most common loop-with-accumulator shape is undefined.

## Example

```egide fragment
var total = 0
xs.each() fn(x):
    total += x        # error? mutation of a private copy? mutation of `total`?
print(total)
```

## Core analysis

*Established*: MEM-001 (capture = copy); MEM-030 (an `inout` parameter cannot be captured by a lambda that outlives the
call); MEM-021 (an `inout` argument cannot be captured by a lambda argument of the same call). Nothing covers a local
`var`. *Extrapolated*: reading MEM-001 literally, `total` stays 0 and no diagnostic is required: a silent wrong result.

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | assigning to, or passing `inout`, a captured binding is a compile-time error; results leave a block by its value | one rule, no new concept; consistent with CON-021 | accumulators need `fold` or a returned value; unfamiliar to Go and Python users |
| B | a lambda passed directly as a call argument and not stored (non-escaping, as in Swift) may capture a `var` by `inout` for the duration of the call, under MEM-021 exclusivity; other lambdas follow A | `for`-like library functions feel native | needs an "escaping" distinction on function-typed parameters (a marker in signatures) |
| C | literal MEM-001: mutation of the copy, no diagnostic | nothing to implement | silent wrong results; contradicts INT-004's spirit |

## Recommendations / Next Steps

A now (it is a restriction, so B can be added later without breaking code), with an E-code and a fix hint ("return the
value from the block"). Re-evaluate B at the MVP checkpoint with the examples of `examples/`. Reject C. Needs a short ADR
adding one MEM rule.
