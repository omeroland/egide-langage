---
id: Q-0045
rule: MEM-070
raised_by: tooling-engineer/T-1120
blocking: []
status: open
---
## Question

C FFI mechanism. PKG-030 and MEM-070 mention C FFI and the manifest entry `ffi:<library>`, but no chapter says how a C function is declared or called, how types map, or how the capability and purity rules apply. This is the cgo counterpart.

## Example

```egide
extern c "libpq": fn PQconnectdb(conninfo: CStr) -> Ptr[PGconn]
```

## Options

A. No C FFI before phase 7; remove the mention. B. FFI only through `import go` and cgo in Go modules. C. A dedicated chapter after the native backend exists.

## Recommendation

B for phases 0-6, then C; update PKG-030 text accordingly. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).
