---
id: Q-0040
rule: TOOL-010
raised_by: tooling-engineer/T-1120
blocking: [T-1153]
status: open
---
## Question

Conditional compilation and build constraints. Go has `//go:build` constraints and `-tags`; chapter 13 has `--target os-arch` but no rule for code that exists on one target only.

## Example

```egide
@cfg(os: linux)   # not in SYN-023
fn open_epoll() -> Epoll: ...
```

## Options

A. No conditional compilation; per-target code lives in `std` or behind `import go` files. B. A closed attribute `@cfg(os:, arch:, backend:)` evaluated at resolve time, no free-form tags. C. Free-form tags like Go.

## Recommendation

B is the smallest set that covers OS and backend differences and keeps the build reproducible (PKG-050); C makes the configuration an unchecked input. A is acceptable if the standard library owns all platform code. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).
