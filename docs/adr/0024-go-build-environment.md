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

### 2. GO-003 (native backend) and cgo (A2; third pass B-1, B-2; the glue design is superseded by section 5, B-2')

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

### 5. Fourth-pass review (all reproduced by the reviewer with Go 1.24.7 on linux/amd64; the list targets 1.25)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| B-1': an ordinary `.go` file with `//go:cgo_import_dynamic _ _ "/path/lib.so"` builds under `CGO_ENABLED=0`; the binary has `NEEDED lib.so` and the library's constructor runs before `main`. `go list` shows no cgo file, nothing in E0706, GO-042.2 or the init rule catches it. The other `//go:cgo_*` pragmas tried (`cgo_ldflag`, `cgo_export_dynamic`, `cgo_import_static`, `cgo_dynamic_linker`) are rejected by the compiler. `//go:wasmimport` on a body-less function builds under `GOOS=wasip1` | established (reproduced) | GO-046.1 scans Go files for `//go:cgo_*` and `//go:wasmimport` (E0706); GO-042.2 adds "a function without a Go body and any `//go:wasmimport`" to the impure list; defence in depth: the produced binary on the Go backend must be static (no dynamic interpreter, no dependency outside a per-OS allow-list), else E0710 |
| B-2': `//export` in a file without `import "C"` exports nothing (no symbol, no header); and in a two-file package a second file can redefine `error`, `nil`, `len`, `true` for the first with no diagnostic, so the hash of the template does not fix its behaviour | established (reproduced) | the template package exports only fixed symbols (one dispatcher); all program-derived Go lives in a separate package reached through a fixed interface, with no `import "C"`, no program-data comments, and identifiers prefixed and checked against keywords, predeclared names, `_C` and `_cgo`. Hash subject: template, interface, mangling rule. (The first split in section 2 is superseded) |
| B-3': for a package with `x.go` (`import "C"`) and `y.go`, `GoFiles` is the same at `CGO_ENABLED=0` and `1`; only `CgoFiles` changes, so an equality test on `GoFiles` passes a cgo file | established (reproduced) | compare every list the Go tool reports; require `CgoFiles` empty under `CGO_ENABLED=1`; the pure-Go-fallback exemption exists on the Go backend only |
| B-4': `go build` runs `git status` and `git log` from `PATH` under the default `-buildvcs=auto`, and git honours the repository's configuration (`core.fsmonitor`, recalled), so building an untrusted clone executes project-controlled code | established (reproduced with a stub `git`); the fsmonitor step emerging | the whole command line comes from a fixed allow-list (`-buildvcs=false`, `-trimpath`, `-mod=readonly`, the tuple); no user or manifest flag reaches it; `PATH` contains no `git`, `hg`, `svn`, `bzr` |
| 1 TOCTOU: read-only permissions do not bind the owning user; `go` execs `compile` and `link` from the tree for seconds after the check | extrapolated | separate user, read-only bind mount or mount namespace where available; always re-hash snapshot and tree after the build and fail on a difference; canonical tree hash defined |
| 2 consistency: `docs/toolchain-parity.md` F01 and T-1129 still listed `egide test --race` as covered | established | both edited in this PR; ADR-0019 line 42 still lists `--race` (that ADR is not edited here: it needs the same note when it is accepted). `c-shared` and `plugin` are added to E0708 |
| 3 C-toolchain identity of two binaries | extrapolated | the hash of the whole tree |
| 4 a fresh empty `GOCACHE` recompiles the standard library on every build | emerging | stated as a cost; a compiler-owned, compiler-verified cache may replace it later |
| 5 provenance of the first toolchain archive hash | n/a | kept on Q-0042/Q-0041 |
| 6 normative text cited ADR numbers | established | the spec text cites rule ids only |

### 6. Fifth-pass review (reproduced by the reviewer with Go 1.24.7 unless marked)

