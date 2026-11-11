# ADR-0022: Gating of Go overrides, classification of Go `init`, no Go at compile time, the Go build environment, and the `unsafe` module path

- Status: Proposed
- Date: 2026-11-11 (revised the same day after the security review of PR #32)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. This ADR touches ch. 4, 5, 9, 10, 11, 13 and the
  purity-list appendix. The `security-reviewer` has reviewed the first draft (REQUEST_CHANGES, 4 blockers, 7
  non-blocking); this revision answers each point (section "Review resolution"). The owner's merge is the acceptance.
- Spec chapters affected: 4 (TYP-031), 5 (MEM-070), 9 (CT-001, new CT-006), 10 (PKG-030, 031, 040, 042, new PKG-032),
  11 (GO-001, 042, 044, new GO-045, GO-046), 13 (TOOL-010), appendix A (new GOP-005, GOP-006), `docs/diagnostics.md`
- Answers: Q-0050; flaws F1, F2a, F2b found in review of ch. 11; blockers B1-B4 of the security review

## Executive Summary

Four ways for a dependency to obtain authority without a matching entry in the root's manifest are closed:
`[go.overrides]` (GO-044) removed capability requirements with no gate and, as first drafted, for every Go caller;
the `init()` functions and package initialisers of imported Go packages run before `main` outside any classification
(and `forbidden` packages such as `net/http/pprof` were reachable by a blank import); Go functions could run at compile
time; and the Go toolchain itself runs dependency-controlled code during analysis and build (cgo, toolchain download,
vendoring, build tags). Q-0050 is settled by renaming the pointer module `std.ptr`. Labels: *established* = spec text or
documented Go semantics; *emerging* = recalled upstream behaviour not re-fetched in this session; *extrapolated* =
inference.

## Core Analysis

### Q-0050: `unsafe` is reserved, MEM-070 names `std.unsafe.Ptr[T]`

*Established* (Q-0050, reproduced): `path = IDENT { "." IDENT }` cannot derive `std.unsafe` because LEX-021 reserves
`unsafe`. Only MEM-070 uses the name (grep over `spec/`, `docs/`, `examples/`, `stdlib/`, `docs/adr/attachments/`).

| Option | Assessment |
|--------|------------|
| **A (recommended)** rename to `std.ptr.Ptr[T]` | A restriction, not a new rule; `unsafe` stays a reserved word that only the block form can carry, so a grep for `unsafe` finds exactly the audit markers (SYN-017, MEM-071). `ptr` rather than the question's `std.raw`, because "raw" is already the adjective of raw strings (LEX-052). Any non-keyword name works. |
| B contextual keyword | A lexer/parser context rule, and the audit word becomes ambiguous. |
| C keywords as path segments after `.` | Weakens LEX-021 for every keyword (`x.match`). |

MEM-070 is edited minimally (one token), so that the textual conflict with ADR-0018's brace rewrite of the same line,
if any, is limited to that token. Using `std.ptr.Ptr` outside an `unsafe` block remains an error by MEM-070 (the
permission is the block, not the name).

### F1: `[go.overrides]` is not gated (GO-044)

*Established* by reading GO-011, GO-044 and PKG-030: a call of a function classified pure needs no capability (GO-011);
a package may reclassify any function as pure with free-text justification (GO-044); PKG-030 lists breaches that need an
`allow` entry, and a call reclassified pure is not an impure call. "Overrides never apply to dependent packages" does
not help, because a dependent calls the declaring package's `pub` API, whose signature has no `using` clause when the
body is pure (CAP-034, CAP-040). So a package can read the file system on behalf of a root that lists nothing, and by
CT-001 the function was even compile-time evaluable (INT-005). `@go_threadsafe` (GO-032) is the same class of
assertion and is gated; GO-044 was left out.

**First draft, and what the review found (B2, established).** The first draft required `go_override:<import path>.<Func>`
and said the override applies "including the call-graph analysis computed for them", justifying that "the entry names the
function, not the module, so the root reviews exactly what it permits". That sentence was false: an evil module with
exported `Sync`, `Backup`, `Export`, all calling an unexported `m.write` that calls `os.WriteFile`, overrides `m.write`
as pure; every caller of `m.write` becomes pure in the analysis, and the root sees one helper in its manifest.

**Rule now (GO-044).** The override applies **only to the edge from Égide source of the declaring package to that exact
function**; inside the Go call graph the function keeps its computed class, so an override is never a pure leaf and Go
callers do not inherit it. This is the narrower of the reviewer's two fixes; the alternative (list and hash every function
whose class changed) was rejected because it makes the allow entry unreadable. The key must be an exported function or
method (`"<import path>.<Type>.<Method>"`), owned by a module that is exactly a `[go]` module of the same package,
resolved by the Go tool and not by string prefix (nested modules, N3); `init` and initialisers cannot be overridden;
`reason` is validated by the manifest reader (N7); the allow entry is `go_override:<import path>.<Func>` on the
dependency edge (E0422); the lock keys the override by the declaring package (N4). The true statement that justifies
function granularity is the narrower one: the root names the function whose class it accepts to be wrong, and by the
edge rule nothing else changes class because of it. Residual risk, *established* and accepted: the named function itself
may do anything, exactly as with `unsafe`.

