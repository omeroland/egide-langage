# Égide Go runtime

Package `rt` is linked into every binary produced by the Go backend (docs/architecture.md §4).

| File | Implements |
|------|------------|
| `rt/scope.go` | structured scopes and tasks (spec/07 CON-001..011) |
| `rt/result.go` | `Result[T]` / `Option[T]` helpers used by generated code |
| `rt/sys.go` | capability roots created once for `main` (spec/06 CAP-001, CAP-010) |

Rules: `go vet` and `go test -race` clean; no global mutable state; every exported identifier documented.
Seed status: scopes are functional; capabilities are stubs (phase 4).
