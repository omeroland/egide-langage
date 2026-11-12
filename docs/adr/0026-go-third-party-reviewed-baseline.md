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
| overrides discharge false positives, class `pure` only | an override is the reviewed classification: class `pure` or one capability class, bound by the digest to the versions and hashes of every module of the function's import closure |
| GO-042 is normative | GO-042 items 1 to 5: items 1 to 4 are the review aid (kept in full), item 5 is a call-site rule |

*Established* (the reviews): the analysis was evaded by `fmt.Sprint(T{})`, `fmt.Sprint(Outer{…})`, a `FuncMap`, `Gen[Evil]`,
`&rand.Reader`, `a := os.Args; a[0] = …`, `*time.UTC = …`. *Extrapolated*: further evasions exist, because the Go
language (reflection, aliasing, generics, linkname) is richer than any finite rule set.

### 2. What the baseline costs and what it keeps

- Cost: a person confirms a reviewed entry for each third-party Go function that Égide calls, and again after each
  version change of any module in its import closure (the digest covers them all). Functions the Égide program does not call
  directly need no entry, because the entry asserts the whole call graph below the function (GO-044.3 keeps the class of
  the function inside Go unchanged).
- Kept: GO-043 drift detection, GO-044 gates (digest in `allow`, `--confirm` by a person, residual rule), the lock
  keys with type arguments and their caps (E0712, E0713), the standard-library list requirements (GOP-007, GOP-008, the
  reclassifications) and GO-025.
- New: GO-042 item 5, a rule about a call from Égide to any Go function whose own class is below `go`: the arguments'
  method sets and type closure count, a method of a non-standard type is `go` unless reviewed. It is decided from types the Égide compiler already
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
as the reviewer's checklist, not as normative proof. This was the owner's decision; ADR-0026 proposes it (ADR-0025 as it stood kept the analysis as the gate).

## Eleventh-pass review (blockers B-1 to B-3, reproduced or reasoned by the reviewer)

| Finding | Resolution |
|---------|------------|
| B-1: item 5 covered only std functions listed `pure`; `fmt.Printf("%v", Evil{})` (`stdout`) runs `String`; a reviewed-`pure` `Render(v any)` dispatches to an unreviewed `Evil.String`; interface-typed arguments have no implementers; a function value passed from Égide is not counted | item 5 applies to any Go callee whose class is below `go` (std of any class, reviewed third-party), over arguments of (a) types with methods, (b) interface types (every implementer in the Go closure, else `go`), (c) function values (counted as called at the call site, else `go`); item 4's closure definition is declared normative for it |
| B-2: the digest holds only the declaring module's version, but an entry asserts a graph that spans other modules | the preimage covers path, version and directory hash of every module in the transitive import closure of the function's package, and the `GOROOT` hash. Alternative: only modules the aid finds reachable. Rejected, the aid has holes |
| B-3: the baseline named only modules of `[go]` | the baseline is every non-standard package of the Go closure; entries for transitive modules are keyed by the import path of the declaring package, with module path and version recorded in the lock (GO-044.1) |
| E0712 and GO-043 still act as gates | the sentence now lists them: they fail closed and grant nothing; GO-043 prints the aid diff and the entry diff, and the class changes only through entries |
| stale E0701/E0702 rows, "classified other than `pure`", `--confirm` output, class names | rows updated; GO-044.2 says "by the aid"; `--confirm` prints old and new class and every changed module version; GO-040 gets `Stderr` and a mapping of class names to capabilities |

## Twelfth-pass review (blocker N-1; non-blocking points)

**Executive Summary.** Item 5 fired only for "a Go type with methods" or a function value that was itself the argument, so
types without methods, Égide composites, generics, function values inside composites and opaque types slipped through
(*verified* by the reviewer on Go 1.24.7 for `[]Evil`, `map[string]Evil`, `[1]*Evil`, `Outer{E Evil}`, a channel receive
and `reflect.ValueOf(Evil{})`; *reasoned* for the rest). The item now walks the type closure whatever the type's own
methods.

| Required fix | Resolution |
|--------------|------------|
| 1. walk the §11.3-mapped type closure regardless of methods | item 5(a): slices, maps, arrays, channels, pointers, structs with or without methods, and the Égide composites through each component's Go mapping |
| 2. per instantiation of an Égide generic; an uninstantiated type parameter is `go` | item 5(e) |
| 3. any Go function value or method value that is not a direct callee counts where it appears, in Égide source too | item 5(c): field, `List`, `Map`, `Chan`, spawned function, stored value |
| 4. opaque types are `go` | item 5(d): `reflect.Value`, `unsafe.Pointer`, `atomic.Value`, `sync.Map`, closures ending in `any` or a type parameter |
| 5. "static type" is the argument expression's type; variadics element by element | item 5: `fmt.Printf("%d", n)` stays `stdout`; a real `GoAny` is `go` (accepted fail-closed cost) |
| 6. (b) only for Go interface-typed expressions | item 5(b): the writer Égide passes is an Égide nominal type, so the rule does not fire; `GoError` and `errors.Is` cost stated |
| 7. GO-044 intro agrees with item 1 on transitive modules | the intro and the key sentence now say "a non-standard module of the Go closure of the `[go]` section" |

