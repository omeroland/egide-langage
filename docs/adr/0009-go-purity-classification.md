# ADR-0009: Per-function Go purity list and call-graph analysis

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 11, appendix A

## Context

Package-level classification is too coarse: `fmt` imports `os`, so the pure `fmt.Sprintf` would be blocked, while
`time.Now` (clock) and `time.LoadLocation` (disk) hide inside an innocuous-looking package.

## Decision

1. The Go standard library is classified **per function** by an official list versioned per Go minor version, reviewed
   by humans; absent functions are impure.
2. Third-party modules are classified by conservative call-graph analysis (in the spirit of Google's capslock),
   recorded per function in `egide.lock`; classification drift fails `egide lock`.
3. Project-local overrides with a reason, listed by `egide audit`, never inherited.

## Consequences

Precise, auditable boundary; a Go module update that starts using the network is caught at lock time.
