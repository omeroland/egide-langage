---
id: Q-0061
rule: CAP-033, CAP-040, CON-050
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0071]
severity: medium
status: open
---
## Question

**Executive summary.** A lambda that uses an implicit capability captures it at creation (CAP-033), so its type is a
plain `fn(A) -> B`. CAP-040 exempts lambda arguments from purity. A "pure" function can therefore perform I/O through a
closure it receives, and nothing in a function type distinguishes a closure that holds authority from one that does not.
Rules that rely on purity of a function-typed argument (CON-050, CT-001) need a precise definition.

## Example

```egide fragment
given sys.log.json(level: Info):
    let f = (x: int) => audit(x)      # audit uses `log`; f has type fn(int) -> int and holds Log
    std.par.map(xs, f)                # CON-050: "f MUST be pure or Send"
```

## Core analysis

*Established*: the three rules above. *Extrapolated*: this is ordinary object-capability behaviour (authority follows
references) and is not a soundness hole for INT-003. It does weaken the reading of ADR-0003 "the signature reveals the
effect": that holds for `using`, not for captured authority.

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | define two notions: a **pure function** (CAP-040, about its own body) and a **pure value** (a closure that captures no capability, `Shared`, `Chan` or `GoRef`, transitively); the compiler infers the second like `Send`, and CON-050, CT-001 and TYP-031 require it | precise; no new syntax | one more inferred marker |
| B | closures may not capture capabilities; they must declare `using` | effects fully visible in types | needs effect polymorphism for `map`, `filter`, … : the separate effect system that INT-010 excludes |

## Recommendations / Next Steps

A. Amend CAP-040 and CON-050, and reword ADR-0003's consequence to "the effect system covers `using`; captured authority
follows data flow".
