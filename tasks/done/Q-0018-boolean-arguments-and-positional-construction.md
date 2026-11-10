---
id: Q-0018
rule: SYN-031, SYN-032, TYP-030, ERR-040
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0031, T-0052]
severity: medium
status: decided
---
## Question

1. **SYN-031** ("boolean arguments MUST be named when the parameter type is `bool`"), read literally, rejects:
   - `Some(true)`, `Ok(false)`, `xs.push(true)`, `m.insert(k, true)`: generic parameters instantiated to `bool`;
   - `assert(a == b)`: `assert`'s only parameter is a `bool` (ERR-040 mentions `assert`), so every assertion needs
     `assert(cond: …)`;
   - `set_enabled(flag)`: a single-parameter function where the name already says what the flag means.
   Is "parameter type" the *declared* type or the *instantiated* type? Do one-parameter functions count?
2. **SYN-032** allows positional construction "only for single-field variants and tuples", but TYP-030 constructs
   newtypes positionally (`UserId(42)`), and the README and examples write `Response(Status.BadRequest)`. If
   `Response` is a struct, those examples are errors.

## Example

```egide
send(msg, urgent: true)       # intended target of SYN-031
let o = Some(true)            # error under the literal reading
assert(total == 3)            # error under the literal reading
let id = UserId(42)           # not covered by SYN-032
```

## Options for item 1

A. Declared type exactly `bool` (generic instantiations exempt), any arity. `assert(cond: x)` is required.
B. Declared type exactly `bool`, and the callee has **two or more** parameters, not counting `self` and `using`
   parameters. `assert(c)` and `set_enabled(f)` are fine, and `send(msg, true)` is still an error.
C. Only boolean *literals* passed positionally are errors. This catches `send(msg, true)` but not
   `send(msg, flag)`.

## Recommendation

1. B. It targets the readability trap (an anonymous `true` among other arguments) without taxing generic code or
   one-argument predicates. Spec edit to SYN-031: "when the parameter's declared type is `bool` and the function has
   at least two parameters other than `self` and `using` parameters". A piped value counts as positional (Q-0017).
2. Add to SYN-032: "and newtypes (`UserId(42)`, TYP-030)". The ch. 12 `std.http` documentation should say whether
   `Response(status)` is a function. The parser is not affected (both forms parse as calls).

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Item 1 option B: SYN-031 applies to declared type exactly `bool` with at least two parameters other than `self` and `using`; generics and one-parameter functions are exempt; a piped value counts as positional. Item 2: SYN-032 adds newtypes and variants declared with positional fields (the original text would have made `Pair(int, int)` unconstructible).

ADR-0016. Rules: SYN-031, SYN-032. Type checker: T-0031, T-0052.
