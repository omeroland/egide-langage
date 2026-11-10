---
id: Q-0008
rule: SYN-012
raised_by: syntax-engineer/wave1
blocking: [T-0010]
---
## Question

The EBNF production `place = IDENT { "." IDENT | "[" expr "]" } ;` (spec/grammar/egide.ebnf, used by the assignment
statement) only admits an `IDENT` as the root of an assignable place. `self` is a reserved keyword (LEX-021), not an
`IDENT`, so `self.count += 1` is not derivable. Yet SYN-012 allows assignment to "`inout` parameters and their
fields/elements", SYN-021 and MEM-024 define `inout self` methods, and assigning a field of `inout self` is the main
reason such methods exist. Is assignment through `self` intended to be part of the grammar?

## Example

```egide
module counters

struct Counter:
    count: int

impl Counter:
    fn bump(inout self):
        self.count += 1          # not derivable from `place` as written
```

## Options

A. Allowed: change the production to `place = ( IDENT | "self" ) { "." IDENT | "[" expr "]" } ;`.
B. Forbidden: `inout self` methods may only mutate `self` by calling other `inout self` methods (this seems to make
   them unusable for structs with plain fields).

## Recommendation

A, because SYN-012 and MEM-024 already treat `inout self` as an assignable place; only the EBNF omits it. The AST
added by T-0008 follows the grammar as written (`place.root : ident`); option A needs one extra constructor for the
place root, which T-0010 (statements parser) would add together with the grammar fix.
