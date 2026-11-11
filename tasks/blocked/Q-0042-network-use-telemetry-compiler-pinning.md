---
id: Q-0042
rule: PKG-041
raised_by: tooling-engineer/T-1120
blocking: [T-1153]
status: open
---
## Question

Network use, telemetry, compiler pinning. Three statements are absent from the spec: `egide build` makes no network access on a complete lockfile (only in the tooling role file); the toolchain sends no telemetry; the manifest cannot require a compiler version and the compiler never downloads another one (Go has `GOTOOLCHAIN` and `toolchain` lines).

## Example

`egide build` run in a container without network.

## Options

A. State all three as rules (ADR-0019 item 3) and add `[package] egide = ">= 0.5"` that only checks. B. Do nothing.

## Recommendation

A: they are consequences of PKG-041/042 and INT-005 that tooling authors would otherwise decide differently. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).
