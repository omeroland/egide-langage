---
id: Q-0054
rule: PKG-003, GO-046
raised_by: language-architect/ADR-0024
blocking: []
severity: medium
status: open
---
## Question

**Executive summary.** PKG-003 says only `pub` items are visible outside their module, but chapters 4 and 10 do not say
whether it governs the fields of a `struct`, whether a field can carry `pub` individually, or what a construction expression
outside the module may do with a struct that has a non-`pub` field. GO-046.1 (ADR-0024) makes a struct decodable by the
native dispatcher only if all its fields are `pub`, which relies on that reading.

## Core analysis

*Established* (spec text): `spec/10-modules-and-packages.md` PKG-003 names items; TYP-031 and TYP-032 state that a validated
type's invariant is assumed everywhere, which presumes a field cannot be set from outside the constructor.
*Extrapolated*: the same reasoning applies to a struct with private fields (the constructor is the only door).

Options:

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | fields are private by default and `pub` per field; a struct literal outside the module needs all fields `pub` | matches Rust; supports the decodable test; invariants are enforceable | adds one visibility keyword position |
| B | fields follow the visibility of the struct | no new syntax | a `pub struct` can no longer hide a field; invariants on records are unenforceable |

## Recommendations / Next Steps

Answer with A, as a short ADR amending PKG-003 and the grammar (`field_decl` gains an optional `pub`); add the rule ids for
construction and for pattern matching on a struct with private fields (E-code to allocate). Until then GO-046.1 treats a
struct as decodable only if every field is `pub` under reading A.
