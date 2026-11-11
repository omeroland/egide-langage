---
id: T-1041
title: Conformance runner: package fixtures for manifest-level tests
kind: task
phase: 1
role: test-engineer
depends_on: [T-0014]
spec: [GO-032, PKG-030, PKG-031]
paths: [tools/conformance/, docs/testing.md, tests/README.md]
estimate: M
labels: [security]
status: backlog
claimed_by:
claimed_at:
---

## Goal

The runner can run a test that is a directory: an `egide.toml` and `src/` of the package under test, optionally
`deps/<name>/` packages, with `# diagnostic:` lines in the entry file, so that rules that depend on a manifest or on a
dependency can be tested (E0420, E0421 with a dependency, PKG-030/031 `allow` chains, GO-044).

## Context

T-1038 re-review: the attack "a dependency asserts `@go_threadsafe` and the root has no matching `allow`" cannot be
written as a single `.egd` file. `tests/security/semantics/go_threadsafe_requires_manifest_allow_*` cover the
manifest-less case only. Fixture directories must be byte-exact (`-text`) like the lexical fixtures.

## Acceptance criteria

- [ ] A directory test is discovered, run with `egide check` in that directory and judged like a file test
- [ ] Header rules (`# spec:`, `# expect:`, `# diagnostic:`, `# phase:`) apply to the entry file
- [ ] `docs/testing.md` and `tests/README.md` describe the layout
- [ ] At least one fixture for E0421 with a dependency lacking the `allow` entry (skipped until phase 6)

## Out of scope

Implementing `egide check` for packages; `tests/security/` additions (the security-reviewer adds them).

## Log

## Outcome
