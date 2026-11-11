# ADR-0024: Go build environment: no dependency code runs during compilation

- Status: Proposed
- Date: 2026-11-11 (split out of ADR-0022; revised after the second and third security reviews)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. Needs the `security-reviewer` (ch. 10, 11).
- Spec chapters affected: 10 (PKG-042, new PKG-043), 11 (GO-003, new GO-046), `docs/diagnostics.md`
- Depends on: Q-0042 (compiler and toolchain pinning, open), Q-0041 (trust roots, open), ADR-0019 (test flags),
  ADR-0022 (lock key). ADR-0025 depends on this ADR. Merge order: ADR-0022, ADR-0023, this ADR, ADR-0025.

## Executive Summary

The Go toolchain runs code that a dependency controls: the cgo tool and the C compiler, a downloaded toolchain, whatever
the environment or the `go env -w` file tells it to run, and a module cache that Go does not re-verify. GO-046 closes these
with six rules: no cgo on the Go backend, a hashed local toolchain, an allow-listed environment with a fresh build cache, an
immutable verified snapshot of the modules, a generated main module and a complete build tuple. The native backend (GO-003)
gets a precisely scoped cgo carve-out for one template-based glue package. Evidence: mostly *emerging* (recalled upstream
behaviour); the third-pass review reproduced several points with Go 1.24.7 (the list targets 1.25), marked *established
(reproduced by the reviewer)*. No Go tool was run by the author.

## Core Analysis

### 1. Vectors and rules

| Vector | Evidence | Rule |
|--------|----------|------|
| cgo preamble, constructors, `#cgo` flags, `pkg-config`: type information through `go list -compiled` and `go build` run the cgo tool and the C compiler (cgo advisories such as CVE-2023-29404/29405 cited by the reviewer) | emerging | GO-046.1: `CGO_ENABLED=0` |
| stray C-family sources: *established (reproduced)*: a package with `c.go` and `x.c` lists no C file under `CGO_ENABLED=0` and builds, the file dropped silently; under `=1` the build fails ("C source files not allowed when not using cgo") | established (reproduced) | GO-046.1: the compiler scans the directory for the file kinds and compares with the compiled set; any such file is E0706 |
| `.syso` objects are linked even with cgo off | emerging | E0706 |
| `GOTOOLCHAIN=auto` downloads and runs a toolchain named in go.mod | established for the main module, extrapolated for dependencies | GO-046.2: `GOTOOLCHAIN=local` |
| the toolchain hash was of the distribution archive, but the installed `GOROOT` tree is what runs | extrapolated (third pass, B-4) | GO-046.2: the lock holds archive and tree hashes; the tree is re-hashed before every `go` start |
| `GOFLAGS`, `GOENV` file, `GOCACHEPROG`, `GOPROXY`/`GOVCS` (`direct` runs `git`), `GOSUMDB`, `GOAUTH` (default `netrc`, can name a command; *established (reproduced)* that it exists), `GODEBUG`, `GOTMPDIR`, `GOPATH`, `GOBIN`, `GOFIPS140`, `-toolexec`, `-overlay` | emerging | GO-046.3: explicit allow-listed environment, "every variable not listed is removed" (third pass: say that rather than enumerate dangers) |
| `GOCACHE` entries are trusted by Go; a shared cache can make the compiled bytes differ from the analysed ones | emerging | GO-046.3: a fresh empty `GOCACHE` per build (also good for reproducibility, PKG-050) |
| Go verifies `go.sum` at download, not on each use of an extracted cache; a hash checked before a build is stale when `go` reads the files (TOCTOU by a same-uid process, for example a Go program run by `egide run`, whose confinement is GO-013 only) | emerging; the TOCTOU extrapolated | GO-046.4: an immutable snapshot, copied and hashed by the compiler, read-only, used by both analysis and build |
| `vendor/` is not checked against `go.sum` | emerging | GO-046.4 and .5; dependencies' `vendor/`, `replace`, `exclude` are already ignored by Go, the live vectors are the main module's `vendor/`, `-mod`, `go.work` and `egide vendor` trees |
| build tags and the architecture level: `evil_linux.go`, `//go:build amd64.v3`, `GOEXPERIMENT`, `purego`, `-tags` | established by Go semantics | GO-046.6: explicit tuple, E0707 for an unrecorded tuple |
| `-race`, `-msan`, `-asan` require cgo: *established (reproduced)*: `CGO_ENABLED=0 go build -race` fails | established (reproduced) | GO-046.6: unavailable on the Go backend, E0708 |

Alternative to an explicit tuple: analyse the union of constraint combinations. Rejected: combinatorial, and it classifies
files no build compiles.

