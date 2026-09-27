# Path ownership

The owning role implements changes in these paths; other roles need a task that explicitly lists the path.
The orchestrator uses this table to avoid scheduling conflicting tasks in the same wave.

| Path | Owner role | Also allowed (via task) |
|------|------------|-------------------------|
| `spec/`, `docs/adr/` | human owner (via ADR) | language-architect drafts ADRs |
| `AGENTS.md`, `CLAUDE.md`, `.claude/`, `agents/`, `tools/hooks/`, `.github/` | human owner | release-manager drafts on `governance/*` |
| `compiler/lib/source/`, `compiler/lib/diagnostics/` | syntax-engineer | any frontend role |
| `compiler/lib/syntax/` (lexer, layout, parser, AST, CST) | syntax-engineer | — |
| `compiler/lib/resolve/`, `compiler/lib/types/`, `compiler/lib/hir/` | type-system-engineer | capability-engineer (`using` resolution) |
| `compiler/lib/check/` | memory-semantics-engineer | capability-engineer (purity, security lints) |
| `compiler/lib/mir/` | memory-semantics-engineer | go-backend-engineer, native-backend-engineer |
| `compiler/lib/comptime/` | comptime-engineer | — |
| `compiler/lib/backend_go/`, `runtime/go/` | go-backend-engineer | go-interop-engineer (`runtime/go/goint`) |
| `compiler/lib/goint/`, `spec/appendix/go-purity/` (data, via PR reviewed by security-reviewer + owner) | go-interop-engineer | — |
| `compiler/lib/backend_c/`, `runtime/c/` | native-backend-engineer | — |
| `compiler/lib/pkg/`, `compiler/lib/fmt/`, `compiler/lib/lsp/`, `compiler/bin/`, `editors/` | tooling-engineer | — |
| `compiler/lib/driver/` | tooling-engineer | any role adding a pass (with task) |
| `stdlib/` | stdlib-engineer | capability-engineer (`std.cap`, security types) |
| `tests/conformance/` | test-engineer | every implementation role adds tests for its task |
| `tests/security/` | security-reviewer | append-only for everyone |
| `tools/` (except hooks) | release-manager | test-engineer (runners) |
| `docs/` (except adr) | docs-writer | every role for its own section |
| `examples/` | docs-writer | stdlib-engineer |
| `tasks/` | everyone, following protocol.md | — |