Non-blocking, handled: an aggregate cap (512 modules, 8192 packages, 16 tuples, 1024 overrides per package; E0712);
`reflect.* pure` removed from the seed list and left to T-0040; the digest against signed intermediate manifests is
`tasks/blocked/Q-0055-go-override-digest-versus-signed-intermediate-manifests.md` (recommended answer A: check at the root).
Alternative considered for fix 1: restrict item 5 to Go-declared types and forbid Égide composites in Go calls. Rejected,
it would make `fmt.Println(list)` impossible, while the closure walk keeps it `stdout` when the elements are plain.
The caps are *extrapolated* defaults. Acceptance cases for the `security-reviewer` after acceptance (not added here):
`Outer{E Evil}`, `[]Evil`, `List[GoRef[Evil]]`, a generic wrapper, `net.Dialer{Control: f}`, `reflect.Value`, each expected `go`.

## Thirteenth-pass review (blocker B-1, reasoned by the reviewer; N-1 closed)

**Executive Summary.** Item 5 classified only the arguments of a call. A reviewed `pure` constructor returns a
`GoRef[Evil]`; Égide builds `http.Client(Transport: ref)`, a construction and not a call; `c.Do(req)` then runs
`Evil.RoundTrip` at class `net` with no `go`. The receiver is argument 0 and a Go value built in Égide is classified where
it is built.

| Point | Resolution |
|-------|------------|
| B-1.1 receiver | item 5(f): the receiver of a method call is argument 0, classified by the type closure of its expression's static type |
| B-1.2 construction | item 5(g): a Go value built in Égide source is classified at the place it is built, by the type closure of its components and the function values among them; the class belongs to the enclosing function |
| B-1.3 acceptance case | **`Client(Transport: ref)` used as a receiver (`c.Do(req)`), with `ref` a `GoRef` of an unreviewed third-party type whose `RoundTrip` calls `os.Remove`, must be classified `go`.** Expected by 5(f) (the closure of `http.Client` reaches its `Transport` implementers) and by 5(g) (the literal itself). For the `security-reviewer` after acceptance; no test is added here |
| N-2 one definition of the implementer set | item 4 defines the implementer set once (the Go closure, plus standard implementers at list classes); 5(b) refers to it |
| N-3 closed list incomplete | 5(a) adds `Result`, enums, `Array`, `Shared`; a type with no Go mapping (`dyn Trait`, capability, resource) passed as an argument is E0713 |
| N-4 direct callee | 5(c) defines it: function name, method selector or instantiated generic in call position; method values, method expressions `T.M` and stored instantiations are function values |
| N-5 total cap | at most 8192 overrides per build as well as 1024 per package (E0712) |
| type closure is a set | stated in item 4: a set indexed by type identity |

Alternative considered for B-1.2: classify only at calls, and make every method of a type reachable from a value that
could reach a call `go`. Rejected, it needs the call-graph analysis that this ADR demoted. The cost of 5(g) is that
building a value with an unreviewed implementer is `go` even when no call follows (*extrapolated*, fail-closed).

## Fourteenth-pass review (blocker B-2, Go behaviour verified by the reviewer on Go 1.24.7)

**Executive Summary.** `json.Marshal([]Evil{…})` and `json.Marshal(&Outer{E: Evil{}})` call the pointer-receiver
`(*Evil).MarshalJSON` and `(*Evil).String`, but the type walk counted the value method set of each type reached (and both
sets only for implementers). A type with pointer-only methods in a `List[Evil]` left `json.Marshal` at class `pure`.

| Point | Resolution |
|-------|------------|
| B-2.1 both method sets for every type reached | item 5(a): the methods of `T` and `*T` count for every type of the closure walk |
| B-2.2 the same in (g) | item 5(g): the constructed type is classified with both sets |
| B-2.3 acceptance case | **`json.Marshal(List[Evil])`, where `Evil` is an unreviewed third-party type that has only pointer-receiver `MarshalJSON` and `String` methods and whose methods call `os.Remove`, must be classified `go`.** For the `security-reviewer` after acceptance; no test is added here |
| top-level `let`, `comptime` argument, default value | no Go value can be built there: CT-006 makes it E0611 (and E0610 where CT-002 applies); 5(g) says so, so it never classifies those expressions |
| generic Go implementers | they count once per instantiation the program uses (5(b) and item 4) |

Alternative considered: count the pointer set only for addressable values. Rejected, `json.Marshal` and `fmt` take the
address themselves, so addressability of the source expression is not the criterion (*established* by the reviewer's
reproduction). Cost: a type with pointer-only methods is as visible as one with value methods, nothing more.

## Decision

Apply the spec diff: GO-042 rewritten (baseline, review aid, item 5), GO-044 items 1, 2 and 5 amended (capability
classes, residual rule for them, the closure's module versions and hashes in the digest, entries for transitive modules), GO-025, GOP-007, GOP-008, the A.3 reclassifications,
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