Alternatives: delete overrides (strongest; legitimate false positives of the conservative GO-042 would then need a fork of
the Go module); module-granular entry (lets one entry cover every function of the module); keep as is (rejected).

### F2a: Go `init()` and package-level initialisers (GO-045)

*Established* Go semantics: importing a package runs its package-level variable initialisers and `init` functions,
transitively, before `main`, with the process's full authority. *Established* from the spec: GO-010..012 gate *calls*,
GO-042 classifies "functions callable from Égide", GO-043 covers "a function called by the Égide program". `init` is in
no classification, no lock entry and no drift check; a dependency update that adds `init() { … }` anywhere in the import
closure runs at start-up with no `allow` change. GO-013 (sandbox) is the only barrier, and CAP-051 says guarantees do not
rely on it.

**Review findings (B1, established from the appendix text).** A.3 lists `net/http/pprof`, `expvar`, `plugin`,
`runtime/cgo`, `syscall`, `unsafe` as `forbidden` ("never callable"). `pprof` and `expvar` are dangerous through their
initialisation (they register handlers on `http.DefaultServeMux`). The first draft made any init remedy a single
`go:std` entry, so a third-party module doing `import _ "net/http/pprof"` needed no Égide call to a forbidden package and
one entry (present in nearly every manifest) sufficed. Also (N1) `go:<module>` was the key already used for impure calls,
so approving a module's calls approved initialisers it gains later.

**Rule now (GO-045, appendix A.4/A.5).**

1. Standard library: the purity list holds `<import path>.init <class>` per package (GOP-005). A `forbidden` package has
   init class `forbidden` unless a line says otherwise. **Only `pure` is accepted**; anything else is E0425 and no entry
   lifts it. There is no `go:std` or `go_init:std` entry at all: the std init classes are a reviewed per-Go-version
   baseline (N1), not a per-root decision. Which standard packages are not `pure` is unknown until T-0040 generates the
   list (*extrapolated*: `os`, `net/http` and `crypto/*` need a decision; `os` is runtime-bound).
2. Third-party modules: the init set is an extra root of GO-042; an impure init set needs `go_init:<module>` (E0424), a
   separate key from `go:<module>` (N1); a `forbidden` init set (any package outside the standard library importing
   `net/http/pprof` or `expvar`, named or blank) is E0425 with no entry.
3. Runtime-bound packages are exempt, and the exemption is an enumerated file (GOP-006, N5): the standard packages
   imported by `runtime/go/rt` (today `context`, `errors`, `fmt`, `io`, `os`, `sync`, `time`, read from the source tree)
   and their transitive standard imports, generated and reviewed, versioned with the list.
4. Callbacks (N2): GO-042 gains item 4: a function value passed as an argument, stored in a package-level variable or a
   field, or started with `go`/`defer`, counts as called by the function that does it. A callback registered in `init`
   (`image.RegisterFormat`, `sql.Register`, `http.HandleFunc`, `signal.Notify`) is therefore classified through the
   registering function. This is conservative and will over-classify (*extrapolated*).
5. Drift (GO-043), lock (PKG-040) and audit cover init sets; no capability can mediate an initialiser, and the rule says so.

