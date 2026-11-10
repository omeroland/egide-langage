---
id: Q-0013
rule: SYN-050, SYN-051, TYP-060, TYP-061, LEX-023
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0012, T-0032, T-0008]
severity: high
status: decided
---
## Question

`simple_pattern = "_" | IDENT | literal_pattern | range_pattern | path "(" … ")" | …`.

1. **Bare identifiers.** In `case None:`, `case Ok(None):` and `case Available:` (enum `State` in ch. 3 §3.3), the
   grammar reads the name as a *binding* that matches anything. Nothing says that a name which resolves to a
   fieldless variant or a constant is a constant pattern. With binding semantics, `case None:` silently matches
   `Some(_)` too. This is the classic Rust/Swift footgun, and here the spec does not even define the rule.
2. **Qualified names without parentheses do not parse**: `case Status.NotFound:`, `case State.Available:`,
   `case http.StatusOK:`. The only dotted pattern is `path "(" … ")"`.
3. **Positional sub-patterns on named-field variants.** The §3.5 example `case Circle(_):` uses a positional pattern
   for `Circle(radius: r)`. SYN-032 allows positional *construction* only for single-field variants. Is the same rule
   meant for patterns?
4. **Literal patterns** omit `DURATION`, `BYTES` and `RAW_STRING`. Range patterns have no open form (`5..`). Is that
   intended?

## Example

```egide
match res:
    case Ok(Some(t)): use(t)
    case Ok(None): missing()     # binding `None`, or the variant?
    case Err(e): fail(e)
match state:
    case State.Available: 1      # syntax error today
    case _: 0
```

## Options

A. **Resolution-based** (Rust): a bare IDENT that resolves to a fieldless variant or a constant is a constant pattern,
   and otherwise a binding. This needs name resolution to parse the meaning, and a typo in a variant name becomes a
   catch-all.
B. **Case-based, mechanical** (OCaml, Haskell): a pattern IDENT that starts with an uppercase letter is a
   constructor/constant pattern and MUST resolve (E02xx "unknown variant or constant `X`"). A lowercase IDENT or `_`
   is a binding. A dotted path, with or without `( … )`, is always a constructor/constant pattern. This matches
   LEX-023 conventions: variants are `UpperCamelCase`, comptime constants are `SCREAMING_SNAKE_CASE`.
C. Always require qualification or parentheses (`None()`, `Option.None`). This is noisy for the prelude.

## Recommendation

B: decidable by the parser, no silent catch-all, and consistent with the naming rules. Spec edits:
SYN-050 gains "a pattern identifier starting with an uppercase letter, or a dotted path, denotes a variant or
constant; other identifiers bind". The EBNF gets `simple_pattern = … | path [ "(" [ field_patterns ] ")" ]`.
For item 3: positional sub-patterns are allowed for single-field variants (mirror SYN-032). For item 4: add
`DURATION` and `BYTES` literals and keep ranges closed. The pattern AST in T-0008 needs `PConst of path` distinct
from `PBind of ident`.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Option B (case-based). Uppercase lone names and any dotted or constructor name are variants/constants and MUST resolve; lowercase lone names bind; variant and constant names must start uppercase (E0113). Item 3: positional sub-patterns follow SYN-032. Item 4: add duration, raw string and bytes literal patterns; ranges stay closed.

ADR-0015. Rules: SYN-050, SYN-053 (new), SYN-024 (new); EBNF `simple_pattern`, `literal_pattern`.
