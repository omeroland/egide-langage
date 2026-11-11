# ADR-0024: Go build environment: no dependency code runs during compilation

- Status: Proposed
- Date: 2026-11-11 (split out of ADR-0022 after its security review)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. Needs the `security-reviewer` (ch. 10, 11).
- Spec chapters affected: 10 (PKG-042, new PKG-043), 11 (GO-003, new GO-046), `docs/diagnostics.md`
- Depends on: Q-0042 (compiler and toolchain pinning, open), Q-0041 (trust roots, open), ADR-0019 (test flags). ADR-0025
  depends on this ADR.

## Executive Summary

The Go toolchain runs code that a dependency controls: the cgo tool and the C compiler (preamble, `#cgo` flags,
constructors), a downloaded toolchain, whatever the environment or the `go env -w` file tells it to run, and a module cache
that Go does not re-verify. GO-046 closes these with six rules (no cgo, pinned local toolchain, allow-listed environment,
hashed private module cache, generated main module, a complete build tuple). Nearly all of the evidence is *emerging*
(recalled upstream behaviour, not re-fetched; no Go toolchain was run), and the ADR says where. It also settles the
contradiction with GO-003 (native backend).

## Core Analysis

### 1. What can run and where (security review B4, A2, A3, A4)

| Vector | Evidence | Rule |
|--------|----------|------|
| cgo preamble, `__attribute__((constructor))`, `#cgo LDFLAGS`, `pkg-config`: type information through `go list -compiled` or `go/packages` runs the cgo tool and the C compiler; `go build` honours the `#cgo` lines. Past cgo build-time advisories (CVE-2023-29404/29405, cited by the reviewer) | emerging | GO-046.1: `CGO_ENABLED=0`; E0705 |
| `.syso` objects are linked even with cgo off | emerging | E0705 |
| `GOTOOLCHAIN=auto`: a go.mod `go`/`toolchain` line downloads and runs a newer toolchain | established for the main module, extrapolated for dependencies | GO-046.2: `GOTOOLCHAIN=local`; version and distribution hash in the lock |
| `GOFLAGS`, `GOENV` file, `GOCACHEPROG` (an external program), `GOPROXY`/`GOVCS` (`direct` runs `git`, `hg`, `svn`), `GOSUMDB`/`GONOSUMDB`/`GOPRIVATE`/`GOINSECURE`, `-toolexec`, `-overlay` | emerging | GO-046.3: explicit allow-listed environment for every `go` process, `GOENV=off`, `GOCACHEPROG` unset, fixed proxy or `off`, `GOVCS=*:off`, `GOSUMDB` on, no `-toolexec`/`-overlay`. The first draft said "environment from the compiler and nothing else"; the reviewer showed that this names a goal, not a mechanism |
| Go verifies `go.sum` at download, not on each use of an extracted module cache; a shared cache can differ from the locked bytes | emerging | GO-046.4: private cache written only by the compiler; the hash of every module directory used is recomputed and compared with the lock before each analysis and build. The first draft claimed "both come from the module cache verified against go.sum", which is not true of a shared cache by default |
| `vendor/` is not checked against `go.sum` (only `vendor/modules.txt` against `go.mod`) | emerging | GO-046.4/5: `egide vendor` trees are re-hashed; the main module is generated. Reviewer C5: `vendor/`, `replace`, `exclude` of *dependencies* are already ignored by Go; the live vectors are the main module's `vendor/` and `-mod`, `go.work` and our own vendor trees, and the justification text now says so |
| Build tags: `evil_linux.go` impure, `evil_other.go` pure, classified on one platform and built on another | established by Go semantics | GO-046.6 |
| Tuple incompleteness (A3): `GOAMD64=v3` selects `//go:build amd64.v3` files; `GOEXPERIMENT`; tags set by `--race`, `-tags`, `purego` | emerging | GO-046.6: the tuple is every constraint-relevant setting, explicit (never "unset"); `--race`, `--cover`, `--fuzz` change it; E0706 for an unrecorded tuple |

Alternative to an explicit tuple: analyse the union of all constraint combinations. Rejected: combinatorial, and it would
classify files no build ever compiles.

### 2. GO-003 (native backend) versus `CGO_ENABLED=0` (A2)

*Emerging* (recalled by the reviewer, not re-fetched): `-buildmode=c-archive` needs cgo, and `CGO_ENABLED` is a property of one
`go build`. The first draft's "the glue is not part of the closure" left the contradiction in place. Options:

| Option | Assessment |
|--------|------------|
| **A (chosen)** carve-out: one compiler-generated glue package may use cgo, verified against a hash in the compiler; the closure must select the **same files** under `CGO_ENABLED=1` as under `CGO_ENABLED=0` (E0705 otherwise), so the analysed file set is the compiled one | Keeps GO-003 and the rule, and closes the trap where enabling cgo for the glue silently enables `//go:build cgo` variants of dependencies. Costs a double file-set computation in phase 7. |
| B change GO-003: Go code runs in a separate process | Removes cgo from the picture entirely; a larger design change in phase 7 that is the native-backend-engineer's decision (T-0100). |
| C scope the rule to the Go backend only | Leaves the native backend unspecified. |

Owner's choice; default A, with B as the likely outcome if T-0100 finds the file-set equality hard to check.

### 3. E0705 scope (C4)

With `CGO_ENABLED=0`, cgo files are excluded from the build, not run. E0705 therefore fires only for a package that needs
cgo to build, for C-family sources the tuple selects, and for `.syso`. A pure-Go fallback library is accepted and its cgo
files are never compiled (*established* by the Go build-constraint rule `cgo`, emerging for the detail of C sources).

## Decision

Apply the spec diff: new GO-046, GO-003 (one sentence), PKG-042 (Go modules), new PKG-043 (lock fields), diagnostics
E0705 and E0706 (E07xx, as the second-pass review C7 asked).

## Alternatives considered

Allow cgo behind a `go_cgo:<module>` entry: rejected for now, because it is only meaningful with a sandboxed C build; the
cost is that cgo-only modules (SQLite bindings, for example, *extrapolated*) are unusable until a later ADR.

## Consequences

- Complexity budget: +1 rule, +1 lock rule, +2 diagnostics, no language feature. Moderate implementation load on T-0082
  (package loader), which must implement GO-046 before it loads any Go package.
- Security: removes build-time execution of dependency code through the Go toolchain (INT-005, PKG-042). Residual: bugs in
  the pinned Go toolchain itself; the hash makes the toolchain a pinned input, not a trusted one.
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: T-0082, T-0083; `tooling-engineer`: lock fields,
  `egide lock --target`, cache hashing; `security-reviewer`: PoCs for cgo constructor, `GOOS` split, `amd64.v3` file,
  `--race` file, `vendor/` mismatch, `GOTOOLCHAIN` line.
- Migration: pre-1.0, no Go interop exists yet.

## Recommendations / Next Steps

1. `security-reviewer` re-reviews; evidence is mostly emerging, so a run against a real Go toolchain (a reproduction per
   vector) should precede acceptance if the owner wants more than a design decision.
2. Owner choices (defaults): GO-003 option A; no cgo entry in this version.
3. ADR-0025 must not be accepted before this ADR. Not verified: no Go tool was run.
