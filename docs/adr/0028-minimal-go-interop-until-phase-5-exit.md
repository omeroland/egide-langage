# ADR-0028: Minimal Go interop until the exit of phase 5

- Status: Proposed
- Date: 2026-11-14
- Deciders: owner
- Decided by: proposed after an external feasibility review of the design (owner request, 2026-11-14); **not accepted**.
  Needs the `security-reviewer` (ch. 11 is touched).
- Spec chapters affected: 10 (PKG-030, PKG-040, PKG-043), 11 (GO-042 review aid, GO-043, GO-044, GO-045 item 2)
- Relation to ADR-0022..0026 (all Proposed): does not contest their analysis. It proposes an **order**: which of their
  rules are implemented for the phase 5 exit, and which wait for evidence from a real program.

## Executive Summary

Chapter 11 is 57 kB, more than chapters 4 to 9 together, and five Proposed ADRs refine it before any Go interop exists.
Its baseline (ADR-0026: every third-party Go function is `go`) is sound and cheap; the machinery on top (overrides with
digests, review-aid call-graph analysis, per-version `go_init` entries) is expensive and its value is unmeasured. This ADR
proposes to implement the baseline and the build confinement first, measure on client-go, then decide the rest.

## Core Analysis

Labels: *established* = text of this repository; *extrapolated* = the reviewer's inference, not measured.

### 1. The flagship program pays the full price and gets the coarse grant

*Established*: the phase 5 exit criterion is a tenant operator against a cluster (`docs/roadmap.md`);
`examples/k8s_namespaces.egd` runs everything under `given sys.go`. GO-042 (as amended by ADR-0026) classifies every
client-go function `go` unless a reviewed override exists.

*Extrapolated*: such a program holds `Go`, which is ambient authority, in most of its call graph. Overrides would only
help if someone reviews client-go function by function, per version. The supply-chain benefit of ADR-0003 then rests on
the OS sandbox (GO-013), not on the classification.

### 2. `go_init` entries

*Established* (GO-045 item 2): an init set is trivial only if the package has no `init` function and every package-level
initialiser is a constant expression or a composite literal of constants, with no call. `var ErrNotFound =
errors.New("not found")` is a call. Any other init set needs `go_init:<module>@<version>=<classes>` written by hand, and
again at each version change (item 4).

*Extrapolated, to be measured by T-1164*: most modules of the client-go closure are non-trivial under this test, so the
first build of an operator needs tens of hand-reviewed entries and each `egide update` needs them again. The measurement
could not be made for this ADR (no access to the Go module proxy from the review environment).

### 3. Type-mapping friction that the rules do not remove

*Established*: `*T` maps to `GoRef[T]?`, not `Send` without `@go_threadsafe` (GO-032); slices and maps are copied both
ways (GO-021). *Extrapolated*: informers, work queues and reconcilers of controller-runtime pass pointers between
goroutines, so an operator will carry `@go_threadsafe` on most types it touches. This is a usability risk to measure with
the first operator, not a soundness problem.

### 4. Counter-hypothesis

"Deferring the gates trains users to accept a coarse `go:<module>` entry, and tightening later breaks them." True, and it
is why items 1 and 2 below keep every rule that cannot be added later without a soundness gap (build confinement, no Go at
compile time, impure by default). What is deferred only ever **narrows** a grant that the baseline already refuses to
widen.

## Decision

Until the phase 5 gate report:

1. **Implement**: GO-001..003 (Go backend only), GO-010..013, GO-020..032, the baseline of GO-042 (third-party = `go`),
   GO-041 with the list as it is, GO-046 items for the Go backend (no cgo, pinned toolchain, static binary, hostile
   archives), CT-006 (ADR-0023), GO-045 item 1 (standard packages), and `go:<module>` in `allow`.
2. **Simplify for now**: a non-trivial third-party init set is covered by the `go:<module>` entry of its module;
   `egide audit` lists the init functions. The per-version `go_init` key of GO-045 item 2 is specified but not enforced.
3. **Defer**: GO-044 overrides and their digests, the review-aid analysis of GO-042 (T-0083), GO-043 drift detection
   beyond "the module version changed", the per-(tuple, function, type arguments) lock entries of PKG-040/PKG-043, and the
   native-backend part of GO-046.1 (see ADR-0027).
4. **Decide with data**: the phase 5 gate report includes the measurements of T-1164 and the list of `@go_threadsafe` and
   `go` grants of the operator. The deferred rules are then accepted, simplified or dropped by ADR.

## Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| Status quo (implement ADR-0022..0026 in full for phase 5) | finest audit trail from day one | largest chapter implemented before any user; per-version review load unmeasured | cost established, benefit extrapolated |
| No third-party Go at all before 1.0 (standard library only) | smallest boundary | removes the phase 5 exit criterion and the reason for ADR-0008 | defeats the Go backend's purpose |
| Process isolation: Go code in a separate sandboxed process, RPC boundary | real authority boundary, not a visible breach | copies and latency; no shared `chan` | worth a post-1.0 ADR for high-assurance users |

## Consequences

- Complexity budget: no rule removed from the spec; about half of chapter 11 leaves the phase 5 critical path.
- Security: INT-001..005 unaffected for Égide code. Item 2 is weaker than ADR-0025: approving a module's calls also
  approves initialisers it gains later, until item 4 is decided. *Residual*: the same as today's Go programs, bounded by
  the sandbox.
- Implementation: T-0082 keeps its scope; T-0083 moves after phase 5; T-0040 unchanged.
- Migration: none (no Go interop exists).

## Recommendations / Next Steps

1. Owner: decide the merge order with ADR-0022..0026. This ADR can be accepted alone: it only orders their implementation.
2. `security-reviewer`: check that nothing in "Defer" is needed for the soundness of "Implement" (GO-045 item 3 says
   GO-045 is sound only with GO-046: item 1 keeps GO-046).
3. `go-interop-engineer`: T-1164 first; its numbers may invalidate §2.
4. Not verified: §1-§3 extrapolations. Nothing was run.
