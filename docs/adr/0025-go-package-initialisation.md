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

### Fourth-pass review (APPROVE, conditional on ADR-0024)

- GO-045.3 ("cgo, `.syso` and unselected files are not in the init set") is true only once ADR-0024 B-1' is fixed: a plain
  `.go` file with `//go:cgo_import_dynamic` loads a shared library before `main` under `CGO_ENABLED=0` (reproduced by the
  reviewer). ADR-0024 now rejects those directives (E0706) and requires a static binary (E0710), and GO-045.3 states the
  dependency in the rule text: **GO-045 MUST NOT be applied without GO-046.** This ADR stays blocked on ADR-0024.
- The root case of `go_init:` is given in the text of E0704 (the root lists it in `[package].allow`, PKG-032).

### Fifth-pass review (H-1, reasoned)

GO-045.2/.4 said drift of a `go_init:<module>` grant is "confirmed again by `egide lock`", but the recorded class set lived
in the lock, which `egide lock` rewrites, so a bot or CI step clears E0704 with no human decision: the defect of ADR-0022 B-3',
and for initialisers, which nothing but the sandbox can mediate. Fixed in the same way: the entry carries the classes
(`go_init:<module>=<classes>`; they are few and readable, unlike the override digest); `egide lock` and `egide update` never
write `allow`; `egide lock --confirm go_init:<module>=<old classes>` does, and prints the difference; an added class fails, a
removed class need not. The stack is now consistent with ADR-0022. The blank line between the E0611 and E0701 rows of the
catalogue (it ended the Markdown table) is removed.

### Sixth-pass review (blocker N2/R-1, reproduced by the reviewer on Go 1.24.7)

- *Hole in GO-042.* A user type with methods, converted to an interface and passed to a standard function the list marks
  `pure`, is invisible to the analysis: acceptance cases (go-interop-engineer, T-0040/T-0083): (a) `fmt.Sprint(T{})` where
  `T.String` writes a file; (b) `sort.Sort(x)` where `x.Less` writes a file. GO-044's residual inherits the gap and needs no
  override to exploit it.
- *Resolution.* GO-042 item 4: a value converted to an interface type counts as calling every method of the method set of
  its dynamic type, at the conversion. Alternative: mark the dispatcher functions (`fmt.Sprint*`, `sort.Sort`, ...) in the
  purity list as `dispatches`/impure. Rejected as the primary fix: the list would need every standard function that takes
  an interface and calls its methods, it would not cover user-package code that does the same, and it would mislabel
  the callee, not the conversion. Cost: a user type with an impure method is reported at every conversion to an interface
  (over-approximation; the fix is a pure method, no override applies).
- *`go_init:` re-confirmation (non-blocking).* Any difference between computed classes and entry, including a removed
  class, now fails E0704 and needs `--confirm`: otherwise a later version re-adding the class would pass unconfirmed.
  Cost: one confirmation when an init set shrinks.

### Seventh-pass review (R-1 to R-3, reproduced by the reviewer)

| Finding | Resolution |
|---------|------------|
| R-1: methods reached through fields and elements (`fmt.Sprint(Outer{E: Evil{}})`, `json.Marshal`) | GO-042 item 4: the rule extends to the type closure (fields, array/slice/chan/map elements, keys, pointees, interface-typed fields as every implementing type of the user-package closure). Cost: a larger over-approximation, bounded by the closure of user types; acceptance cases `fmt.Sprint(Outer{…})` and `json.Marshal(Outer{…})` for T-0040/T-0083 |
| R-2: a function value in a `template.FuncMap` is not "passed as an argument"; `text/template` is `pure` in the list and ran it | GO-042 item 4: a function value stored into any composite value that is passed to a standard function counts as called by the storing function. Alternative: reclassify `text/template` and `html/template` Execute functions as impure. Not done in the spec text because the purity list belongs to GOP-xxx review; recommended as an additional list change for the `security-reviewer`, since the rule above does not cover a template parsed from a file that names functions registered elsewhere (extrapolated) |
| R-3: generics (`Gen[T any](v T)` is pure, `Gen(Evil{})` is not) | GO-042 item 4 and GO-044.2: analysis per instantiation; a new instantiation is a new classification (lock) and may change the override digest or residual |

### Eighth-pass review (B-1 to B-3 reproduced by the reviewer on Go 1.24.7)

