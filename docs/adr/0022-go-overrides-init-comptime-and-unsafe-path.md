# ADR-0022: Gating of Go overrides, classification of Go `init`, no Go at compile time, and the `unsafe` module path

- Status: Proposed
- Date: 2026-11-11
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. This ADR touches ch. 9, 10 and 11 and needs the
  `security-reviewer` before the owner decides (docs/adr/README.md). The owner's merge is the acceptance.
- Spec chapters affected: 4 (TYP-031), 5 (MEM-070), 9 (CT-001, new CT-006), 10 (PKG-030, PKG-040), 11 (GO-044, new GO-045),
  `docs/diagnostics.md`
- Answers: Q-0050; two flaws found in review of ch. 11 (labelled F1 and F2 below)

## Executive Summary

Two gaps in chapter 11 let a dependency obtain authority without any entry in the root's manifest: `[go.overrides]`
(GO-044) removes the capability requirement of a Go function with no gate, and the `init()` functions and package-level
initialisers of imported Go packages run before `main` outside any classification. A third gap, execution of Go
functions at compile time, is closed before it can be implemented (CT-001 plus CAP-040 currently allow it). Q-0050 is
settled by renaming the pointer module `std.ptr`. Reasoning is mostly *established* from spec text; the Go-specific
behaviour of `init` is *established* Go semantics; the reach of real modules is *extrapolated*.

## Core Analysis

### Q-0050: `unsafe` is reserved, MEM-070 names `std.unsafe.Ptr[T]`

*Established* (Q-0050, reproduced): `path = IDENT { "." IDENT }` cannot derive `std.unsafe` because LEX-021 reserves
`unsafe`. Only MEM-070 uses the name (grep over `spec/`, `docs/`, `examples/`, `stdlib/`; the ADR-0018 annex does not).

| Option | Assessment |
|--------|------------|
| **A (recommended)** rename to `std.ptr.Ptr[T]` | Restriction, not a new rule; `unsafe` stays a reserved word that only the block form can carry, so a grep for `unsafe` finds exactly the audit markers (SYN-017, MEM-071). The question proposed `std.raw`; `ptr` is chosen because `raw` is already the adjective of raw strings (LEX-052). The owner may pick any non-keyword name. |
| B contextual keyword | Adds a lexer/parser context rule and makes the audit word ambiguous. |
| C keywords as path segments after `.` | Weakens LEX-021 for every keyword (`x.match`). |

Note: using `std.ptr.Ptr` outside an `unsafe` block remains an error by MEM-070 (the permission is the block, not the
name).

### F1: `[go.overrides]` is not gated (GO-044)

*Established* by reading GO-011, GO-044 and PKG-030:

1. GO-011: a call to a function classified pure needs no capability. GO-044: a package may reclassify any `"module.Func"`
   as pure with a free-text reason.
2. PKG-030 lists the breaches that need an `allow` entry (`unsafe`, `ffi`, `go:<module>` for impure Go calls,
   `go_threadsafe`). A call reclassified pure is not an impure call, so no `go:` entry is required.
3. "Overrides never apply to dependent packages" does not help: a dependent calls the declaring package's `pub` API,
   whose signature has no `using` clause because the body is pure (CAP-034, CAP-040).

Walk-through: package `evil` declares an override for a function that reads the file system and exposes
`pub fn config() -> str`. A root depending on `evil` lists nothing special, calls `evil.config()` without any capability,
and reads a file: INT-003 is defeated by a manifest edit that no `allow` entry reveals (only `egide audit` prints it).
By CT-001 the same function is also compile-time evaluable (INT-005). `@go_threadsafe` (GO-032) is the same class of
assertion and is gated by `go_threadsafe:<go module>` and E0420/E0421; GO-044 was simply left out.

Rule (GO-044, rewritten): only `class = "pure"`; the key must name a function of a Go module declared in the same
package's `[go]` (not the standard library, whose classification is the human-reviewed list GO-041, and not another
package's module: E0423); `reason` satisfies SYN-018; every package that transitively contains an override lists
`go_override:<import path>.<Func>` (E0422); the override changes only the classification of calls made by the declaring
package; audit and lock record it. Granularity is the function, not the module: GO-032 at module granularity lets a
package allowed `go_threadsafe:k8s.io/client-go` assert any type of the module (item 3 of the duplicate Q-0022), and I do
not copy that defect.

Alternatives: (a) delete overrides (strongest; false positives of the conservative analysis GO-042 would then block
legitimate calls, and the escape would be a fork of the Go module); (b) module-granular entry (rejected above);
(c) keep as is (rejected: *established* laundering path). Chosen: gate. Counter-hypothesis: the gate is still only a
manifest line; a root that blindly adds `go_override:…` accepts the risk, as with `unsafe`.

### F2a: Go `init()` and package-level initialisers