Alternatives: forbid every Go package with a non-pure init set (rejected, *extrapolated*: `client-go` registers schemes
and flags at init); run init in a sandbox (not possible in Go's runtime); do nothing (contradicts "auditable", 11.2).

### F2b: Go functions at compile time (CT-006)

*Established*: CT-001 plus CAP-040 let a Go function classified pure run at compile time. That would execute foreign code
with the compiler's authority (INT-005), on the strength of a static approximation (GO-042 lists what it cannot see).

**First draft, and what the review found (B3, established from text).** CT-006 said "a call to a Go function in a
compile-time context" with an enumerated context list, so these bypassed it: `comptime let xs = map(["a"],
strings.ToUpper)` (no syntactic call; CAP-040 exempts lambda arguments), `f"{ver}"` for a Go-typed `ver` (implicit
`String()`), a TYP-031 predicate through an Égide helper, `@template` bodies, `comptime fn`, derivations, array lengths and
const-generic arguments, and the TOOL-010 conflict below.

**Rule now.** CT-006 is defined on the engine: the compile-time evaluator has no foreign-function interface; reaching a
Go call, a Go function used as a value, an operation on a Go-typed value that resolves to Go code (method, Display,
equality, hashing, drop), or any of these through Égide functions, trait objects or function values, is **E0611** at the
outermost compile-time site (its own code, N6, since E0610's message is misleading for a Go function classified pure).
The checker reports what it sees statically; the engine reports the rest, so a missed case fails instead of executing.
Go types as compile-time type values stay legal. CT-001 is reworded; TYP-031 says predicates are evaluated at compile time
for literals and so cannot reach Go.

**TOOL-010 / CT-005 / INT-020 conflict (B3.5).** TOOL-010 says the REPL, `egide run` and `egide test` share the
comptime interpreter, with semantics identical to compiled code. *Established*: INT-020 excludes programs that use Go
interop, so the "identical semantics" claim never covered them. Options:

| Option | Assessment |
|--------|------------|
| **A (chosen)** the interpreter has no Go interface in any mode; `egide run` and `egide test` of a program whose package closure uses `import go` build with the Go backend (GO-046) and execute the binary; the REPL rejects `import go` (E0612) | One engine, no mode flag that is "one bug from INT-005"; TOOL-010 stays true for everything INT-020 covers. Cost: a Go-using program is compiled before `egide run`, and the REPL cannot import Go. |
| B one interpreter with an FFI enabled outside compile-time mode | The reviewer's concern: CT-006 would then depend on a context flag. Rejected. |
| C a second interpreter instance with FFI for run/REPL | Two engines to keep identical; rejected as complexity without a user need. |

Owner's call: if the REPL must import Go packages, C is the fallback.

### B4: the Go toolchain runs code of dependencies (GO-046, new)

*Emerging* (recalled upstream behaviour: type information via `go list -compiled` / `go/packages` runs the cgo tool and
the C compiler on a package's preamble; `go build` honours `#cgo pkg-config:` and `#cgo LDFLAGS`; past cgo build-time
advisories such as CVE-2023-29404/29405 are cited by the reviewer, not re-fetched; `GOTOOLCHAIN=auto` downloads and runs a
newer toolchain named in a go.mod `go`/`toolchain` line, *established* for the main module and *extrapolated* for
dependencies; Go does not verify `vendor/` contents against `go.sum`, only `vendor/modules.txt` against `go.mod`).
Consequently the first draft's sentence "analysing a Go package for type information is not execution of its code" was
**wrong for cgo** and is removed. The ADR previously left PKG-042 unchecked; PKG-042 only spoke of code of "that package".

