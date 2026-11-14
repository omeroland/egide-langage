---
id: Q-0057
rule: TYP-042, TYP-045, ERR-030, ERR-032, CON-021
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0050, T-0062, T-0063]
severity: high
status: open
---
## Question

**Executive summary.** `Send` and `Resource` are inferred marker traits and there is no `Copy` trait (TYP-045). The spec
does not say how the body of a generic function is checked when its type parameter may be a resource or may not be
`Send`. Either the check happens after monomorphisation (errors inside library code, against design principle 3, "local
reasoning") or generic code needs a bound that the spec does not define.

## Example

```egide decls
fn dup[T](x: T) -> (T, T):
    (x, x)                      # copies x

fn in_task[T](s: Scope, x: T) -> Task[T]:
    s.spawn(() => x)            # requires T: Send
```

`dup[File]` copies a resource (ERR-030); `in_task[Shared[Cell]]` sends a non-`Send` value (CON-021).

## Core analysis

*Established*: TYP-042 (generics are monomorphised, bounds are traits); TYP-045 (markers inferred; every non-resource
value can be copied). *Extrapolated*: `List[T]`, `Map[K, V]`, `Option[T]` and `Chan[T]` need the same answer, since a
`List[File]` cannot offer `xs[i]` returning a copy. Swift needed several releases to add non-copyable generics for this
reason.

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | a type parameter is copyable and not a resource by default; a parameter that accepts resources is written `T: ?Resource` (spelling to decide) and its body is checked linearly; `Send` is an ordinary bound `T: Send` | definition-site checking; errors at the call site | one new bound form; `std` collections need two API tiers |
| B | check after monomorphisation | no new syntax | errors point inside library bodies; a library change can break callers silently |
| C | resources can never be type arguments | simplest | no `Option[File]`, no `Result[File, E]`: `dir.open(...)?` stops working |

## Recommendations / Next Steps

A. C is excluded by ERR-031's own example (`dir.open("app.toml")...?` is a `Result` of a resource). Needs an ADR before
T-0050 (generics and traits) is split, because it shapes the signatures of `std.prelude`.
