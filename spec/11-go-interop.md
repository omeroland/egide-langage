# 11. Go interoperability

Égide calls any Go package directly and Go can call Égide, without going through C (ADR-0008). This works because
the Go backend compiles to the same runtime: an Égide task is a goroutine and a `Chan[T]` is a `chan T`.
**The Go backend is therefore permanent**, not a stepping stone.

## 11.1 Importing Go

```egide decls
import go "k8s.io/client-go/kubernetes" as kube
import go "k8s.io/client-go/rest" as rest
import go "k8s.io/apimachinery/pkg/apis/meta/v1" as metav1
import go "strings" as strings

fn client() -> Result[kube.Clientset, GoError] using go: Go:
    let cfg = rest.InClusterConfig()?
    kube.NewForConfig(cfg)

fn tenant_namespaces(cs: kube.Clientset) -> Result[List[str], GoError] using go: Go:
    let list = cs.CoreV1().Namespaces().List(metav1.ListOptions(LabelSelector: "tenant"))?
    Ok([strings.ToLower(ns.Name) for ns in list.Items])
```

- **[GO-001]** `import go "<import path>" as alias` imports a Go package. The alias is mandatory. The Go module MUST be
  declared in the `[go]` section of the manifest (10.2). A `[go]` key is a Go module path whose first element contains a
  dot, so a key `os` or `std` cannot make a standard package look third-party. The path is a string consumed by tools (SYN-018, E0115).
- **[GO-002]** Exported Go identifiers keep their Go spelling (`NewForConfig`); LEX-023 naming warnings do not apply
  to them.
- **[GO-003]** Go interop is available with the Go backend. With the native backend, Go packages are linked through
  Go's `c-archive` mode, at the cost of two runtimes in one process and cgo call overhead; the compiler emits a warning.

## 11.2 The security boundary

Go code has ambient authority: Égide cannot stop it from opening files or sockets. Égide makes this breach **visible in
types** and **auditable**.

- **[GO-010]** Calling a Go function classified **impure** (§11.4) requires the `Go` capability in scope:
  `using go: Go` (or an explicit `Go` argument). `Go` is obtained only from `sys.go` in `main`.
- **[GO-011]** Calling a Go function classified **pure** requires no capability.
- **[GO-012]** A Go function classified with a specific capability (e.g. `Clock` for `time.Now`) requires that
  capability instead of `Go`. The Égide wrapper passes nothing to Go: the requirement exists only to make the authority
  visible to the Égide type system.
- **[GO-013]** The OS sandbox (CAP-050) applies to the whole process, Go code included. It is the real barrier for
  Go code.

## 11.3 Type mapping

| Go | Égide | Boundary rule |
|----|-------|---------------|
| `bool`, `int`, `int8`…`int64`, `uint8`…`uint64`, `float32`, `float64` | `bool`, `int`, `i8`…`i64`, `u8`…`u64`, `f32`, `f64` | identical; Go `int` is 64-bit on supported targets |
| `uint`, `uintptr` | `u64` / not supported | `uintptr` requires `unsafe` |
| `string` | `str` | **[GO-020]** Go strings may be invalid UTF-8: conversion validates and returns `Result`; `.as_bytes()` gives `Bytes` without validation |
| `[]T`, `map[K]V` | `List[T]`, `Map[K, V]` | **[GO-021]** copied at the boundary in both directions; Go can never mutate an Égide value |
| `[N]T` | `Array[T, N]` | copied |
| exported `struct` | imported nominal type | exported fields accessible; constructed with named arguments |
| `*T` | `GoRef[T]?` | `nil` becomes `None`; see GO-032 |
| `(T, error)`, `error` | `Result[T, GoError]`, `Result[(), GoError]` | automatic; `?` works |
| `(T, bool)` "comma ok" | `T?` | when the Go doc convention applies (map lookups, type assertions) |
| interface types | `dyn` Go interface | type switches become `match` on `go.type_of(x)` |
| `any` | `GoAny` | extraction by typed `match` |
| `chan T` | `Chan[T]` | same object, no copy |
| `func(A) B` | `fn(A) -> B using Go` | Égide lambdas passed to Go run with the capabilities they captured |
| `context.Context` first parameter | injected | **[GO-022]** the current task's cancellation and deadline (CON-011) |
| variadic `...T` | trailing `List[T]` or spread `*xs` | — |
| `panic` | Égide panic | **[GO-024]** `go.recover(() => …)` converts it into `Result[T, GoPanic]` |

- **[GO-030]** Go functions returning `(T, error)` MUST be treated as `Result` even when the Go documentation says the
  error "never happens".
- **[GO-031]** Go methods with pointer receivers are callable on `GoRef[T]`.
- **[GO-032]** `GoRef[T]` has reference semantics like `Shared[T]` and is not `Send`, unless the attribute
  `@go_threadsafe(reason: "…")` (SYN-023) is written on a `type` alias of exactly that Go type `T`, for example
  `@go_threadsafe(reason: "documented as safe for concurrent use")` above `type Clientset = kube.Clientset`. The
  attribute asserts a property the compiler cannot check, as `unsafe` does, and is gated like it:
  1. it may appear only in a package that itself runs `import go` of the Go module of `T` (E0420), so it cannot reach
     the types of another dependency;
  2. the assertion is **program-wide** (an alias is the same type), it applies to `GoRef[T]` for exactly that `T`;
  3. every package that transitively contains it MUST list `"go_threadsafe:<go module>"` in its `allow` entries
     (PKG-030, PKG-031), otherwise the build fails (E0421);
  4. `egide audit` lists every such attribute with its reason.
  There is no "bridge module": the term is not used by this specification.

## 11.4 Purity classification of Go functions

