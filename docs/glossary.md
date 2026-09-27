# Glossary

| Term | Meaning |
|------|---------|
| ADR | Architecture Decision Record in `docs/adr/`; the only way to change the spec |
| Attenuation | deriving a capability with less authority from another (CAP-003) |
| Capability | an unforgeable value granting authority over an external resource (ch. 6) |
| COW | copy-on-write: the physical copy of a shared value happens at its first mutation (MEM-010) |
| Exclusivity | an `inout` argument is accessible only to the callee during the call (MEM-021) |
| `given` | block making capability values implicitly available to `using` clauses (CAP-031) |
| HIR / MIR | high-level (typed, desugared) and mid-level (CFG) intermediate representations |
| ICE | internal compiler error |
| Layout algorithm | conversion of indentation into NEWLINE/INDENT/DEDENT tokens (LEX-030..035) |
| MVS | minimal version selection (PKG-020) |
| ORC | targeted cycle collection for potentially cyclic `Shared` types (MEM-061), after Nim 2 |
| Perceus | precise reference counting with in-place reuse, after Koka and Lean 4 |
| Pure | a function with no authority (CAP-040); may run at compile time |
| Resource | a value that must be closed (`Close`), never implicitly copied (ERR-030) |
| Sink type | a type that reaches an interpreter (`Sql`, `Html`, `Cmd`…), buildable only by templates (ch. 12) |
| Task | a lightweight thread attached to a scope (ch. 7) |
| Template | a prefixed string literal desugared by a comptime function (CT-040) |
| `using` | implicit capability parameters, part of the function type (CAP-030) |
| Validated type | a newtype with an invariant checked at construction (TYP-031) |
| Value semantics | variables hold independent values; no shared mutable references (ch. 5) |
