---
id: Q-0058
rule: SEC-012
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0072]
severity: medium
status: open
---
## Question

**Executive summary.** SEC-012 says the clear value of a `Secret[T]` is reachable only inside `s.expose(v => …)` and that
the lambda's **result type** cannot contain `T`. A result-type check does not see side effects of the lambda, so the clear
value can leave through anything the lambda captured with reference semantics.

## Example

```egide fragment
let leak = Chan[str](cap: 1)
password.expose(v => leak.send(v))      # result type Result[(), Closed]: accepted
let clear = leak.recv()                 # str, no longer a Secret
```

The same works with a captured `Shared[Mutex[str]]`, a capability (`log.info(v)`, `out.print(v)`) or a `GoRef`.

## Core analysis

*Established*: SEC-012 text; MEM-050 and CON-030 give `Shared` and `Chan` reference semantics; capabilities are values
that lambdas capture (CAP-022). *Extrapolated*: with Q-0056 option A a captured `var` cannot carry the value out, so the
remaining channels are exactly the reference-semantics types and capabilities.

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | state the guarantee as it is: `Secret` prevents **accidental** disclosure (logs, `Display`, JSON, equality timing); deliberate exfiltration inside `expose` is out of scope; `egide audit` lists every `expose` | honest; nothing to implement | weaker than the current wording |
| B | the `expose` lambda must be pure (CAP-040) and capture no `Shared`, `Chan`, `GoRef` or capability | closes the example | a secret must reach a sink (a TLS handshake, a DB login), which needs a capability: `expose` becomes unusable without a second API |
| C | B, plus sink APIs of `std` that accept `Secret[T]` directly (`pool.connect(password: Secret[str])`), so user code rarely needs `expose` | closes the example and stays usable | larger `std` surface; `expose` remains for the rest, audited |

## Recommendations / Next Steps

A for the wording now (the README example already passes a `Secret[str]` straight to `Pool.connect`, which is C's shape),
C as the design direction for `std`. Record that zeroing and `mlock` are best-effort on the Go backend (the Go runtime may
copy a value before it is zeroed).
