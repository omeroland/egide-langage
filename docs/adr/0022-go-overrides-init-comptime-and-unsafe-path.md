# ADR-0022: Gate for Go overrides, own-breach declarations, and the `unsafe` module path

- Status: Proposed
- Date: 2026-11-11 (revised twice after the security review of PR #32)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. The owner's merge is the acceptance.
- Scope after the split: this ADR keeps Q-0050 (`std.ptr`), GO-044 (override gate) and PKG-030/031/032. The other
  mechanisms of the first draft moved to separate ADRs on the security reviewer's recommendation: ADR-0023 (no Go at
  compile time), ADR-0024 (Go build environment), ADR-0025 (Go package initialisation, depends on ADR-0024). The file
  name still says "init-comptime" for history only.
- Spec chapters affected: 5 (MEM-070, MEM-071), 10 (PKG-030, 031, 032, 040), 11 (GO-001, GO-044), 13 (TOOL-011),
  `docs/diagnostics.md`
- Answers: Q-0050; flaw F1 (ungated overrides); blockers B2 and A1, A5 of the security review

## Executive Summary

`[go.overrides]` removes the capability requirement of a Go function with no gate, so a dependency can read the file
system on behalf of a root that lists nothing. It is gated like `@go_threadsafe`: an `allow` entry
`go_override:<import path>.<Func>` on the dependency edge, an override that applies only to the Égide-to-Go edge, and an
ownership test on the declaring package of the resolved object, which rejects promoted methods, aliases of foreign types
and function-typed variables. The same PR fixes the inconsistency between MEM-071, PKG-031/032 and TOOL-011 on where a
package declares its own breaches, and renames `std.unsafe.Ptr` to `std.ptr.Ptr`. Labels: *established* = spec text;
*emerging* = recalled upstream behaviour; *extrapolated* = inference.

## Core Analysis

### Q-0050: `unsafe` is reserved, MEM-070 names `std.unsafe.Ptr[T]`

*Established* (reproduced in Q-0050): `path = IDENT { "." IDENT }` cannot derive `std.unsafe` because LEX-021 reserves
`unsafe`. Only MEM-070 uses the name.

| Option | Assessment |
|--------|------------|
| **A (recommended)** `std.ptr.Ptr[T]` | A restriction; `unsafe` stays reserved and only the block form carries it, so a grep for `unsafe` finds the audit markers (SYN-017, MEM-071). `ptr` rather than `std.raw`, because "raw" is the adjective of raw strings (LEX-052). Any non-keyword name works. The edit is one token, so ADR-0018's brace rewrite of MEM-070 conflicts at most on that token. |
| B contextual keyword | A context rule in lexer and parser; the audit word becomes ambiguous. |
| C keywords as path segments | Weakens LEX-021 for every keyword. |

### F1: `[go.overrides]` is not gated (GO-044)

*Established* by GO-011, GO-044 and PKG-030: a call classified pure needs no capability; GO-044 lets a package reclassify
any function as pure with a free-text reason; PKG-030 lists the breaches needing an `allow` entry and a call reclassified
pure is not an impure call. "Overrides never apply to dependent packages" does not help, because a dependent calls the
declaring package's `pub` API, whose signature has no `using` clause when the body is pure (CAP-034, CAP-040).
`@go_threadsafe` (GO-032) is the same class of assertion and is gated; GO-044 was left out.

Findings of the review and their resolution:

| Finding | Established / emerging | Resolution (GO-044) |
|---------|------------------------|---------------------|
| B2: an override of an unexported helper `m.write` made every Go caller pure | established from the first draft text | the override applies only to the Égide-to-Go edge of that exact function and is never a pure leaf of the Go call graph (item 2); the key must be an exported function or method |
| A1: promoted methods and aliases launder: `type W struct{ *os.File }` in `[go]` module `m`; key `m.W.Write` names a type owned by `m` but the method is `os.File.Write` (class `fs`) | extrapolated by the reviewer from the text; I agree | ownership is decided by the package that **declares the resolved object** (`go/types` `Func.Pkg()` after alias resolution), not by the key; a promoted method, a method of an alias of a foreign type, and a package-level variable of function type (`var Sync = os.WriteFile`) are E0702, together with the standard library, `init` and nested modules |
| N3: nested modules, `[go]` keys named `os` or `std` | extrapolated | the owning module is the one the Go tool reports and must be exactly a `[go]` module; a `[go]` key needs a dot in its first path element (GO-001) |
| N7: `reason` is a TOML string the Égide lexer never sees | established | the manifest reader applies the constraints of SYN-018 and tools apply LEX-006 on output (item 3) |

