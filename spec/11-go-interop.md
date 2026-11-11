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
  declared in the `[go]` section of the manifest (PKG-040). The path is a string consumed by tools (SYN-018, E0115).
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
  `[go.overrides] "<import path>.Func" = { class = "pure", reason = "…" }`. Like `@go_threadsafe` (GO-032) it asserts
  a property the compiler cannot check, and is gated like it:
  1. only `class = "pure"` exists; the key MUST name a function of a Go module declared in the `[go]` section of the
     same package. A standard-library function or a function of another package's module is E0423 (the standard library
     is classified by the reviewed list, GO-041);
  2. `reason` is a string consumed by tools (SYN-018, E0118);
  3. every package that transitively contains the override MUST list `"go_override:<import path>.<Func>"` in its
     `allow` entries (PKG-030, PKG-031), otherwise the build fails (E0422). The entry names the function, not the module,
     so the root reviews exactly what it permits;
  4. the override changes the classification only for calls made by the declaring package, including the call-graph
     analysis (GO-042) computed for them; it never applies to dependent packages. Calls through the declaring
     package's `pub` API are visible to dependents only through item 3;
  5. `egide audit` lists every override with its reason, and `egide.lock` records it (PKG-040);
  6. an overridden function is still never run at compile time (CT-006).
- **[GO-045] Package initialisation.** Go runs the `init` functions and package-level variable initialisers of every Go
  package linked into the program (the transitive closure of the packages named by `import go`, without the packages the
  Égide runtime itself links) before `main`, with ambient authority and before any capability value exists. They are
  therefore classified like functions: the **init set** of a package is its `init` functions and its variable
  initialisers. For the standard library the purity list (GO-041) holds one line `<import path>.init <class>` per
  package; a package without that line is impure (`.*` does not cover `init`). For a third-party package the init set is
  an additional root of the analysis of GO-042. If the init set of any package in the closure is not pure, importing it
  counts as impure Go code of the module that contains that package (`std` for the standard library) and the module MUST
  be listed as `go:<module>` in `allow` (PKG-030), otherwise E0424. Drift detection (GO-043) covers init sets, and
  `egide audit` lists them. No capability can mediate an initialiser; the OS sandbox (GO-013) is the barrier.

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