Attacks by a dependency of the root, none needing an `allow` entry before this change: a cgo preamble with
`__attribute__((constructor))` (also invisible to GO-045's init set); a go.mod requiring a newer toolchain; a `vendor/`
tree or `replace` that makes the analysed bytes differ from the compiled ones (classification of one tree, build of
another); build tags (`evil_linux.go` impure, `evil_other.go` pure: pure on a developer's macOS, impure in Linux CI).

**Rule (GO-046, PKG-042, PKG-040, PKG-032).** `CGO_ENABLED=0` for analysis and build, and any package of the closure with
cgo, C/C++/ObjC/SWIG sources or `.syso` objects is E0426 (no allow entry in this version; a `go_cgo:<module>` entry could
be added by a later ADR, *extrapolated* cost: modules such as SQLite bindings are unusable until then); local pinned
toolchain (`GOTOOLCHAIN=local`), recorded in the lock; environment and flags from the compiler only (`-mod=readonly`,
`GOWORK=off`, no `-toolexec`); the main module of the Go build is generated, and `vendor/`, `replace`, `exclude`,
`go.work`, `toolchain` directives of dependencies are ignored; analysed bytes are the compiled bytes, both verified
against the lock's `go.sum` lines; the lock records the build tuple (`GOOS`, `GOARCH`, tags, `CGO_ENABLED`) with each
classification, and a build for an unrecorded tuple is E0427 until `egide lock --target` has analysed it and drift (GO-043)
passed. Assembly stays allowed and impure (GO-042.2). Alternative: allow cgo behind an allow entry (the reviewer's other
option) rejected for now as it needs a sandboxed C build to be meaningful. Not verified: I ran no Go toolchain; these rules
are the reviewer's proposal accepted as drafted, adjusted to the spec's vocabulary. T-0082 (package loader) must implement
them before any Go package is loaded.

### Review resolution (PR #32)

| Point | Resolution |
|-------|------------|
| B1 forbidden init defeated | Fixed: init class `forbidden` is E0425 with no entry; no `go:std`; third-party blank imports of `pprof`/`expvar` are E0425 |
| B2 override launders callers | Fixed: edge-only rule; false sentence corrected above |
| B3 CT-006 bypassable; TOOL-010 | Fixed: engine-level rule, E0611, option A for TOOL-010 (E0612) |
| B4 toolchain execution | Fixed: GO-046; the CT-006 sentence removed; also covers cgo constructors (cgo excluded) |
| N1 `go:std` overloaded | Fixed: `go_init:<module>` for third parties; std init is a reviewed baseline, no entry |
| N2 callbacks in init | Fixed: GO-042 item 4 |
| N3 key grammar | Fixed: methods keyed `<import path>.<Type>.<Method>`; module by the Go tool; `init` not overridable; `[go]` keys need a dot in the first element (also fixes the GO-001 cross-reference to PKG-040) |
| N4 root `allow` slot, lock key | Fixed: PKG-031 reads `allow` only from the edge-declaring manifest; new PKG-032 gives the root `[package].allow`; lock keyed by declaring package (PKG-040). This resolves item 4 of the duplicate Q-0022 (now Q-0053) for GO-044/045 |
| N5 runtime exclusions | Fixed: GOP-006 and a generated file |
| N6 ranges, E0610 | E0611 is a new code; the range table is amended to say that E04xx also holds the authority gates of ch. 10 and 11, as E0420/E0421 already did (justify rather than move, because moving would renumber two allocated codes) |
| N7 manifest strings | Fixed: GO-044.3 says TOML strings are not lexed by Égide and the manifest reader applies SYN-018 and LEX-006 |
| MEM-070 vs ADR-0018 | MEM-070 edit reduced to one token; rationale moved here |

## Decision

Apply the spec diff of this PR. New rule ids: CT-006, GO-045, GO-046, PKG-032, GOP-005, GOP-006. New diagnostics: E0422
to E0427, E0611, E0612.

## Alternatives considered

In the sections above.

## Consequences

- Complexity budget: +6 rules, +8 diagnostics, 2 new manifest `allow` forms (`go_override:`, `go_init:`), one new lock
  field family (init sets, tuple). No new language feature; every rule restricts an unreviewed path to authority. This is a
  large addition for one ADR; the owner may prefer to split GO-046 into its own ADR.
- Security: closes the laundering path (F1, B2), the unclassified start-up path (F2a, B1), compile-time execution (F2b,
  B3) and build-time execution through the Go toolchain (B4). Residual: an accepted `go:`, `go_init:` or `go_override:`
  entry grants what it names; the sandbox (GO-013) is the only barrier for initialisers; the std init baseline depends on
  the review of T-0040.
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: init sets and the callback rule in T-0040,
  T-0082, T-0083, GO-046 in the loader; `tooling-engineer`: new allow entries, lock fields, `egide lock --target`,
  `egide run` through the Go backend for Go programs (T-0092, T-0036); `comptime-engineer`: E0611 and the REPL E0612;
  `test-engineer` and `security-reviewer`: negative PoCs in `tests/security/` (append-only, not touched here).
- Migration: pre-1.0, no released code; no Go interop exists yet.

## Recommendations / Next Steps

1. `security-reviewer`: re-review B1-B4 against this revision.
2. Owner choices with defaults: `std.ptr` (any non-keyword name); TOOL-010 option A (C if the REPL must import Go);
   cgo excluded without an allow entry (a `go_cgo:` entry is the alternative); split GO-046 into a separate ADR if
   the PR is judged too large.
3. After acceptance the orchestrator creates the follow-up tasks above; Q-0050 is marked answered in this PR.
4. Not verified: no tool was run against these rules; the effect on `strings`, `fmt`, `os`, `net/http` init classes is
   extrapolated until T-0040.