### 2. GO-003 (native backend) and cgo (A2; third pass B-1, B-2)

*Emerging* (recalled): `-buildmode=c-archive` needs cgo, and `CGO_ENABLED` is a property of one `go build`.

| Third-pass finding | Resolution |
|--------------------|------------|
| B-1: a hash of the glue package "embedded in the compiler" has no subject, because the glue exports the program's `pub` API and differs per program | the glue is split: one **fixed template file** (the only `import "C"`, plus the preamble) whose bytes and hash are embedded in the compiler, and per-program files in the same package without `import "C"`. Every program-derived string in any glue file is an ASCII identifier of the Égide grammar (ADR-0010), never a doc comment, tag or string literal (extrapolated: this is the injection surface) |
| B-1: with cgo on, the C compiler and linker run, and `CC`, `CGO_CFLAGS`, `CGO_LDFLAGS`, `PKG_CONFIG` and `PATH` are inherited | pinned by the compiler (absolute compiler path, fixed flags, `pkg-config` disabled, `PATH` of pinned directories); the C toolchain identity (version, SHA-256 of compiler and linker) is in the lock; stated as part of the trusted computing base |
| B-2: "same files under `CGO_ENABLED=1` and `0`" fails for the standard library: *established (reproduced)* `net` has 0 cgo files at 0 and 5 at 1, `os/user` 0 and 2 | defined on the **user-package closure** only; the standard library is the pinned toolchain's, classified per tuple by the reviewed list (`CGO_ENABLED` is a tuple member) |
| B-2: it also ignored C sources | the directory scan of GO-046.1 (E0706) |

Options for the native backend: **A (chosen)** the carve-out above; B Go runs in a separate process (removes cgo from the
picture; a phase 7 design decision, T-0100); C scope the rule to the Go backend (leaves the native backend unspecified).
Default A; B is the likely outcome if T-0100 finds the glue constraints heavy.

### 3. Build modes and the tuple (third pass B-3)

`--race`, `--msan` and `--asan` need cgo (reproduced), contradicting both `CGO_ENABLED=0` and ADR-0019's planned `egide test
--race`. Options: forbid them on the Go backend (**chosen**, E0708) or route them through the native-backend glue mechanism.
ADR-0019 needs a note that `egide test --race` is unavailable on the Go backend until a cgo story exists (the Go runtime's own
`go test -race` in the repository's Makefile is a development check of `runtime/go`, not a user program, and is unaffected).
`--cover` and `--fuzz` remain tuple members.

### 4. Lock key

The lock keys the classification by **(build tuple, declaring package, function)**: the tuple here, the declaring package from
ADR-0022 (PKG-040), stated once in PKG-043. Cross-compiling needs `egide lock --target` per target (documentation item for
`egide build --target`).

## Decision

Apply the spec diff: GO-046, GO-003 (one sentence), PKG-042, PKG-043, diagnostics E0706, E0707 and E0708 (E07xx; codes are
allocated in merge order: ADR-0022 E0701-E0703, ADR-0025 E0704-E0705, this ADR E0706-E0708, ADR-0023 E0709).

## Alternatives considered

Allow cgo behind a `go_cgo:<module>` entry: rejected for now (only meaningful with a sandboxed C build; cgo-only modules such
as SQLite bindings are unusable meanwhile, *extrapolated*). E0706 also rejects pure-Go libraries that ship C files for an
optional cgo variant: a deliberate cost; the owner may relax it to "files the tuple compiles".

## Consequences

- Complexity budget: +1 rule, +1 lock rule, +3 diagnostics, no language feature. Heavy implementation load on T-0082
  (package loader), which must implement GO-046 before it loads any Go package.
- Security: removes build-time execution of dependency code through the Go toolchain (INT-005, PKG-042). Residual: bugs
  in the pinned Go toolchain (pinned, not trusted) and the C toolchain on the native backend (trusted computing base).
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: T-0082, T-0083; `tooling-engineer`: lock fields,
  `egide lock --target`, snapshotting and tree hashing; `security-reviewer`: PoCs (cgo constructor, `GOOS` split, `amd64.v3`
  file, `x.c` stray source, `-race`, `vendor/` mismatch, `GOTOOLCHAIN` line) plus one reproduction per vector before acceptance.
- Migration: pre-1.0, no Go interop exists yet.

## Recommendations / Next Steps

1. `security-reviewer` re-reviews. 2. Owner choices (defaults): GO-003 option A; no cgo entry; E0706 strict. 3. ADR-0025 must not
be accepted before this ADR. 4. Not verified by the author: no Go tool was run; `GOTOOLCHAIN`, `GOCACHEPROG`, `GOVCS` behaviour is
recalled.
