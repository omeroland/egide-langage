# ADR-0014: Generic arguments in expressions and types

- Status: Proposed
- Date: 2026-11-09
- Deciders: owner
- Spec chapters affected: 3, 4, 9 (and `spec/grammar/egide.ebnf`)
- Raised by: T-0022 (spec audit of chapters 2 and 3). Answers Q-0009 (slice-or-index ambiguity, PR #4) through
  SYN 043; `slice_or_index` is deleted.

> New rule ids are written with a space (`SYN 042`) because `tools/check-spec.sh` rejects references to ids that do
> not exist yet in `spec/`.

## Context

The spec and the examples pass explicit generic arguments in expressions: `db.one[Tenant](sql"…")`,
`req.json[Tenant]()`, `toml.parse[Config](…)` (ch. 8), `Args.parse[Options](…)` (`examples/wc.egd`). Types are also
comptime values passed in parentheses: `fields(T)` (CT-020), `Buffer(4096)` (CT-011). The grammar does not support
this:

1. In expressions, `[ … ]` is `slice_or_index`, which holds **one** expression. `f[Map[str, int]]()` and
   `f[A, B]()` do not parse. `f[int?]()` parses as error propagation on `int`. `f[fn(int) -> int]()` does not parse.
2. `slice_or_index = expr | [ expr ] ( ".." | "..=" ) [ expr ]` overlaps with `expr`, which already contains
   `range_expr` with optional bounds. This is a reduce/reduce conflict.
3. In types, `type_arg = type | expr` is a reduce/reduce conflict on every path (`Array[u8, n]`: is `n` a type or a
   comptime value?).
4. `base_type = "(" [ type { "," type } [ "," ] ] ")"` makes `(int)` a one-element tuple type, whereas SYN-038
   makes `(x)` a parenthesised expression and `(x,)` the one-element tuple. There is no way to parenthesise a type.
5. In `fn f() -> fn(int) -> int using Log:`, it is undecidable with one token of lookahead whether `using` belongs
   to `f` (`using_clause`, `IDENT ":" type`) or to the returned function type (`using type`). In `fn() -> int?` it is
   unspecified whether `?` applies to `int` or to the function type.

These block T-0011 (expressions) and T-0009 (types in declarations), and they fix the AST shape that T-0008 is
defining now.

## Decision

Use Go's approach: **one syntax for `[ … ]` argument lists, disambiguated by name resolution, not by the parser.**
This follows from CT-011 ("`type` is the type of types at compile time"): types are already values in comptime
argument positions.

**New SYN 042 (Generic argument lists).** "A postfix `[ a1, …, an ]` holds *generic arguments*. Each argument is an
expression, or one of the type-only forms `fn(…) [-> T] [using …]` and `dyn B1 + … + Bn`. After name resolution:
if the operand denotes a generic function, a generic type or a comptime type constructor, the arguments are type
arguments or comptime value arguments (a generic argument that resolves to a type is a type, otherwise it is a
comptime value, evaluated under CT-001..CT-004 and CAP-041); otherwise the operation is indexing, which takes exactly one argument, and a type-only form or a
second argument is a compile-time error. Inside a generic argument, a postfix `?` applied to a type is `Option`
(SYN-041)."

```egide
let t = req.json[Tenant]()?                  # instantiation
let m = decode[Map[str, List[int]]](raw)?    # nested
let c = cache[Key, fn(int) -> int?]()        # type-only form; `int?` is Option[int]
let x = xs[i]                                # indexing (xs is a value)
let y = xs[i, j]                             # error: indexing takes one index
```

**New SYN 043 (Slices are indexing with a range).** "`xs[a..b]`, `xs[a..]`, `xs[..b]` and `xs[..]` are indexing with
a range expression (SYN-040 is unchanged)." This removes `slice_or_index`.

**New SYN 044 (Types as comptime arguments).** "Outside `[ … ]`, a type passed as an expression argument
(`fields(T)`, CT-020) MUST be a path, optionally with generic arguments, or a tuple of such. Other type forms MUST
first be named with `type F = …`."

**New TYP 006 (Type syntax disambiguation).** "`(T)` is `T`; a one-element tuple type is `(T,)` (consistent with
SYN-038). In a return type, `?` binds to the nearest type: `fn() -> int?` returns `Option[int]`; an optional
function is `(fn() -> int)?`. A function type used as a return type MUST be parenthesised:
`fn f() -> (fn(int) -> int) using log: Log:`. A function type with several `using` capabilities joins them with
`+`: `fn(Config) using Client + Log`." Negative example: `fn f() -> fn(int) -> int using Log:` is the syntax
error E0105 "parenthesise a function type used as a return type".

