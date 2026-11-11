# ADR-0019: Toolchain parity with the Go toolchain

- Status: Proposed
- Date: 2026-11-10
- Deciders: owner
- Spec chapters affected: 10, 13 (and the phase-6 and phase-2 lines of `docs/roadmap.md`)
- Raised by: tooling-engineer, task T-1120 (analysis in `docs/toolchain-parity.md`)

## Executive Summary

The owner asked for "the set of tools of the Go language". This ADR proposes to read it as functional parity of the
`egide` toolchain with the standard Go toolchain, expressed in Égide's own verbs, and to forbid the Go features that
execute host code or weaken verification. It lists the amendments to chapters 10 and 13 and to the roadmap that the
parity plan needs.

## Context

Chapter 13 lists 12 commands. The inventory of the Go 1.24.7 toolchain (55 tools, 25 test/build modes, 33 vet analyzers,
`docs/toolchain-parity.md`) shows 9 tools covered, 13 partial, 18 absent and 15 excluded by design. Three things are
not Go gaps but spec gaps: no rule says that a complete lockfile and cache means no network access in `egide build`
(it is only in the tooling-engineer role file); `egide test`, `egide audit`, `egide expand`, `egide explain` and the
VS Code extension have no task; chapter 13 has no command to create a package, add a dependency or publish one,
although PKG-010, PKG-020 and PKG-060 presuppose them.

## Decision

1. **Interpretation.** Parity of function, not of spelling and not of trust assumptions.
2. **New rows for the table of chapter 13** (flat verbs, like `lock` and `vendor`):

   | Command | Purpose |
   |---------|---------|
   | `egide new` / `init` | create a package (manifest, `src/`) |
   | `egide add`, `remove`, `update` | edit requirements, resolve, lock, verify |
   | `egide fetch`, `egide verify [--artifact F]` | fill the cache from the lock; re-check hashes and signatures; rebuild and compare an artefact |
   | `egide why`, `graph`, `list [--json]` | explain, print and enumerate packages, with capabilities and `allow` breaches |
   | `egide install PKG@VER` | build and install a published binary, verified |
   | `egide doc [--html]` | documentation from `##` comments, escaped |
   | `egide fix` | apply suggested fixes, edition migrations, deprecation rewrites |
   | `egide cover`, `egide bench` | coverage reports, benchmarks |
   | `egide env`, `version [-m]`, `clean`, `bug` | environment (read-only), version and embedded SBOM data, caches, bug-report text |
   | `egide publish`, `yank` | registry operations (needs a registry design ADR) |
   | `egide test` flags | `--filter --skip --list --shuffle --count --timeout --failfast --json --cover --race --fuzz` |
   | `egide fmt` flags | `--check` (exists), `--diff`, stdin with `-` |
   | `egide build` flags | `-o`, `--emit`, `--verbose`, `--dry-run` |

3. **New toolchain rules** (ids assigned when written into the spec):
   - network access: only `fetch`, `add`, `update`, `install`, `publish`, `yank` and the explicit refresh of the
     vulnerability snapshot access the network; `build`, `check`, `test`, `run`, `lock` on a complete lockfile and cache never do;
   - the toolchain collects and sends no telemetry;
   - the toolchain never executes code supplied by a package, a manifest or an option at build or check time
     (no `-toolexec`, analyzer plug-ins, module-defined tools, build plug-ins, generators);
   - no option, environment variable or configuration file disables hash or signature verification (extends PKG-041 to
     every command, including `fetch`, `install` and the vulnerability snapshot);
   - every command that prints text from source or manifest uses the single escaping function (LEX-006).
4. **Roadmap.** `egide test` (TOOL-030) moves to phase 2 for the core and phase 4 for fake capabilities; `egide audit`,
   the package commands, coverage, `doc`, `fix`, LSP extensions and the VS Code extension are phase 6; `--trace`,
   sanitizers and PGO are phase 7.
5. **Spec-questions that gate parts of this ADR:** Q-0040 (conditional compilation), Q-0041 (private registries and
   Sigstore trust roots), Q-0042 (compiler pinning and auto-download), Q-0043 (workspaces), Q-0044 (`@bench`, `@fuzz`),
   Q-0045 (C FFI mechanism).

## Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| Literal clone of `go` (`egide mod tidy`, `egide tool ...`, `egide generate`) | zero learning for Go developers | imports `generate`, `-toolexec`, module tools, `GONOSUMDB`-style bypasses; nested verbs contradict chapter 13 | breaks INT-005 and PKG-041 |
| Minimal: keep the 12 commands, rely on Go's own tools | no work | no package creation, no dependency editing, no coverage, no bench; Go tools do not work on the native backend | does not meet the owner's request and leaves spec gaps |
| Delegate everything to the Go toolchain for the Go backend | cheap for phase 6 | two toolchains to document; no answer for phase 7 | kept only for low-level tools (nm, objdump, pprof viewer) |
| Parity of function (this ADR) | familiar workflows, stricter security | 36 tasks, one role overloaded | chosen, staged in four waves |

## Consequences

- Complexity budget: adds about 20 commands to chapter 13 but no language feature; removes none. Counter-risk: a toolchain
  surface larger than the team can test; mitigated by T-1155 (CLI conformance) and T-1156 (parity check).
- Security: reduces ambient authority compared with Go (no generators, no tool execution, no verification bypass);
  adds new network-using commands (`fetch`, `install`, `update`, snapshot refresh) that must verify before use. The
  `security-reviewer` should review T-1132, T-1136, T-1140 and T-1151.
- Implementation: tasks T-1121..T-1156; `compiler/bin/`, `compiler/lib/pkg/`, `compiler/lib/driver/`, `compiler/lib/lsp/`, `editors/`.
- Migration: none (no syntax change); `@bench` and `@fuzz`, if adopted, extend the closed attribute set of SYN-023 and need an edition note.