- **[GO-040]** Every Go function callable from Égide is classified as **pure**, **requires C** for a capability `C`
  (`Clock`, `Rand`, `Stdout`, `Stdin`, `Dir`, `Env`, `Proc`, `Net`, `Log`) or **impure** (requires `Go`).
- **[GO-041] Standard library.** Functions of the Go standard library are classified by the official, versioned
  **Go purity list** ([appendix](appendix/go-purity-list.md)), one file per Go minor version, reviewed by humans.
  A standard-library function absent from the list is **impure**.
- **[GO-042] Third-party modules.** Functions of modules declared in `[go]` are classified by static call-graph
  analysis (in the spirit of Google's capslock): a function's classification is the union of the classifications of
  everything it may call, bottoming out at standard-library functions classified by GO-041. The analysis is
  conservative:
  1. a call through an interface value or a function value may call anything, unless the value comes from Égide;
  2. `unsafe`, cgo, `//go:linkname`, assembly and `reflect` calls that can reach unexported state classify as impure;
  3. writing an exported package-level variable classifies as impure.
  The result is recorded per function in `egide.lock` (PKG-040).
- **[GO-043] Drift detection.** When a new version of a Go module changes the classification of a function called by
  the Égide program, `egide lock` fails and prints the per-function capability diff.
- **[GO-044] Overrides.** A package may declare a false positive pure with
  `[go.overrides] "<import path>.Func" = { class = "pure", reason = "…" }` (a method is keyed
  `"<import path>.<Type>.<Method>"`; the import path is the longest prefix that is a package of a module of `[go]`, and an
  ambiguous key is E0702). Like `@go_threadsafe` (GO-032) an override asserts a property the compiler cannot check, and is
  gated like it:
  1. only `class = "pure"` exists. The key MUST resolve to an exported function or method **declared** in a package of a
     module that is exactly a module of the `[go]` section of the same package, and the function MUST have a Go body.
     Ownership is decided by the package that declares the resolved object (the Go type checker's `Func.Pkg()` after alias
     resolution, `Func.Origin()` for a generic function), not by the package named in the key and not by string prefix. A
     key that resolves to a method promoted through an embedded field, to a method or function of a type alias of a foreign
     type, to a package-level variable of function type, to a method of an interface type (also one promoted from an
     embedded local interface or reached through a type parameter), to a function without a Go body, to the standard
     library, to a nested or other module, or to `init` or a variable initialiser, is E0702;
  2. **what an override discharges.** It discharges only findings of GO-042 item 1 (a call through a function or interface
     value) and item 3 (a write to an exported package-level variable) in the call graph reachable from the function, and only
     as follows. *Item 1:* before a finding is discharged, the possible targets of the call are resolved inside the
     user-package closure (class-hierarchy or variable-type analysis), and the classes of the resolved targets enter the
     residual; a call through a value whose target is statically known (`w := os.Stdout.Write; w(p)`), through a
     package-level function variable (`hook(p)`) or through an interface with implementations in the closure is therefore
     not discharged. Only a call whose target set is unbounded because it depends on a value supplied by the Égide caller
     (a parameter) is discharged. *Item 3:* only writes to exported variables **declared in the overridden function's own
     module**; a write to a variable of any other package, the standard library included, is residual. The **residual** is
     everything else GO-042 finds below the function: every item 2 finding (`unsafe`, cgo, assembly, `reflect`, a body-less
     function, `go:linkname`), every resolved target of item 1 and every call to a function classified other than `pure`
     (`os.WriteFile` is `Dir`); a callee that is classified `Go` only because of a discharged item 1 finding does not count.
     The residual MUST be empty, otherwise E0702, which prints it. **`--confirm` can never lift E0702**;
  3. **the override applies only to the edge from Égide source of the declaring Égide package to that exact function.**
     Inside the Go call graph the function keeps the class computed by GO-042, so Go callers of it, and Go functions that
     reach it, are classified as if there were no override. An override is never a pure leaf of the analysis;
  4. `reason` is a string consumed by tools. It is a TOML string, which the Égide lexer never sees, so the manifest
     reader applies the constraints of SYN-018 itself (single line, 1 to 200 scalar values, no LEX-003 character, no
     `Zs` other than U+0020; E0118), and every tool that prints it (audit, lock, SBOM) passes it through the output
     escaping of LEX-006;
  5. **the grant names what it grants.** The identity of a discharged finding is (enclosing function, kind, the callee's
     static type or the variable object as package path and name, multiplicity), with no source position, so that a
     refactor does not change it and a second write of the same kind to another variable does. Every package that
     transitively contains the override MUST list `"go_override:<import path>.<Func>=<digest>"` in the `allow` entries of the
     dependency edge (PKG-030, PKG-031, PKG-032), where `<digest>` is the SHA-256 of the canonical map from every locked
     build tuple to its set of discharged findings (so `x_windows.go` against `x_linux.go` is covered, and `egide lock
     --target` for a new tuple changes the digest). A missing entry, or a digest that differs from the computed one, fails the
     build (E0701). `egide audit` and `egide lock --confirm` print the sets in full;
  6. **confirmation is a manifest edit.** `egide lock` and `egide update` never modify `allow`. When a dependency update
     changes the discharged sets, the build fails (E0701) until a person runs `egide lock --confirm
     go_override:<import path>.<Func>=<old digest>`, which names the function and the digest it replaces (so a stale script
     cannot confirm a changed set), rewrites that one entry and prints the difference, so the change appears as a manifest
     diff in review. `--confirm` refuses to run without both. It does not apply to E0702. The checks of items 1 and 2 and the
     digest are evaluated for every locked build tuple;
  7. `egide audit` lists every override with its reason and its discharged sets, and `egide run` of a script prints the
     `allow` entries the script declares for itself (TOOL-011); `egide.lock` records them (PKG-040).

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