| Finding | Resolution |
|---------|------------|
| B-1' closed with a condition: the compiler honours `//go:cgo_import_dynamic` indented, inside a function body, with CRLF, after a `//line` directive and without `import "unsafe"`; it rejects it only as "misplaced" when code trails on the line or after a block comment | GO-046.1: the scan is token-level (`go/scanner` comments) over every position and over files the tuple ignores; the conformance test (follow-up for `test-engineer`) must use these placements. A column-1 regex or a header-only directive list would miss them |
| G-1 (blocking, reproduced): Go exports only upper-case names, so `prog.egide_dispatch` does not compile | the one exported entry point is `Egide_Dispatch`, the single exception to the prefix; the keyword, predeclared and `_C`/`_cgo` checks are stated to be vacuous after the prefix |
| G-2 (blocking as a spec gap): the mangling rule is the hash subject but undefined and not injective (`pkg a_b` + `fn c` against `pkg a` + `fn b_c` both give `egide_a_b_c`; Go reports a redeclaration, so a dependency could cause a build failure, or the compiler could resolve the wrong item) | GO-046.1 defines an injective, reversible mangling: for each dot-separated segment, its decimal length, `_`, and the segment (`a_b.c` is `egide_3_a_b1_c`, `a.b_c` is `egide_1_a3_b_c`) |
| Module-cache layout: with `GOMODCACHE` at extracted directories only and `GOPROXY=off`, `go build` fails ("missing go.sum entry"); directory `replace` builds without consulting `go.sum` | GO-046.4: the generated main module names every module with a directory `replace` to the snapshot; `GOMODCACHE` is an empty private directory; the compiler's own hash comparison is therefore the sole verification (stated) |
| The extension list drifts from `go/build`: `.sx .hh .hpp .hxx .f .F .for .f90` are missing; `.C` is invisible to `go list` | GO-046.1 derives the set from the file tables of `go/build` of the pinned toolchain, including case variants, instead of enumerating; the diagnostics row no longer enumerates |
| E0710 must run before `egide run`/`egide test` executes the artefact (note from the #33 review) | stated in GO-046.1 |
| Dispatcher as a forgery oracle if the host is itself sandboxed (reasoned) | the dispatcher never decodes capability or resource types from its buffer |
| Cost, not a finding: `.h`, `.S`, body-less functions rule out assembly-accelerated libraries unless they offer a `purego` build | accepted and documented here: the tuple tag `purego` is the way in |

### 7. Sixth-pass review (reasoned, not run)

| Finding | Resolution |
|---------|------------|
| B-1 (blocking): nothing forbids hostile archive entries when the snapshot is built or extracted (`..`, absolute paths, symlink then `//go:embed` of a host file, hard links, devices, FIFOs) | GO-046.4 gains the hostile-archive rule (regular files and directories only, resolved-path check, exclusive creation, collisions) with a new code E0711; PKG-041 applies it to Égide package archives. Alternative: let the archive library sanitise. Rejected, the property must be in the spec so that every implementation and the conformance test share it |
| B-2 (blocking): "plain data" undefined; validated types, sink types, `Ptr`, `GoRef`, `Shared`, `Chan`, functions and trait objects could be forged from bytes | GO-046.1 gives a closed list of decodable types; validated types decode through their constructor; everything else is non-decodable. Cost: a host API cannot pass a handle or callback across the boundary. Accepted, it needs a separate ADR |

### 8. Seventh-pass review

| Finding | Resolution |
|---------|------------|
| B-1: E0711 prints an attacker-controlled entry name; LEX-006 covers source text only (terminal escapes, RTL overrides) | new GO-046.7: one function `diag_escape` (non-printable-ASCII scalars as `\u{HEX}`, truncation to 120 characters) for every derived string of E0701 to E0711, audit, lock, SBOM, `--confirm` |
| B-2: no extraction bounds (zip bombs, sparse tar, entry counts, deep paths; Go caps module zips at 500 MiB) | GO-046.4(b): fixed limits (500 MiB total, 100 MiB per file, 100 000 entries, depth 32, 255 B segment, 4096 B path, ratio 100:1; toolchain 2 GiB and 200 000 entries), declared and actual sizes. The numbers are *extrapolated* defaults for the owner; the toolchain row is unverified |
| collision rule depended on the host | NFC plus full case folding on every host |
| portable names | no backslash, `:`, trailing dot or space, Windows device names (as `x/mod` rejects them) |
| "nothing was written" cannot hold for a stream | private staging directory on the same file system, moved after checks and hash; reworded |
| archive metadata | discarded (fixed modes, no owners, xattrs, setuid) |
| "private invariant" undecidable | decodable structs and enums: no `Drop`; invariants only as validated-type fields |
| Go toolchain tarball must itself pass | stated as an assumption in GO-046.2, to verify in T-0100 (the installed GOROOT was clean, the archive could not be downloaded) |
| #36 E0006 row will be stale by one code after merge | noted, no action: this PR does not touch that row |

## Decision

Apply the spec diff: GO-046, GO-003 (one sentence), PKG-042, PKG-043, diagnostics E0706, E0707, E0708 and E0710 (E07xx; codes are
allocated so that the catalogue stays sorted: ADR-0022 E0701-E0703, ADR-0025 E0704-E0705, this ADR E0706-E0708 and E0710,
ADR-0023 E0709; this is not the stack order).

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
