# ADR-0025: Classification of Go package initialisation (`init`)

- Status: Proposed
- Date: 2026-11-11 (split out of ADR-0022 after its security review)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. Needs the `security-reviewer` (ch. 11).
- **Depends on ADR-0024 and MUST NOT be accepted before it.** GO-045.3 relies on GO-046 to keep cgo, `.syso` objects and
  unselected files out of the closure. This PR is based on the ADR-0024 branch for that reason (its diff includes ADR-0024
  until that PR merges). Until both are accepted and implemented, T-0082 must not load any Go package.
- Spec chapters affected: 10 (PKG-030, PKG-043), 11 (GO-042 item 4, new GO-045), appendix A (new GOP-005, GOP-006),
  `docs/diagnostics.md`

## Executive Summary

Go runs the `init` functions and package-level initialisers of every linked package before `main`, with the process's
authority and before any capability exists; a blank import runs them without any call. GO-010 to GO-012 gate calls only, so
this is an unclassified path to authority, and a `forbidden` package such as `net/http/pprof` was reachable through a
third-party blank import. GO-045 classifies init sets per package: the standard library through reviewed `.init` lines
(only `pure` accepted), third-party modules through the GO-042 analysis with a separate `go_init:<module>` entry, and
`forbidden` init is an error no entry lifts. Labels: *established* = spec text or documented Go semantics; *emerging* =
recalled upstream behaviour; *extrapolated* = inference.

## Core Analysis

### 1. The hole

*Established* Go semantics: importing a package runs its variable initialisers and `init` functions, transitively, before
`main`. *Established* from the spec: GO-010..012 gate calls, GO-042 classifies "functions callable from Égide", GO-043 covers
"a function called by the Égide program". `init` is in no classification, no lock entry and no drift check; a dependency
update that adds `init() { … }` anywhere in the closure runs at start-up with no `allow` change. GO-013 (sandbox) is the only
barrier, and CAP-051 says guarantees do not rely on it.

### 2. Findings of the review and resolution

| Finding | Resolution |
|---------|------------|
| B1 (established from appendix A.3): `net/http/pprof`, `expvar`, `plugin` are `forbidden` and dangerous through initialisation; a single `go:std` entry made a third-party `import _ "net/http/pprof"` acceptable | init class `forbidden` is E0705 with no entry; no `go:std` entry exists |
| C1 (second pass): 45.1 must say the test applies to every standard package in the closure, including through third-party packages | GO-045.1 says so explicitly, with `plugin` as the example |
| N1: `go:<module>` was shared with call authority, so approving calls approved later initialisers | separate key `go_init:<module>` (E0704); std init classes are a reviewed per-Go-version baseline, not a per-root decision |
| N2 (extrapolated): callbacks registered in `init` (`image.RegisterFormat`, `sql.Register`, `http.HandleFunc`, `signal.Notify`) are invoked later by pure-classified functions | GO-042 item 4: a function value passed as argument, stored in a variable or field, or started with `go`/`defer` counts as called by the function that does it. Conservative; it will over-classify (extrapolated) |
| N5, C3: the runtime exclusion list was unenumerated and generated | GOP-006: enumerated file, generated from `runtime/go/rt` imports, CI fails if the committed file differs from the generated one, review under GOP-003 |
| C6 (extrapolated): GOP-005 accepts only `pure`; `net/http` reads `GODEBUG` at init, so under GO-042 it classifies non-pure unless a reviewer writes `net/http.init pure` | accepted: GOP-005 requires an explicit reviewed decision for `net/http`, `crypto/*`, `database/sql`, `os`; T-0040 makes them |
| cgo constructors, `.syso` and asm init-array entries (B4, first pass) | not part of the init set: GO-046 removes cgo and `.syso` from the closure (hence the dependency on ADR-0024) |

### 3. Alternatives

Forbid every Go package with a non-pure init set: rejected (*extrapolated*: `client-go` registers schemes and flags at init
and would be unusable). Run init in a sandbox: not possible in Go's runtime. Do nothing: contradicts "auditable" (11.2).

### Third-pass review (APPROVE after ADR-0024; wording residuals applied)

- **R-1 (extrapolated).** A callback registered in an init (`image.RegisterFormat`) later runs through a std dispatcher the
  list classifies pure (`image.Decode`, `crypto.Hash.New`, `sql.Open`). The consent is the `go_init:` entry, but its apparent
  scope is start-up. GO-045.2 now says the entry grants the recorded set of capability classes wherever the callbacks are
  reachable, and `egide audit` prints the callbacks.
- **R-2 (extrapolated).** The entry is per module, the class is per init set: drift compares the capability set, not
  "impure" (a module approved for `env` whose update adds `net` fails, E0704), so the masking of ADR-0022 B-2 does not recur.
- GOP-006 says "every program of the Go backend" (on the native backend only Go-interop programs link the runtime packages).
- T-0040 must be told that an absent `.init` line is `go` and therefore E0705 (fail closed): a new Go minor with unreviewed
  packages breaks builds until they are reviewed. Codes follow merge order: E0704 (impure init not listed), E0705 (forbidden or
  non-`pure` standard init).
- The PKG-030 sentence carries both `go_override:` (ADR-0022) and `go_init:` and the lock rule is PKG-043 (ADR-0024); this
  branch is a merge of the previous branches in the stack, so it is rebase-clean against ADR-0024.

## Decision

Apply the spec diff: GO-045, GO-042 item 4, PKG-030 (`go_init:`), PKG-043 (lock records init classes), GOP-005, GOP-006,
diagnostics E0704 and E0705 (E07xx).

## Consequences

- Complexity budget: +1 rule, +2 appendix rules, +1 `allow` form, +2 diagnostics.
- Security: closes the unclassified start-up path and keeps `forbidden` meaningful. Residual: an accepted `go_init:` entry
  grants what it names; the sandbox is the only barrier for initialisers; the std baseline depends on the T-0040 review.
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: init sets and the callback rule in T-0040 and
  T-0083, the GOP-006 generator and CI check; `tooling-engineer`: lock, audit and drift; `security-reviewer`: PoCs
  (blank import of `pprof` from a third party, init that registers a callback, `import _ "plugin"`).
- Migration: pre-1.0, no Go interop exists yet.

## Recommendations / Next Steps

1. Merge order: ADR-0024, then this one (retarget the PR to `main` after ADR-0024 merges).
2. `security-reviewer` re-reviews. 3. Not verified: nothing was run; the effect on `net/http`, `crypto/*`, `os` is
   extrapolated until T-0040.