*Established* Go semantics: importing a package runs its package-level variable initialisers and `init` functions
(transitively, in dependency order) before `main`; the code has the full authority of the process. *Established* from
the spec: GO-010..012 gate *calls* of classified functions, GO-042 classifies "functions callable from Égide", GO-043
detects drift only for "a function called by the Égide program". `init` is not callable, so it is in no classification,
no lock entry and no drift check. A dependency update that adds `init() { os.Setenv(...) / dial(...) }` to a Go module
anywhere in the import closure runs at start-up, with no `allow` change. (GO-013, the sandbox, is the only barrier, and
CAP-051 says guarantees do not rely on it.)

Rule (new GO-045): classify the **init set** of every Go package in the closure (the standard library through a
`<import path>.init <class>` line in the purity list, absent = impure, so `strings.*` does not silently cover it;
third-party packages as extra roots of the GO-042 analysis). A non-pure init set counts as impure Go code of its module
and requires `go:<module>` (`go:std` for the standard library) in `allow`; new code E0424 (the catalogue had no code for
a missing `go:<module>` entry at all). Drift (GO-043), lock (PKG-040) and audit include init sets. No capability can
mediate an initialiser, and the rule says so.

Alternatives: forbid Go packages with a non-pure init set (rejected: *extrapolated* that most real modules, for example
`client-go`, register schemes and flags at init and would be unusable; a gate keeps them usable and visible); run init
in a sandbox (not possible in Go's runtime); do nothing and document (rejected: it contradicts "auditable", 11.2).

Costs, *extrapolated*: the purity list (T-0040) needs one `init` line per standard package, produced by the generator and
reviewed; the call-graph tool (T-0083) needs the init set as roots. Both are `go-interop-engineer` work already scoped
as large.

### F2b: Go functions at compile time

*Established*: CT-001 says any pure function can run at compile time; CAP-040 defines "pure" with "does not call impure
Go code", so a Go function classified pure is, by the text, compile-time evaluable. Running Go during compilation
means executing foreign code with the compiler's authority, which INT-005 forbids; a classification is a conservative
static approximation (GO-042 lists cases it cannot see) and a mistake or an override (F1) would turn into build-time code
execution. The phase 1 interpreter is an OCaml bytecode interpreter and cannot call Go, so the rule costs nothing today
and prevents a future shortcut.

Rule (new CT-006, CT-001 and TYP-031 amended): Go code never runs at compile time, whatever its classification; a call
to a Go function in a compile-time context is E0610 ("a call to a Go function"); validated-type predicates may not call
Go. Alternative: allow only std functions on the reviewed list (rejected: the list is reviewed for authority, not for
determinism or termination, and CT-003's budgets cannot bound native code).

### Not decided here (for the `security-reviewer`)

- *Extrapolated, unverified:* building the generated Go program invokes the Go toolchain on third-party source;
  `cgo` packages run the C compiler on it, `go generate` is not run by `go build`. PKG-042 ("building never executes code
  of the package with authority") should be checked against T-0082 (the Go package loader), which must not run
  `go generate`, `go run` or a toolchain download (`GOTOOLCHAIN=local`). I did not verify it.
- Item 4 of the duplicate Q-0022 (does the root package need its own `allow`?) applies to GO-044 and GO-045 as it does
  to GO-032; this ADR follows GO-032's wording ("every package that transitively contains it").

## Decision

Apply the spec diff of this PR: MEM-070 (`std.ptr.Ptr[T]`), GO-044 rewritten, GO-045 added, CT-001 and CT-006, TYP-031,
PKG-030 and PKG-040, diagnostics E0422, E0423, E0424 and the extended E0610.

## Alternatives considered

In the sections above.

## Consequences

- Complexity budget: +2 rules (GO-045, CT-006), +3 diagnostics, +1 manifest allow form; no new language feature. All
  are restrictions of unreviewed paths to authority.
- Security: closes a capability-laundering path (F1) and an unclassified start-up execution path (F2a), and keeps INT-005
  (F2b). Residual: an accepted `go:`/`go_override:` entry still grants what it names; sandbox remains the barrier for init.
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: init sets in T-0040 and T-0083;
  `tooling-engineer`: `go_override:` and init in lock, audit and drift (T-0092); `comptime-engineer`: E0610 on Go calls;
  `test-engineer` and `security-reviewer`: negative PoCs under `tests/security/` (append-only; not touched here).
- Migration: pre-1.0, no released code; no Go interop exists yet.

## Recommendations / Next Steps

1. `security-reviewer` reviews F1, F2a, F2b before the owner decides.
2. Owner choices with defaults: module name (`std.ptr`; any non-keyword works); granularity of `go_override:` (function;
   module is the alternative); `go:std` as the entry for standard-library init sets.
3. After acceptance the orchestrator creates the follow-up tasks above and marks Q-0050 answered (done in this PR).
4. Not verified: I ran no tool against these rules; the purity-list impact on `strings`, `fmt` and similar packages
   is extrapolated.
