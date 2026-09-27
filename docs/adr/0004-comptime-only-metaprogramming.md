# ADR-0004: `comptime` as the only metaprogramming

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 9

## Decision

No macros. Pure Égide functions run at compile time; types are comptime values; derivations and prefixed string
templates are comptime functions; reflection exists only at compile time. Compile-time code has no capability, so builds
cannot perform I/O (only declared `embed` files).

## Alternatives considered

| Option | Why not |
|--------|---------|
| Hygienic declarative macros | a second language inside the language; hard to audit |
| Procedural macros (Rust) | arbitrary code execution at build time — a supply-chain attack vector |

## Consequences

The same interpreter serves comptime, the REPL and `egide run`, so it must be built early (phase 1).