The justification of function granularity is the narrow one: the root names the function whose class it accepts to be
wrong, and by item 2 nothing else changes class because of it. Residual risk, *established* and accepted: the named function
itself may do anything, exactly as with `unsafe`. Alternatives: delete overrides (legitimate false positives of the
conservative GO-042 would then need a fork of the Go module); module-granular entries (one entry covers every function);
keep as is (rejected).

### A5: where a package declares its own breaches (PKG-031, PKG-032, MEM-071, TOOL-011)

*Established*: MEM-071 says a package declares `allow = ["unsafe"]` "in the manifest of every dependent"; the first-pass
PKG-032 said `[package].allow` and gave a manifest-less script (TOOL-011) an empty list, so a script could not use
`unsafe`; PKG-031 says `allow` is read from the edge-declaring manifest. Options:

| Option | Assessment |
|--------|------------|
| **A (chosen, fail-closed)** the root package must list its own breaches in `[package].allow`; for a dependency the list is informational and never satisfies a dependent's gate; scripts may carry the list in their leading comment block | Keeps the existing test assumption (a manifest-less file has an empty list, so `@go_threadsafe` there is E0421). Cost: a root that uses `unsafe` must say so once more. |
| B the gate protects only against dependencies; the root is never gated | Fewer lines in a root manifest; removes a check that currently fails closed, and changes GO-032's observable behaviour for roots. |

