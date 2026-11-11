---
id: Q-0044
rule: SYN-023
raised_by: tooling-engineer/T-1120
blocking: [T-1127, T-1130]
status: open
---
## Question

Attributes for benchmarks and fuzzing. The attribute set is closed (SYN-023). Go has benchmark and fuzz functions; Égide has `@test`, `@integration`, `@property`.

## Example

```egide
@bench
fn parse_big() -> ():
    ...
```

## Options

A. Add `@bench` (fn, no arguments) and treat `@property` as the fuzz entry point. B. Add `@bench` and `@fuzz`. C. Benchmarks in `bench/` as ordinary programs, no attribute.

## Recommendation

A: one fewer attribute, and a property with coverage feedback is a fuzz test; C matches the current docs/testing.md but gives no `egide bench` selection. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).
