# Tests

| Directory | Content | Owner |
|-----------|---------|-------|
| `conformance/<chapter>/` | black-box language tests, one `.egd` per case, rule-tagged | test-engineer + implementers |
| `security/` | attacks that MUST be rejected or neutralised — **append-only** | security-reviewer |
| `quarantine/` | flaky tests awaiting a fix (blocks phase exit) | test-engineer |

Format and rules: [`docs/testing.md`](../docs/testing.md). Run with `make conformance` or
`./tools/run-conformance.sh <dir>`.
