---
id: Q-0020
rule: SYN-002, SYN-003, SYN-010, SYN-021, SYN-061, TYP-031, CT-002, LEX-022, LEX-060
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0009, T-0010]
severity: low
status: decided
---
## Question

These are small mismatches between the prose and the EBNF. Each needs a yes/no answer so that the parser tasks write
the right parse-fail tests.

1. **SYN-061 vs `simple_stmt`.** SYN-061 lists expression, `return`, `break`, `continue`, assignment and `let`. The
   EBNF `simple_stmt` also has `var`, `comptime let`, `defer` and `yield`, and it had let-else, which ADR-0013 moves
   out.
2. **Empty blocks.** There is no `pass`. Is `()` (the unit literal) the empty statement? The spec should say so
   (`fn noop(): ()`).
3. **Empty bodies.** `struct`, `enum`, `trait` and `impl` bodies need at least one item. A marker struct
   (`struct Marker`), or an impl of a trait whose methods all have default bodies, cannot be written.
4. **`import a.{X, Y} as z`** is allowed by the EBNF and has no meaning.
5. **`pub impl …`** is allowed by the EBNF (`top_decl` puts `pub` before every declaration). Impls have no visibility.
6. **`type A = int where self > 0`** (no `new`) is allowed by the EBNF. TYP-031 defines `where` only for `new` types.
7. **`comptime let` at top level** duplicates top-level `let`, which is already comptime (CT-002). SYN-003 lists both.
8. **`..=` without an upper bound** (`a..=`, `..=`) is allowed by `range_expr` and has no meaning.
9. **`self` parameters.** `param` allows `comptime self`, `self` in a non-first position and `self` in free
   functions. SYN-021 implies otherwise, but there is no diagnostic.
10. **LEX-022.** Because `go` is a keyword after `import`, a top-level module named `go` can never be imported
    (`import go.util`).
11. **LEX-060.** "`..` followed by `=` is `..=` only when the next character is not `=`": `a..==b` is invalid with or
    without the exception, so the exception changes no outcome.

## Recommendation

1. Align SYN-061 with the EBNF: expression, assignment, `return`, `break`, `continue`, `defer`, `yield`. A `let`,
   `var` or `comptime let` in a single-line block is an error ("binding is immediately out of scope"). Spec edit to
   SYN-061, and EBNF `suite = single_stmt NEWLINE | …` with `single_stmt` listing those forms.
2. Yes: add to SYN-010 "an empty block is written `()`".
3. Allow `struct Name` and `impl … for …` without `:` and a body (the EBNF gains `[ ":" INDENT … DEDENT ]`).
   Empty enums and traits stay errors.
4. Error: `as` only on a single-path import.
5. Error: `pub` is not allowed on `impl`.
6. Error: `where` requires `new`.
7. Forbid `comptime` on a top-level `let` (one spelling). Keep `comptime let` inside function bodies.
8. Error: `..=` requires an upper bound.
9. Add to SYN-021: "`self` is allowed only as the first parameter of a function in a `trait` or `impl`; its modes are
   none, `inout`, `take`". Use a new E01xx diagnostic.
10. Accept and document: "no top-level module may be named `go`".
11. Simplify LEX-060 to plain maximal munch.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

1 single-line block holds expression, assignment, return, break, continue, defer, yield (bindings are E0109). 2 the empty block is `()`. 3 `struct Name` and `impl T for U` may omit the body. 4 `as` only on single imports. 5 `pub impl` is an error. 6 `where` requires `new`. 7 no top-level `comptime let`. 8 `..=` needs an upper bound. 9 `self` first parameter in trait/impl only (E0114). 10 no module named `go` (E0116). 11 LEX-060 is plain maximal munch.

ADR-0015. Rules: SYN-001, SYN-002, SYN-003, SYN-010, SYN-021, SYN-024 (new), SYN-040, SYN-061, LEX-060; EBNF.
