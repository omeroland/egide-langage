---
id: Q-0009
rule: SYN-040
raised_by: syntax-engineer/wave1
blocking: [T-0011]
status: decided
---
## Question

`postfix_expr = primary "[" slice_or_index "]"` with `slice_or_index = expr | [ expr ] ( ".." | "..=" ) [ expr ]`
(spec/grammar/egide.ebnf) is ambiguous. `expr` already derives ranges through `range_expr`, whose bounds are
`bitor_expr`s, so a range between two `bitor_expr`s has two derivations. When a bound is a lower-precedence
expression, the two derivations give different trees for the same input, although the grammar header claims LR(1).

## Example

```egide
xs[a < b .. c]      # expr alternative: a < (b..c)   slice alternative: (a < b)..c
xs[a or b .. c]     # expr alternative: a or (b..c)  slice alternative: (a or b)..c
```

## Options

A. Drop the slice alternative: `slice_or_index = expr`. Slices rely on `range_expr`; bounds are limited to
   `bitor_expr`, and `xs[a < b .. c]` means `a < (b..c)` (a type error in practice). Writing `xs[(a < b)..c]` is
   required for the other reading.
B. Keep the slice alternative and state in the grammar and SYN-040 that inside `[ ]` it wins: both bounds are full
   `expr`s, so `xs[a < b .. c]` means `(a < b)..c`. Menhir needs a dedicated rule or precedence declaration.

## Recommendation

A: it is simpler, matches the precedence table (SYN-100 level 10 puts `..` above comparisons), and keeps one meaning
for `..` everywhere. The AST (`Index` with a `Range` index) represents both options, so T-0008 is unaffected.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Option A: `slice_or_index` is deleted; `xs[a..b]` is indexing with a range expression, `..` keeps SYN-100 level 10, so `xs[a < b .. c]` is `a < (b..c)`.

ADR-0014. Rules: SYN-040, SYN-043 (new); EBNF `postfix_expr`, `gen_args`.
