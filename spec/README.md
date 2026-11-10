# The Égide Language Specification

Version **0.2-draft** — this directory is the **normative source of truth**. When the compiler, the standard library,
a test or a document disagrees with the specification, the specification wins and the other artefact has a bug —
unless an accepted ADR says the specification itself is wrong, in which case the specification is amended first.

## Chapters

| # | Chapter | Rule prefix |
|---|---------|-------------|
| 1 | [Introduction, goals and complexity budget](01-introduction.md) | `INT` |
| 2 | [Lexical structure](02-lexical-structure.md) | `LEX` |
| 3 | [Syntax](03-syntax.md) — full grammar in [`grammar/egide.ebnf`](grammar/egide.ebnf) | `SYN` |
| 4 | [Types](04-types.md) | `TYP` |
| 5 | [Values and memory](05-values-and-memory.md) | `MEM` |
| 6 | [Capabilities](06-capabilities.md) | `CAP` |
| 7 | [Concurrency](07-concurrency.md) | `CON` |
| 8 | [Errors and resources](08-errors-and-resources.md) | `ERR` |
| 9 | [Compile-time evaluation](09-comptime.md) | `CT` |
| 10 | [Modules and packages](10-modules-and-packages.md) | `PKG` |
| 11 | [Go interoperability](11-go-interop.md) | `GO` |
| 12 | [Security types of the standard library](12-stdlib-security.md) | `SEC` |
| 13 | [Toolchain](13-toolchain.md) | `TOOL` |
| A | [Appendix: Go purity list](appendix/go-purity-list.md) | `GOP` |

## Conventions

- The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** are to be interpreted as in RFC 2119.
- Every normative statement carries a stable **rule identifier**, written in bold brackets in Markdown (`**[LEX-012]**`). Identifiers are never reused or
  renumbered; a deleted rule is kept as `~~LEX-012~~ (removed by ADR-00NN)`.
- Tests reference rules in their header (`# spec: LEX-012, SYN-040`), diagnostics reference the rule they enforce,
  and pull requests cite the rules they implement. `tools/check-spec.sh` verifies that identifiers are unique.
- Code blocks tagged `egide` are **examples**: non-normative unless the surrounding text says otherwise. They are
  extracted and parsed by the conformance suite, so the info string says what the block is:

  | Info string | Content | Extractor wraps it as |
  |-------------|---------|-----------------------|
  | `egide` | a complete file (starts with `module`, after an optional shebang) | nothing |
  | `egide decls` | declarations (and imports), no `module` line | `module spec.decls` plus the block |
  | `egide fragment` | a statement sequence | `module spec.fragment`, `fn fragment():` and the block indented |
  | `egide invalid` | a block that MUST be rejected by the parser | like `fragment` or `decls`, expected to fail |

  Blocks inside a list item are dedented by their common indentation. A line marked `# error RULE-ID` is a
  semantic error reported by a later phase; it does not stop the block from parsing. Token-by-token annotations
  (`# FN IDENT …`) are comments.
- "Compile-time error" means the program is rejected with a diagnostic; the diagnostic code catalogue lives in
  [`docs/diagnostics.md`](../docs/diagnostics.md).
- "Panic" means the current task is aborted as described in ERR-040 (ch. 8).

## Changing the specification

Only through an accepted ADR (see [`docs/adr/README.md`](../docs/adr/README.md)). Implementation agents MUST NOT edit
this directory; a Claude Code hook enforces it (`tools/hooks/guard-protected-paths.sh`).
