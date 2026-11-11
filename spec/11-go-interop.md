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
  The cgo this needs is confined to one compiler-generated package (GO-046.1).

- **[GO-046] Go build environment.** Type information, classification (GO-042) and the final build of the Go closure (the
  Go packages named by `import go` and everything they import) follow these rules, so that no code of a dependency runs
  during compilation (INT-005, PKG-042). The **user-package closure** is the Go packages of the modules of `[go]` and the
  non-standard packages they import; the standard library belongs to the pinned toolchain and is classified by the
  reviewed list (GO-041), not by file analysis.
  1. *cgo.* The closure is analysed and built with `CGO_ENABLED=0`. The compiler scans the directory of every package of the
     user-package closure for files of the kinds `.c .cc .cpp .cxx .m .mm .h .S .swig .swigcxx .syso` (Go assembly `.s` is
     allowed and classified impure, GO-042.2) and compares them with the set the build compiles: any such file is E0706,
     whether or not the tuple compiles it, because Go drops a stray C source silently when cgo is off and fails when it is
     on. A package that needs cgo to build (no Go file is selectable without it) is also E0706. A Go file that imports `"C"`
     and is excluded by the tuple, with a pure-Go fallback, is never compiled and is not an error.
     *Native backend (GO-003).* The `c-archive` build needs cgo for the export glue. The glue package has one fixed template
     file that holds `import "C"` and the preamble, whose bytes are embedded in the compiler and checked against their hash
     (the hash subject is the template, not the per-program output), and per-program files in the same package without
     `import "C"`. Every program-derived string written into any glue file is an ASCII identifier of the Égide grammar
     (ADR-0010), never a doc comment, tag or string literal. With `CGO_ENABLED=1` the user-package closure MUST select the
     same Go files as with `0` (otherwise E0706); the standard library is exempt, since with cgo on `net` and `os/user`
     select cgo files of the pinned toolchain, which the list classifies per tuple (`CGO_ENABLED` is a tuple member). The C
     compiler and linker then run, so `CC`, `CXX`, `CGO_CFLAGS`, `CGO_CXXFLAGS`, `CGO_LDFLAGS` and `PKG_CONFIG` are set by
     the compiler to a pinned compiler (absolute path), fixed flags and a disabled `pkg-config`, the `PATH` holds only the
     pinned toolchain directories, and the identity of the C toolchain (version and SHA-256 of the compiler and linker
     binaries) is recorded in the lock (PKG-043). The C toolchain is part of the trusted computing base. Phase 7 (T-0100)
     confirms this mechanism or replaces it with a separate process;
  2. *Toolchain.* `GOTOOLCHAIN=local`: the pinned toolchain is the only one that runs and none is downloaded. The compiler
     extracts the verified distribution into its own read-only directory and, before **every** `go` start, recomputes the hash
     of the installed `GOROOT` tree and compares it with the lock. The lock holds the version, the hash of the archive and the
     hash of the tree (PKG-043). The pinning policy is Q-0042;
  3. *Environment.* Every `go` process is started by the compiler with an explicit environment, and every variable not
     listed here is removed: the pinned `GOROOT`; a private `HOME`, `TMPDIR` and `GOTMPDIR`; a **fresh, empty `GOCACHE` for each
     build** (Go trusts its entries, so a shared cache could make the compiled bytes differ from the analysed ones);
     `GOMODCACHE` set to the snapshot of item 4; a minimal `PATH`. `GOENV=off`, `GOFLAGS` overwritten with `-mod=readonly`,
     `GOWORK=off`, `GOTOOLCHAIN=local`; `GOPROXY` a fixed proxy of the compiler's trust root (Q-0041) or `off`; `GOVCS=*:off`;
     `GOSUMDB` on with its default. `GOAUTH`, `GOCACHEPROG`, `GODEBUG`, `GOPATH`, `GOBIN`, `GOFIPS140`, `GONOSUMDB`,
     `GOPRIVATE` and `GOINSECURE` are unset. No `-toolexec`, no `-overlay`;
  4. *Verified bytes.* Go checks `go.sum` when it downloads a module, not each time it reads an extracted cache, and a hash
     checked before a build can be stale when `go` reads the files. The compiler therefore builds an **immutable snapshot**: it
     copies each module into a compiler-owned tree while hashing it, compares the hash with the `go.sum` lines of the lock
     (PKG-041), makes the tree read-only (and, where the operating system allows, unreachable for writing by other
     processes of the same user), and runs both the analysis and the build against that snapshot. The bytes analysed,
     compiled and locked are the same. Trees produced by `egide vendor` (PKG-052) are verified the same way;
  5. *Module graph.* The main module of the Go build is generated by the compiler from the `[go]` sections and the lock.
     Go already ignores `vendor/`, `replace`, `exclude` and `toolchain` directives of dependencies; the live vectors are the
     main module's `vendor/` and `-mod`, `go.work` and `egide vendor` trees, which items 3 and 4 close;
  6. *Build tuple.* File selection depends on more than `GOOS` and `GOARCH`. The tuple is the explicit value (never "unset")
     of: `GOOS`, `GOARCH`, the architecture level that applies (`GOAMD64`, `GOARM`, `GOARM64`, `GO386`, `GOMIPS`,
     `GOMIPS64`, `GOPPC64`, `GORISCV64`, `GOWASM`), `GOEXPERIMENT`, `CGO_ENABLED`, the Go release tags (the toolchain
     version), and every build tag including `-tags` and the tags that flags set; `--cover` and `--fuzz` of `egide build` and
     `egide test` change the tuple. The build modes `-race`, `-msan` and `-asan` require cgo and are unavailable on the Go
     backend: E0708. The lock records the classification per (tuple, package, function) (PKG-043). A build under a tuple that
     has no classification in the lock is E0707 until `egide lock --target` has analysed it and the drift check (GO-043) has
     passed, so cross-compiling needs `egide lock --target` for each target.

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
  2. **what an override discharges.** It discharges only the findings of GO-042 items 1 (a call through a function or
     interface value) and 3 (a write to an exported package-level variable) in the call graph reachable from the function. The
     **residual** is everything else that GO-042 finds below the function: every item 2 finding (`unsafe`, cgo, assembly,
     `reflect`, a body-less function, `go:linkname`) and every call to a function classified other than `pure`
     (`os.WriteFile` is `Dir`). The residual MUST be `pure`, that is empty; otherwise E0702, which prints it. So a wrapper
     around an assembly stub or around a classified standard function cannot be overridden, and a version of the function
     that starts to reach one is rejected, not masked;
  3. **the override applies only to the edge from Égide source of the declaring Égide package to that exact function.**
     Inside the Go call graph the function keeps the class computed by GO-042, so Go callers of it, and Go functions that
     reach it, are classified as if there were no override. An override is never a pure leaf of the analysis;
  4. `reason` is a string consumed by tools. It is a TOML string, which the Égide lexer never sees, so the manifest
     reader applies the constraints of SYN-018 itself (single line, 1 to 200 scalar values, no LEX-003 character, no
     `Zs` other than U+0020; E0118), and every tool that prints it (audit, lock, SBOM) passes it through the output
     escaping of LEX-006;
  5. **the grant names what it grants.** Every package that transitively contains the override MUST list
     `"go_override:<import path>.<Func>=<digest>"` in the `allow` entries of the dependency edge (PKG-030, PKG-031,
     PKG-032), where `<digest>` is the SHA-256 of the canonical set of discharged findings (function reached, finding kind,
     for each instantiation used by Égide source) as computed for each locked build tuple. A missing entry, or a digest that
     differs from the computed one, fails the build (E0701). The set is printed in full by `egide audit` and by the diff of
     `egide lock --confirm go_override:<import path>.<Func>`;
  6. **confirmation is a manifest edit.** `egide lock` and `egide update` never modify `allow`. When a dependency update
     changes the discharged set (a new dynamic call, a new instantiation) or makes the residual non-empty, the build fails
     until a person runs `egide lock --confirm` naming the function, which rewrites that one `allow` entry and prints the
     set difference, so the change appears as a manifest diff in review. `--confirm` refuses to run without naming the
     function, in any mode. The check of item 2 and the digest are evaluated for every locked build tuple, and
     `egide lock --target` re-checks them;
  7. `egide audit` lists every override with its reason and its discharged set; `egide.lock` records them (PKG-040).

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
