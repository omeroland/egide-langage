# Architecture Decision Records

An ADR records one significant decision: language semantics, compiler architecture, process. **Any change to `spec/`
requires an accepted ADR.**

## Lifecycle

`Proposed` → `Accepted` | `Rejected` → (later) `Superseded by ADR-NNNN`.

1. Any agent may write a `Proposed` ADR (copy [`template.md`](template.md), next free number) in a PR labelled `adr`.
2. The `language-architect` role reviews it against the complexity budget (spec/01 §1.4) and the security goals
   (INT-001..005); the `security-reviewer` reviews every ADR touching ch. 5, 6, 9, 11 or 12.
3. **Only the human owner accepts or rejects.** Agents never merge an ADR PR.
4. The same PR that accepts an ADR contains the spec edits, with new rule ids, and follow-up tasks in `tasks/backlog/`.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-ocaml-bootstrap-compiler.md) | OCaml 5 for the bootstrap compiler | Accepted |
| [0002](0002-mutable-value-semantics.md) | Mutable value semantics instead of borrow checking | Accepted |
| [0003](0003-capabilities-as-sole-authority.md) | Object capabilities as the only authority; `using` as effect system | Accepted |
| [0004](0004-comptime-only-metaprogramming.md) | `comptime` as the only metaprogramming | Accepted |
| [0005](0005-indentation-syntax-and-trailing-blocks.md) | Indentation-based syntax and trailing blocks | Accepted |
| [0006](0006-orc-cycle-collection.md) | Targeted cycle collection for `Shared` | Accepted |
| [0007](0007-structured-uncoloured-concurrency.md) | Structured, uncoloured concurrency | Accepted |
| [0008](0008-go-interop-and-permanent-go-backend.md) | Go interoperability; Go backend is permanent | Accepted |
| [0009](0009-go-purity-classification.md) | Per-function Go purity list and call-graph analysis | Accepted |
| [0010](0010-english-keywords-ascii-identifiers.md) | English keywords, ASCII identifiers | Accepted |
| [0011](0011-rule-tagged-spec-and-conformance-first.md) | Rule-tagged specification, conformance-first development | Accepted |
| [0012](0012-ai-agent-development-model.md) | Development by a coordinated team of AI agents | Accepted |
| [0013](0013-layout-token-contract-and-block-ended-expressions.md) | Layout token contract and block-ended expressions | Accepted (owner-delegated, review at MVP) |
| [0014](0014-generic-arguments-in-expressions-and-types.md) | Generic arguments in expressions and types | Accepted (owner-delegated, review at MVP) |
| [0015](0015-parser-contract-decisions-at-mvp-start.md) | Parser-contract decisions at the start of the MVP | Accepted (owner-delegated, review at MVP) |
| [0016](0016-lexical-and-semantic-decisions-at-mvp-start.md) | Lexical and semantic decisions at the start of the MVP | Accepted (owner-delegated, review at MVP) |
| [0017](0017-security-review-resolution.md) | Resolution of the security review of ADR-0013 to ADR-0016 | Accepted (owner-delegated, review at MVP) |
| [0018](0018-surface-syntax-familiarity.md) | Surface syntax familiarity | Proposed (owner confirmation required) |
| [0019](0019-toolchain-parity.md) | Toolchain parity with the Go toolchain | Proposed |
| [0020](0020-lexical-edge-cases.md) | Lexical edge cases of numeric, string and prefix literals | Proposed |
