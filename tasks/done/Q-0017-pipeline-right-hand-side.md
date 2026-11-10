---
id: Q-0017
rule: SYN-037, SYN-100, SYN-031, SYN-033
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0011, T-0033]
severity: medium
status: decided
---
## Question

SYN-037 defines `x |> f(a)` as `f(x, a)` and `x |> f` as `f(x)`. The EBNF allows any `cond_expr` on the right side
(`pipe_expr = cond_expr { "|>" cond_expr }`). Unspecified:

- method callee: `x |> obj.m(a)`. Is it `obj.m(x, a)`?
- postfix after the call: `x |> f(a)?`. Is it `f(x, a)?` or `(f(a))?` with `x` inserted later?
- curried calls: `x |> f(a)(b)`.
- non-call right sides: `x |> (g if c else h)`, `x |> a + b`. Because `|>` binds looser than comparisons (SYN-100),
  `xs |> len == 0` parses as `xs |> (len == 0)`.
- trailing blocks: `xs |> each() fn(x): …`.
- interaction with SYN-031 (is a piped `bool` positional?) and with SYN-033 (callee's first parameter is `inout`:
  there is no `&`).

## Options

A. **Restrict.** The right side MUST be a path or a call `callee(args)`, optionally followed by `?`. `x` is inserted
   as the first positional argument: `x |> c(args)?` is `c(x, args)?`, and `x |> o.m(a)` is `o.m(x, a)`. Anything else
   is error E0108 "the right side of `|>` must be a function or a call". A piped value counts as a positional argument
   for SYN-031. Piping into an `inout` first parameter is an error ("use `f(&x)`"). A trailing-block right side is not
   allowed (block-ended expression, ADR-0013).
B. Allow any expression that evaluates to a function and call it with `x` (F#/Elixir style). This is more general and
   loses the "exactly `f(x, a)`" reading.

## Recommendation

A. It keeps SYN-037 a purely syntactic desugaring, which T-0033 implements in HIR. `xs |> len == 0` then gets E0108
with the hint "parenthesise: `(xs |> len) == 0`", which is better than a type error. The AST (T-0008) keeps a `Pipe`
node. The parser (T-0011) or the desugarer checks the shape. The spec should say which.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Option A. The right side of `|>` is a path or a call, optionally followed by `?`; the value is inserted as the first positional argument; anything else is E0108. The parser checks the shape (cover).

ADR-0015. Rules: SYN-037.