Owner's choice; default A. Either way `allow` is read only from the manifest of the package that declares the edge, never
as a union over the graph (the variant that would let a dependency satisfy its dependent's gate).

### Third-pass findings (security review of head 0c514a86; Go 1.24.7 reproductions by the reviewer, the list targets 1.25)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| B-1: `Func.Pkg()` ownership accepts a local interface method (`type Sink interface{ Write([]byte)(int, error) }`, also embedded in a struct) and a body-less function (assembly stub, `//go:linkname`). Attack: `func Stdout() Sink { return os.Stdout }`, override `m.Sink.Write`, and a write to fd 1 is pure | established (reproduced); the last step extrapolated | GO-044.1 adds to E0702: interface methods (also promoted or via a type parameter), functions without a Go body, and functions whose body triggers GO-042 item 2. The target must have a Go body whose own call graph GO-042 analyses. Overrides exist for items 1 and 3 of GO-042 (calls through values; exported-variable writes), never item 2 |
| B-2: an accepted override masks a later true positive: GO-043 compares the effective class, which stays `pure`; the same for a tuple on which the function is not pure | extrapolated | the lock records the **underlying** class per tuple next to the override; drift compares it; growth of the capability set under an override is E0701 until the entry is re-confirmed by `egide lock` (GO-044.5) | (superseded by B-2' below)
| B-3: duplicated clause in MEM-071; no code for an unlisted `unsafe`/`ffi:`/`go:`/`test-capabilities` in the root; `[package].allow` missing from PKG-010 and the manifest example | established | MEM-071 fixed; new code E0703; PKG-010 and the 10.2 example updated |
| Non-blocking 1: the key grammar is ambiguous for dotted path elements | extrapolated | longest prefix that is a package of a `[go]` module; ambiguity is E0702 |
| Non-blocking 3: generic functions | extrapolated | `Func.Origin()`; the override applies to every instantiation |
| Non-blocking 5: a script's comment block declares its own `allow` | established | TOOL-011 says it is the author's consent, not the runner's |
| Non-blocking 2: overlap with the other ADR PRs | established | the lock key is **(build tuple, declaring package, function)**, stated here in PKG-040; see "Merge order" |

### Fourth-pass findings (security review of head 81683258; reasoned from the text and from `go/types` behaviour reproduced earlier, not re-run)

| Finding | Resolution |
|---------|------------|
| B-1': the E0702 exclusions are bypassed by a one-line exported wrapper in the same module: around an interface method (`V{w io.Writer}` returning `os.Stdout`), around an unexported assembly stub, or a direct `os.WriteFile`. "Never item 2" was decoration (extrapolated attack, established text) | option A of the reviewer: an override **discharges only the findings of GO-042 items 1 and 3** below the function; the **residual** (item 2 findings and every call classified other than `pure`) must be empty, else E0702 prints it (GO-044.2). Wrappers over a stub or over `os.WriteFile` are rejected; a wrapper over an interface call is the canonical item 1 false positive and stays legal, its consent being the digest of item 5 |
| B-2': the "underlying class" is vacuous for an item 1 override: that class is already `Go`, the top of the lattice, and no order was defined, so a version adding a file write does not grow `{Go}` (extrapolated) | the lock records the **set of discharged findings** (function reached, kind, instantiation) and requires an empty residual. A version that adds `os.WriteFile` makes the residual non-empty (E0702); a version that adds another dynamic call changes the discharged set (E0701). Nothing is collapsed to `Go` |
| B-3': re-confirmation by `egide lock` is silent: the confirmation state lives in the lock that the command rewrites, so a bot or CI run clears E0701 with no human decision (established from the text) | the `allow` entry carries the confirmed state, `go_override:m.F=<digest>`; `egide lock` and `egide update` never edit `allow`; `egide lock --confirm go_override:m.F` rewrites that one entry, prints the set difference, and refuses to run without the function named, in any mode (GO-044.5, 6). Digest rather than a readable set because the discharged set is a list of call sites, not of capability classes; `egide audit` prints it in full. Owner's choice: a readable list is the alternative |
| Non-blocking 1: "declaring package" in PKG-040 is ambiguous | classification keyed (tuple, Go package, function); override keyed (tuple, declaring Égide package, Go package, function) |
| Non-blocking 2: PKG-032 enumerated root breaches incompletely | "every kind of entry of PKG-030"; E0703 covers every kind that has no code of its own. The root case of `go_init:` is given its code in ADR-0025 |
| Non-blocking 3: E0702 and the digest must be evaluated per tuple (`purego` versus an assembly stub) | GO-044.6 |
| Non-blocking 4: generics | the confirmed set is computed per instantiation used by Égide source; a new instantiation is a changed set |
| Non-blocking 5, 6: "allocated in merge order" is inexact; "GO 046"/"PKG 043" typos in normative text | reworded ("allocated so that the catalogue stays sorted"); the spec text no longer cites ADR or sibling rule ids |
| Non-blocking 7: with #29 merged first, `docs/adr/README.md` conflicts on the last row | trivial, keep both rows |

### Fifth-pass findings (security review of head 20fc1fbf; P1 to P4 reasoned, P3 and the reflect case verified by the reviewer)

| Finding | Resolution |
|---------|------------|
| P1: `Log` calls a package-level function variable `hook(p)`; an update swaps `hook`'s initialiser for an `os.WriteFile` closure; the finding (function, kind) and the digest are unchanged. Same for a Go-internal interface implementation swapped between versions (P4) | before an item 1 finding is discharged its possible targets are resolved inside the user-package closure (class-hierarchy or variable-type analysis; `golang.org/x/tools/go/callgraph/vta` is the usual tool, recalled) and their classes enter the **residual**. Only a call whose target set is unbounded because it depends on a parameter supplied by the Égide caller is discharged. A changed initialiser therefore makes the residual non-empty (E0702) |
| P2: `Bump` writes the module's own exported variable; an update adds `http.DefaultTransport = evil` in the same function; two writes of the same kind collapsed to one set element | item 3 discharges only writes to exported variables declared in the overridden function's own module; a write elsewhere is residual. The finding identity is (enclosing function, kind, callee type or variable object by package path and name, multiplicity), no positions: stable under refactoring (positions would train `--confirm` into a reflex), fine enough to see a second write |
| P3 (verified): `w := os.Stdout.Write; w(p)` writes to fd 1 but is an item 1 finding although its target is statically known, so the one-line indirection made it override-eligible | covered by the same resolution step: a statically known target is resolved and counted in the residual |
| GO-044.6 against GO-044.2 contradicted: a non-empty residual is E0702, yet `--confirm` was said to lift it | stated: `--confirm` never lifts E0702 |
| A single digest cannot equal the computed value for every locked tuple when sets differ (`x_windows.go` against `x_linux.go`) | the digest covers the map from every locked tuple to its set; adding a tuple with `egide lock --target` changes it and needs a confirmation. The alternative is one entry per tuple (`=<tuple>:<digest>`); owner's choice, default one digest |
| Non-blocking: define the residual over findings, not over the class of callees | stated: a callee that is `Go` only because of a discharged item 1 finding does not count |
| Non-blocking: `--confirm` should take the old digest | `egide lock --confirm go_override:<path>.<Func>=<old digest>`; refuses without both |
| Non-blocking hygiene: a script's self-declared `allow` includes override digests, so the gate does not protect `egide run untrusted.egd` | accepted in this ADR (A5); `egide run` of a script prints the `allow` entries it declares for itself |

**Out of scope of this ADR but recorded, reproduced by the reviewer on Go 1.24.7 (established).** The purity list classes
`reflect` as `pure`, yet `reflect.ValueOf(os.Stdout).MethodByName("Write").Call(...)` writes to fd 1 with no `unsafe` and no
function value (GO-042 item 4 of ADR-0025 would catch only the variant that passes `os.WriteFile` as a value). The appendix row
for `reflect` is amended in this PR (one row): `Value.Call`, `CallSlice`, `Method`, `MethodByName` and `Interface` are `go`.
Follow-ups for the owner and the orchestrator, not done here: a `go-interop-engineer` task to carry the amended row into
`go1.25.lst` (T-0040) and a call-graph rule so that GO-042 item 2 treats `reflect` method invocation as impure; a
`tests/security/` case (the `security-reviewer` writes it, append-only; the reviewer has said they will file it): a module
function that calls `reflect.ValueOf(os.Stdout).MethodByName("Write").Call(...)` must be classed `go` and must not be
overridable (E0702), and a `test-engineer` conformance case that a `reflect.Value.Call` in a compile-time context is E0611
once ADR-0023 is accepted.

### Merge order

Recommended: **#32, #33, #34, #35**, as a stack (each PR's base is the previous branch; GitHub retargets to `main` as they
merge). #29 and #30 touch only ch. 2/3 and can merge at any time; they conflict with the others only in
`docs/adr/README.md` and `docs/diagnostics.md` rows. Use merge commits, not squashes, for the stacked PRs. Codes were
allocated so that the catalogue stays sorted: ADR-0022 E0701-E0703, ADR-0025 E0704-E0705, ADR-0024 E0706-E0708, ADR-0023 E0709
(this is not the stack order). The PKG-030 sentence is extended by this ADR (`go_override:`) and by ADR-0025 (`go_init:`); the
lock rules are PKG-040 (here) and the Go-closure lock rule of ADR-0024.

## Decision

Apply the spec diff: MEM-070 (`std.ptr.Ptr[T]`), MEM-071 (root clause), GO-001 (`[go]` key rule), GO-044 rewritten,
PKG-030/031/040, new PKG-032, TOOL-011 (script `allow`), diagnostics E0701, E0702 and E0703. New rule id: PKG-032.

## Alternatives considered

In the sections above.

## Consequences

- Complexity budget: +1 rule, +2 diagnostics, +1 `allow` form; no language feature.
- Security: closes override laundering (F1, B2, A1). Residual: an accepted `go_override:` entry grants what it names.
- Ranges: the new codes are in E07xx ("packages and Go interop", currently empty), as the second-pass review (C7) asked;
  E0420/E0421 stay where they are.
- Implementation (follow-ups proposed, none created): `go-interop-engineer` and `tooling-engineer`: manifest reader,
  ownership resolution with the Go type checker, lock keys; `security-reviewer`: negative PoCs for A1 (alias, promoted
  method, function-typed variable) and B2 in `tests/security/` (append-only, not touched here).
- Migration: pre-1.0, no Go interop exists yet.

## Recommendations / Next Steps

1. `security-reviewer`: re-review A1 and A5.
2. Owner choices (defaults): `std.ptr`; A5 option A.
3. This PR conflicts textually with the other ADR PRs only in `docs/adr/README.md`, `docs/diagnostics.md` and
   neighbouring lines of ch. 10/11/13; none semantically.
4. Not verified: nothing was run; A1 is reasoned from the text and recalled Go semantics.