| Finding | Resolution |
|---------|------------|
| B-1: reads of standard-library variables (`io.ReadFull(rand.Reader, b)`, `strings.Join(os.Args[1:], " ")`) are pure under the amended GO-042 | GO-042 item 3: a read of an exported standard-library variable takes the class of its list line; new GOP-007 (`<import path>.var.<Name> <class>`, default `go`, not covered by `.*`); seed lines added for `crypto/rand`, `os`, `io`, `time.Local` |
| B-2: `return map[string]any{"run": evil.Run}` stays pure; item 4 named only variables and fields | GO-042 item 4: any function value that is not the callee of a direct call counts as called where it appears; implicit interface conversions (assignment, argument, return, literal, send) are covered. Alternative: keep the conditional rule (composite passed to a standard function). Rejected: the conditional is exactly what the reproduction evades |
| B-3: generics share the lock key `(tuple, package, function)` | PKG-040, PKG-043 and the digest of GO-044.5 add the type arguments to the key |
| list reclassification (defined by the `security-reviewer`) | A.3 and `go1.25.lst`: `text/template`, `html/template`: `ParseFiles`, `ParseGlob` (functions and `(*Template)` methods) `fs`, `Execute`, `ExecuteTemplate` `go`, rest `pure`; `archive/zip.OpenReader`, `crypto/tls.LoadX509KeyPair`, `mime.TypeByExtension`, `mime.ExtensionsByType` `fs`; `mime.AddExtensionType` `go`; `reflect.Value.Seq`, `Seq2` `go`. New GOP-008: a wholesale `pure` claims no ambient reads and is reviewed per function |
| non-blocking: `context` and `time.Local` clock or disk reads | `time.var.Local clock` added; `context.WithDeadline` and `WithTimeout` read the clock but contexts are injected (GO-022): left in the T-0040 audit, not decided here |

Recommended follow-up task text (not created): *T-NNNN, stdlib purity list audit (go-interop-engineer + security-reviewer):
for every function and exported variable of the Go standard library in the list, decide the class by reading the code for
reads of ambient state (clock, `time.Local`, environment, argv, random source, disk, user and network databases, global
registries) and for calls of functions received as arguments or stored in values (`Funcs`, `Seq`, `sort`, `slices`
comparators); remove every wholesale `pure` line that fails GOP-008; add the acceptance cases `func leak() (*io.Reader, *[]string) { return &rand.Reader, &os.Args }` followed by `io.ReadFull(*pr, b)` and `len(*pa)`, `io.ReadFull(rand.Reader)`,
`strings.Join(os.Args[1:], " ")`, `fmt.Sprint(Outer{…})`, `json.Marshal`, a `FuncMap` template and `Gen[Evil]` to the
conformance suite.*

### Ninth-pass review (B-1' reproduced on Go 1.24.7)

| Finding | Resolution |
|---------|------------|
| B-1': `func leak() (*io.Reader, *[]string) { return &rand.Reader, &os.Args }` is pure; reads and writes through the pointers are invisible | GO-042 item 3: every use of an exported standard-library variable takes its list class, and taking its address is a use that also counts as a write (impure). Acceptance case added to the T-0040 audit text: `leak()` above, then `io.ReadFull(*pr, b)` and `len(*pa)` |
| `crypto/tls.* pure` (GOP-008 claimed it corrected): `Client`, `Server`, `Handshake` read `rand.Reader`, the clock and system roots | `crypto/tls` is `go` by default; `Dial*`, `Listen` `net`, `LoadX509KeyPair` `fs`, `X509KeyPair` `pure` |
| `context.WithTimeout`, `WithDeadline` and `time.AfterFunc` read the clock under pure lines; `time.Unix(...).Format` reads `$TZ` and `/etc/localtime` | the four `context` constructors and `AfterFunc` are `clock`; `time.Unix`, `UnixMilli`, `UnixMicro` are `clock` (the `Local` zone is host state reached through the clock capability). Residual: a `Time` obtained by other means and formatted in `Local` (extrapolated) stays with the T-0040 audit |
| `fmt.Fprintln(os.Stdout, …)` becomes `go` through the conversion rule, so `os.var.Stdout stdout` is useless | fix the line, not the rule: `os.var.Stdin/Stdout/Stderr` are `go`, and GO-042 item 4 states the supported path (the writer Égide passes, which comes from Égide, or `fmt.Print*` = `stdout`). Alternative: special-case a direct `os.Stdout` conversion to the variable's class. Rejected: the callee may type-assert to `Truncate`, `Fd` or `ReadFrom` |
| spelling of type arguments in the lock key | `go/types.TypeString` after alias resolution, full import paths, local types `<path>.<func>.<name>#<n>`, anonymous structs with names, types and tags (GO-042 item 4) |
| instantiation growth unbounded | 64 per generic function, 4096 per program, nesting 16; E0712. The numbers are *extrapolated* defaults |
| an Égide generic calling a Go generic | analysed per Égide instantiation; the Égide type arguments are mapped by §11.3; a type argument with no mapping is a compile error |

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