**EBNF**:

```ebnf
type          = ret_type | fn_type ;
ret_type      = simple_type [ "?" ] ;                    (* every type except an unparenthesised fn type *)
simple_type   = path [ "[" gen_args "]" ]
              | "(" ")" | "(" type ")" | "(" type "," [ type { "," type } [ "," ] ] ")"
              | "dyn" bound { "+" bound }
              | "Self" ;
fn_type       = "fn" "(" [ type { "," type } ] ")" [ "->" ret_type ] [ "using" fn_caps ] ;
fn_caps       = bound { "+" bound } ;                    (* capability types are nominal *)
bound         = path [ "[" gen_args "]" ] ;               (* traits and capabilities; was `bound = type` *)
gen_args      = gen_arg { "," gen_arg } [ "," ] ;
gen_arg       = expr | fn_type | "dyn" bound { "+" bound } ;
postfix_expr  = primary { "(" [ args ] ")" | "[" gen_args "]" | "." IDENT | "?" } ;
```

`fn_sig` uses `ret_type` after `->`. `slice_or_index` and `type_arg` are deleted. `dyn A + B` (used in ERR-020) is
now in the grammar. A function type joins several capabilities with `+`, `fn(Config) using Client + Log`, because
`fn() using A, B` is ambiguous inside a parameter or argument list and `using (A, B)` is ambiguous with a tuple type;
CAP-033's single-capability example is unchanged. `gen_arg = fn_type` relies on ADR-0013, which removes the `fn` lambda from `expr`.

Checked mechanically: a Menhir transcription of this EBNF together with ADR-0013 (simplified literals, patterns and
bitwise levels) reports 0 conflicts; with `fn_caps` as a parenthesised list or with `dyn` capabilities it reports
conflicts, hence the form above.

Reproduction of the conflict check (not committed: the ADR template has no attachment slot, and the proposed
grammar is only a simplified transcription). Write each production above in Menhir syntax with tokens for the lexer
terminals, replace literals and patterns by a few representative alternatives, then run `menhir --explain file.mly`
and read `file.conflicts`. The scratch file used for this ADR (about 110 lines) is attached as a comment on PR #6.

## Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| A. Unified `[ … ]`, resolution decides (this ADR, Go 1.18) | one syntax, reads like the spec examples; LR(1); types-as-values is already in CT-011 | the resolver converts expression ASTs to types | chosen |
| B. Rust-style turbofish `f.[T](x)` or `f::[T](x)` in expressions | purely syntactic | extra punctuation that the examples do not use; still needs fixes 3–5 | uglier, solves less |
| C. No explicit generic arguments in expressions; rely on inference and `let x: T = …` | smallest grammar | `fields(Map[str, int])` (CT-020) needs types in expressions anyway; `req.json[Tenant]()` becomes two lines | does not remove the need |
| D. Angle brackets `f<T>(x)` | familiar | `a < b > (c)` ambiguity, the reason Go chose `[ ]` | ambiguous |

## Consequences

- Complexity budget: removes two productions (`slice_or_index`, `type_arg`), adds one resolution rule. No new
  feature: every form above is already used by the spec or the examples.
- Security: INT-001..005 are unaffected. A generic argument that resolves to a comptime value is evaluated at build
  time, so it is subject to CT-001, CT-003 and CAP-041 (only pure functions, bounded, no capability). Deciding
  type-versus-value in the resolver must not create a way to run impure code at build time: SYN 042 adds "a comptime
  value argument is evaluated under CT-001..CT-004".
- Implementation: T-0008 (AST: `Index of expr * gen_arg list`, `gen_arg = Expr | TypeOnly of ty`; types keep their
  own AST with `TyApp of path * gen_arg list`), T-0011 (postfix), T-0009 (types), T-0030 (resolver turns `Index` into
  `Instantiate` when the operand is generic; converts expression-shaped arguments to types), T-0031/T-0050.
  Diagnostics: E0105 (syntax), plus resolver codes in E02xx for "indexing takes one index" and "type syntax is not a
  value here", allocated by the implementing task.
- Migration: none.
- Index: the owner adds a row for this ADR to `docs/adr/README.md` on acceptance.
