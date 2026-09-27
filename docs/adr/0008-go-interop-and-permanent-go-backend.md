# ADR-0008: Go interoperability; the Go backend is permanent

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 11, 13

## Decision

`import go "path" as alias` imports Go packages directly on the Go backend; `egide build --go-package` exports Égide
APIs to Go. The Go backend stays a first-class target alongside the native backend. Impure Go calls require the `Go`
capability.

## Consequences

- Day-one access to client-go, controller-runtime, Prometheus, Vault, gRPC.
- Go code has ambient authority: mitigated by the `Go` capability, per-function purity classification (ADR-0009),
  `egide audit` and the OS sandbox. This is a documented breach, not a hidden one.
- Values crossing the boundary are copied; Go can never mutate Égide values.
