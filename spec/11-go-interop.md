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
  3. writing an exported package-level variable classifies as impure;
  4. a function value that is passed as an argument, stored in a package-level variable or in a field, or started with
     `go` or `defer`, counts as called by the function that does it (so a callback registered with `image.RegisterFormat`
     or `sql.Register` is classified through the registering function, and this applies to the roots of GO-045).
  The result is recorded per function in `egide.lock` (PKG-040).
- **[GO-043] Drift detection.** When a new version of a Go module changes the classification of a function called by
  the Égide program, `egide lock` fails and prints the per-function capability diff.
- **[GO-044] Overrides.** A package may declare a false positive pure with
  `[go.overrides] "<import path>.Func" = { class = "pure", reason = "…" }` (a method is keyed
  `"<import path>.<Type>.<Method>"`). Like `@go_threadsafe` (GO-032) it asserts a property the compiler cannot check, and
  is gated like it:
  1. only `class = "pure"` exists. The key MUST name an exported function or method of a package whose owning module
     (as reported by the Go tool, not by string prefix) is exactly a module declared in the `[go]` section of the same
     package. The standard library (reviewed list, GO-041), a nested or other module, `init` and variable initialisers
     (GO-045) cannot be overridden: E0423;
  2. **the override applies only to the edge from Égide source of the declaring package to that exact function.** Inside
     the Go call graph the function keeps the class computed by GO-042, so Go callers of it, and Go functions that reach it,
     are classified as if there were no override. An override is never a pure leaf of the analysis;
  3. `reason` is a string consumed by tools. It is a TOML string, which the Égide lexer never sees, so the manifest
     reader applies the constraints of SYN-018 itself (single line, 1 to 200 scalar values, no LEX-003 character, no
     `Zs` other than U+0020; E0118), and every tool that prints it (audit, lock, SBOM) passes it through the output
     escaping of LEX-006;
  4. every package that transitively contains the override MUST list `"go_override:<import path>.<Func>"` in the `allow`
     entries of the dependency edge (PKG-030, PKG-031, PKG-032), otherwise the build fails (E0422). The entry names the
     function whose class the root accepts to be wrong; by item 2 no other Go function changes class because of it;
  5. `egide audit` lists every override with its reason; `egide.lock` records it under the declaring package (PKG-040);
  6. an overridden function is still never run at compile time (CT-006).
- **[GO-045] Package initialisation.** Go runs the `init` functions and package-level variable initialisers of every Go
  package linked into the program (the transitive import closure of the packages named by `import go`) before `main`,
  with ambient authority and before any capability value exists. Blank imports (`import _ "net/http/pprof"`) run them
  without any call, so GO-010 to GO-012 never apply. Their **init set** is therefore classified, per package, as follows.
  1. *Standard library.* The purity list (GO-041, appendix A.4) holds one line `<import path>.init <class>` per package;
     it covers the package's own initialisers and those of the standard packages it imports. A package without a line
     has the class `forbidden` if A.3 lists it as `forbidden`, otherwise `go`. Only `pure` is accepted: importing a
     standard package whose init class is not `pure` is E0425, and no `allow` entry lifts it. The packages the Égide
     runtime links (A.5) are exempt.
  2. *Third-party modules.* The init set is an additional root of the analysis of GO-042. A package in the closure whose
     init set is impure requires `"go_init:<module>"` in `allow` (E0424); a separate key from `go:<module>`, so that
     approving calls of a module does not approve initialisers it gains later. A package whose init set is
     `forbidden` (for example any package that imports `net/http/pprof` or `expvar`, named or blank, outside the
     standard library) is E0425 and no entry lifts it.
  3. Cgo, `.syso` objects and any file the build does not compile are not part of the init set; GO-046 excludes them.
  4. Drift detection (GO-043), the lock (PKG-040) and `egide audit` cover init sets. No capability can mediate an
     initialiser; the OS sandbox (GO-013) is the only barrier left after these gates.
- **[GO-046] Go build environment.** Type information, classification (GO-042, GO-045) and the final build of the Go
  closure follow these rules, so that no code of a dependency runs during compilation (INT-005, PKG-042):
  1. cgo is disabled (`CGO_ENABLED=0`). A package of the closure that has cgo files (`import "C"`), C, C++, Objective-C
     or SWIG sources, or `.syso` objects, is E0426. (The glue the compiler generates for GO-003 is not part of the
     closure.) Assembly is allowed and classified impure (GO-042);
  2. the toolchain is the pinned local one (`GOTOOLCHAIN=local`; no toolchain download) and its version is recorded in
     the lock; `GOFLAGS`, `-toolexec` and every environment variable that changes the Go build come from the compiler and
     from nothing else (`-mod=readonly`, `GOWORK=off`);
  3. the main module of the Go build is generated by the compiler from the `[go]` sections and the lock. `vendor/`
     directories, `replace`, `exclude`, `go.work` and `toolchain` directives of dependencies are ignored; vendored trees
     produced by `egide vendor` (PKG-052) are re-verified against the lock hashes before use;
  4. the bytes analysed are the bytes compiled: both come from the module cache verified against the `go.sum` lines of
     the lock (PKG-041);
  5. classification depends on `GOOS`, `GOARCH` and build tags, so the lock records the tuple
     (`GOOS`, `GOARCH`, tags, `CGO_ENABLED`) with each classification (PKG-040). A build for a tuple that is not in the
     lock is E0427 until `egide lock --target` has analysed it and the drift check (GO-043) has passed.

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
