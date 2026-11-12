# ADR-0026: Third-party Go modules: a reviewed baseline, the analysis as a review aid

- Status: Proposed
- Date: 2026-11-12 (split out of ADR-0025 on the owner's decision after ten security-review passes)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. The owner delegated the choice of the baseline to the
  orchestrator (review at the MVP); the owner's merge of this PR is the acceptance. Needs the `security-reviewer` (ch. 11).
- **Depends on ADR-0024 and ADR-0022.** This PR is based on the ADR-0024 branch (its diff includes ADR-0022 to ADR-0024
  until they merge). It amends GO-044 of ADR-0022.
- Spec chapters affected: 10 (PKG-030 reference to overrides, PKG-040, PKG-043), 11 (GO-025 new, GO-042 rewritten,
  GO-043, GO-044 items 1, 2, 5), appendix A (GOP-007, GOP-008 new, A.3 rows, `go1.25.lst`), `docs/diagnostics.md` (E0712,
  E0713)

## Executive Summary

Ten review passes on the static classification of third-party Go code (GO-042) each found a new way to evade it
(interface conversions, fields and elements, function values in composites, generics, standard-library variables and
their aliases, local-type spelling, key size). Each rule is a heuristic over Go semantics, so the gate cannot be
complete. This ADR changes the gate: a function of a third-party Go module is `go` (impure) unless a **reviewed entry**
names it, the static analysis is demoted to a **review aid** that cannot grant a class, and everything already written
about the analysis is kept as the reviewer's checklist and as normative requirements on the standard-library purity list.
Labels: *established* = spec text or a reproduction in the reviews; *emerging* = recalled upstream behaviour;
*extrapolated* = inference.

## Core Analysis

### 1. The decision

| Before (ADR-0022 to ADR-0025) | After (this ADR) |
|-------------------------------|------------------|
| a third-party function is `pure` when the analysis finds nothing | it is `go` unless a reviewed entry (a GO-044 override) names it |
| an evasion of the analysis grants a class (authority) | an evasion of the analysis hides a finding from the reviewer; no class changes |
| overrides discharge false positives, class `pure` only | an override is the reviewed classification: class `pure` or one capability class, bound to the module version through the digest |
| GO-042 is normative | GO-042 items 1 to 5: items 1 to 4 are the review aid (kept in full), item 5 is a call-site rule |

*Established* (the reviews): the analysis was evaded by `fmt.Sprint(T{})`, `fmt.Sprint(Outer{…})`, a `FuncMap`, `Gen[Evil]`,
`&rand.Reader`, `a := os.Args; a[0] = …`, `*time.UTC = …`. *Extrapolated*: further evasions exist, because the Go
language (reflection, aliasing, generics, linkname) is richer than any finite rule set.

### 2. What the baseline costs and what it keeps

- Cost: a person confirms a reviewed entry for each third-party Go function that Égide calls, and again after each
  version change of its module (the digest includes the module version). Functions the Égide program does not call
  directly need no entry, because the entry asserts the whole call graph below the function (GO-044.3 keeps the class of
  the function inside Go unchanged).
- Kept: GO-043 drift detection, GO-044 gates (digest in `allow`, `--confirm` by a person, residual rule), the lock
  keys with type arguments and their caps (E0712, E0713), the standard-library list requirements (GOP-007, GOP-008, the
  reclassifications) and GO-025.
- New: GO-042 item 5, a rule about a call from Égide to a standard function: the arguments' method sets and type closure
  count, a method of a third-party type is `go` unless reviewed. It is decided from types the Égide compiler already
  holds and does not use the call-graph analysis, so it closes the path "Égide passes a third-party Go value to
  `fmt.Sprint`" that the baseline alone would leave open (*extrapolated*).

### 3. Alternatives

| Option | Why not |
|--------|---------|
| A. keep hardening the analysis as the gate (ADR-0025 tenth-pass state) | a new evasion every pass; the cost of an evasion is authority |
| B. forbid third-party Go modules | removes the Go ecosystem, the point of the Go backend |
| C. per-module entry (`go:<module>`) only | exists (PKG-030) but is coarse: it approves every function of the module, including future ones. Kept as the way to call an unreviewed function with `Go` |
| D. this ADR | fails closed; review effort is visible in the manifest and the lock |

## Findings that led to the baseline (moved verbatim from ADR-0025)

The sections below were written in ADR-0025 during the sixth to tenth passes and are relocated here with their
resolutions; the rules they describe are now GO-042 items 1 to 5, GO-025, GOP-007, GOP-008 and the list changes.

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

### Tenth-pass review (B-1'' to B-3'' verified or reasoned by the reviewer)

| Finding | Resolution |
|---------|------------|
| B-1'': the lock key spells type arguments as a tree, its length is exponential in nesting depth (a 310-byte source gives a 28 MB key with 14 instantiations); the three counts never trigger | cap of 1024 bytes on the readable spelling and 4 MiB on all keys, computed bottom-up on the type graph with saturating arithmetic before any string is built (E0712); the identity of an entry is the SHA-256 over the shared graph (linear), the readable form is display |
| B-2'': a store through an exported variable is not a write of the variable (`a := os.Args; a[0] = "x"`, `*time.UTC = …`, `unicode.Upper.R16 = nil`); aliasing defeats any syntactic rule | the class is decided by the variable's **type**: pointer, slice, map, function, channel, interface, or struct/array containing one: `go`, unless the line is annotated `immutable` after review. Value types (numbers, strings, booleans and arrays/structs of them) take their line's class. `io.EOF` is `immutable` (justified in GO-042: unexported fields, no mutating method); `os.Args`, `crypto/rand.Reader`, `time.UTC`, `time.Local`, `unicode.*` are `go`. Cost: `time.Date(…, time.UTC)` written in a Go closure is `go`; Égide never touches `time.UTC` (GO-025). Alternative: a per-variable syntactic alias analysis. Rejected, aliasing defeats it |
| B-3'': local-type spelling not injective (`func (A) String` and `func (B) String` both spell `p.String.t#1`; `init`, closures) | owner path includes the receiver type, `init.<k>` and `.func<k>` ordinals in source order, independent of line numbers |
| `Time` and the `Local` zone | GO-025: `.UTC()` at the §11.3 boundary, UTC-only Égide constructors. `time.Parse`, `ParseInLocation`, `Time.Unmarshal*`, `GobDecode`, `Time.Local` are `clock` (they select `Local`); the A.3 `time` row no longer says `Unix` or `Parse*` are pure; a conversion of a std type counts its methods with the classes of the list (so `json.Unmarshal(&t)` reaches `UnmarshalJSON`); `flag.Parse` is `env` |
| implicit address-of, method instantiations, no code for "no Go mapping" | implicit address-of is a use and a write; the bound counts methods of generic types; E0713 |

**Is the Go purity model too intricate for one ADR? Yes, and I recommend a split.** ADR-0025 currently carries the init rule of ADR-0025 (package
initialisation), the GO-042 analysis rules (item 3 variables, item 4 function values, interface conversions, type closure,
generics, the lock key) and the purity-list reclassification. The analysis rules have grown with every pass because each
rule is a heuristic over Go semantics (aliasing, reflection, generics, stdlib dispatch) and every pass finds a new
evasion. Proposal: (1) keep the init rule of ADR-0025 and the init classification in ADR-0025; (2) move the GO-042 amendments into a new ADR
whose **baseline is conservative**: a function of a third-party Go module is `go` unless a reviewed entry names it
(module, version, function) as `pure` or as a specific class in the lock; the static analysis (GO-042) becomes a **reviewer aid**
that proposes a classification and flags the findings of this PR, instead of the gate. The cost is a human review per
dependency version (drift detection GO-043 already forces a diff); the gain is that no unforeseen evasion of the
analysis grants authority, because the gate no longer relies on its completeness. That ADR would carry the rules above
as the reviewer's checklist, not as normative proof. This is the owner's decision; this PR keeps the analysis as the gate.

## Decision

Apply the spec diff: GO-042 rewritten (baseline, review aid, item 5), GO-044 items 1, 2 and 5 amended (capability
classes, residual rule for them, module version in the digest), GO-025, GOP-007, GOP-008, the A.3 reclassifications,
`go1.25.lst`, PKG-040 and PKG-043 keys with type arguments, diagnostics E0712 and E0713.

## Consequences

- Complexity budget: no new construct; one rewritten rule, one new rule (GO-025), two list rules, two diagnostics. GO-044
  becomes the single mechanism that classifies third-party code.
- Security: INT-001..005 unaffected. Residual: an entry asserts a property the compiler does not check, like `unsafe`;
  review quality (a person, with the aid's findings) is now the control. The standard-library list remains a reviewed gate
  with the requirements above.
- Implementation (follow-ups proposed, none created): `go-interop-engineer`: review-aid report in `egide audit` and in the
  `--confirm` output, GO-042 item 5 in the call-site checker (T-0083), the list audit (T-0040, text in the tenth-pass
  section); `tooling-engineer`: digest with module version; `test-engineer`: acceptance cases listed in the relocated
  sections; `security-reviewer`: PoCs in `tests/security/` after merge.
- Migration: pre-1.0, no Go interop exists yet.

## Recommendations / Next Steps

1. Merge order: ADR-0022, ADR-0023, ADR-0024, then this ADR, then ADR-0025 (the init rule of ADR-0025), which does not depend on it.
2. `security-reviewer`: focus on GO-042 item 5, the GO-044 amendments, and whether any rule left in "review aid" still acts as a gate.
3. Not verified: nothing was run; the review-aid rules are as reviewed in the relocated passes, whose reproductions were on Go 1.24.7.
