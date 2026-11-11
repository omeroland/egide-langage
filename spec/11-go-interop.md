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
  during compilation or at load time outside what GO-042 classifies (INT-005, PKG-042). The **user-package
  closure** is the Go packages of the modules of `[go]` and the non-standard packages they import; the standard library
  belongs to the pinned toolchain and is classified by the reviewed list (GO-041), not by file analysis.
  1. *cgo and its equivalents.* The closure is analysed and built with `CGO_ENABLED=0`. The compiler scans every package of
     the user-package closure and reports E0706 for: a file of the kinds `.c .cc .cpp .cxx .m .mm .h .S .swig .swigcxx
     .syso` (Go assembly `.s` is allowed and impure, GO-042.2), whether or not the tuple compiles it, because Go drops a
     stray C source silently when cgo is off and fails when it is on; a package that needs cgo to build; and any
     `//go:cgo_*` or `//go:wasmimport` directive in a Go file (`//go:cgo_import_dynamic` is accepted by the Go compiler
     in an ordinary file under `CGO_ENABLED=0` and makes the binary load a shared library before `main`). On the Go
     backend a Go file that imports `"C"` and is excluded by the tuple, with a pure-Go fallback, is never compiled and is not
     an error. As defence in depth the compiler checks the produced binary: it MUST be statically linked (no dynamic
     interpreter, no dynamic-library dependency outside a per-operating-system allow-list), otherwise the build fails
     (E0710).
     *Native backend (GO-003).* The `c-archive` build needs cgo to export symbols, and `//export` works only in a file that
     imports `"C"`. The glue is therefore split into two packages. The **template package** is fixed: its bytes (the only
     file that imports `"C"`, with the preamble) are embedded in the compiler and checked against their hash, and it exports
     only fixed symbols (for example one dispatcher `egide_call(id, buf, len)`). The **program package** holds everything
     derived from the program; it does not import `"C"`, contains no comment produced from program data, and is reached by
     the template only through a fixed interface. Every identifier in it carries a fixed prefix (`egide_`) and is checked
     against Go keywords, predeclared identifiers and the prefixes `_C` and `_cgo`, so that it can neither redefine `error`,
     `nil`, `len` or `true` for the template nor collide with generated code. The hash subject is the template, the
     interface and this mangling rule. With `CGO_ENABLED=1` the compiler compares every list that the Go tool reports for
     each package of the user-package closure (Go, cgo, ignored Go, C-family, assembly, `.syso` and the rest) with the lists at
     `CGO_ENABLED=0`, and requires the cgo list to be empty: a package with an `import "C"` file in it is E0706 even though
     its list of plain Go files is the same in both modes. The pure-Go-fallback exemption does not exist on the native
     backend. The standard library is exempt (with cgo on, `net` and `os/user` select cgo files of the pinned toolchain,
     which the list classifies per tuple). The C compiler and linker then run, so `CC`, `CXX`, `CGO_CFLAGS`, `CGO_CXXFLAGS`,
     `CGO_LDFLAGS` and `PKG_CONFIG` are set by the compiler to a pinned compiler (absolute path), fixed flags and a disabled
     `pkg-config`, and the `PATH` holds only the pinned toolchain directories. The lock records the identity of the C toolchain
     as the hash of its whole tree (the compiler driver executes `cc1`, `as` and the linker, and reads headers and runtime
     objects). The C toolchain is part of the trusted computing base. Phase 7 (T-0100) confirms this mechanism or replaces it
     with a separate process;
  2. *Toolchain.* `GOTOOLCHAIN=local`: the pinned toolchain is the only one that runs and none is downloaded. The compiler
     extracts the verified distribution into its own read-only directory and, before **every** `go` start, recomputes the hash
     of the installed `GOROOT` tree and compares it with the lock. The tree hash is canonical: sorted relative names, file
     modes, symlink targets and contents, and no extra file. The lock holds the version, the hash of the archive and the hash
     of the tree. The source of truth for the first archive hash (the Go checksum database, or the signed hashes published
     by the Go project) and the pinning policy are Q-0042;
  3. *Environment and command line.* Every `go` process is started by the compiler with an explicit environment, and every
     variable not listed here is removed: the pinned `GOROOT`; a private `HOME`, `TMPDIR` and `GOTMPDIR`; a **fresh, empty
     `GOCACHE` for each build** (Go trusts its entries, so a shared cache could make the compiled bytes differ from the
     analysed ones; the cost is that the standard library is recompiled for each build, and a compiler-owned cache that the
     compiler keys and re-verifies may replace it); `GOMODCACHE` set to the snapshot of item 4; a `PATH` of the pinned
     toolchain directories that contains no `git`, `hg`, `svn` or `bzr` (`go build` runs `git status` and `git log` when
     `-buildvcs=auto`, and git honours the configuration of the repository it is run in). `GOENV=off`, `GOFLAGS`
     overwritten, `GOWORK=off`, `GOTOOLCHAIN=local`; `GOPROXY` a fixed proxy of the compiler's trust root (Q-0041) or `off`;
     `GOVCS=*:off`; `GOSUMDB` on with its default; `GOAUTH`, `GOCACHEPROG`, `GODEBUG`, `GOPATH`, `GOBIN`, `GOFIPS140`,
     `GONOSUMDB`, `GOPRIVATE` and `GOINSECURE` are unset. The whole command line is generated by the compiler from a fixed
     allow-list: `-buildvcs=false`, `-trimpath`, `-mod=readonly` and the tuple. No flag from the user or from `egide.toml`
     reaches it, which closes `-toolexec`, `-overlay`, `-ldflags`, `-gcflags`, `-asmflags`, `-compiler`, `-modfile`, `-pkgdir`
     and `-pgo`;
  4. *Verified bytes.* Go checks `go.sum` when it downloads a module, not each time it reads an extracted cache, and a hash
     checked before a build can be stale when `go` reads the files. The compiler therefore builds an **immutable snapshot**: it
     copies each module into a compiler-owned tree while hashing it, compares the hash with the `go.sum` lines of the lock
     (PKG-041), and runs both the analysis and the build against that snapshot. Read-only permissions do not bind the owning
     user, so the compiler uses a separate user, a read-only bind mount or a private mount namespace where the operating
     system offers one, and in every case re-hashes the snapshot and the `GOROOT` tree after the build and before it accepts
     any artefact, failing the build on a difference. The bytes analysed, compiled and locked are the same. Trees produced
     by `egide vendor` (PKG-052) are verified the same way;
  5. *Module graph.* The main module of the Go build is generated by the compiler from the `[go]` sections and the lock.
     Go already ignores `vendor/`, `replace`, `exclude` and `toolchain` directives of dependencies; the live vectors are the
     main module's `vendor/` and `-mod`, `go.work` and `egide vendor` trees, which items 3 and 4 close;
  6. *Build tuple.* File selection depends on more than `GOOS` and `GOARCH`. The tuple is the explicit value (never "unset")
     of: `GOOS`, `GOARCH`, the architecture level that applies (`GOAMD64`, `GOARM`, `GOARM64`, `GO386`, `GOMIPS`,
     `GOMIPS64`, `GOPPC64`, `GORISCV64`, `GOWASM`), `GOEXPERIMENT`, `CGO_ENABLED`, the Go release tags (the toolchain
     version), and every build tag including `-tags` and the tags that flags set; `--cover` and `--fuzz` of `egide build` and
     `egide test` change the tuple. The build modes `-race`, `-msan`, `-asan`, `-buildmode=c-shared` and `plugin` require cgo
     and are unavailable on the Go backend: E0708. The lock records the classification per (tuple, Go package, function)
     (PKG-043). A build under a tuple that has no classification in the lock is E0707 until `egide lock --target` has analysed
     it and the drift check (GO-043) has passed, so cross-compiling needs `egide lock --target` for each target.

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
  2. `unsafe`, cgo, `//go:linkname`, assembly, `reflect` calls that can reach unexported state, a function without a Go
     body and any `//go:wasmimport` classify as impure;
  3. writing an exported package-level variable classifies as impure;
  4. a function value that is passed as an argument, stored in a package-level variable or in a field, or started with
     `go` or `defer`, counts as called by the function that does it (so a callback registered with `image.RegisterFormat`
     or `sql.Register` is classified through the registering function, and this applies to the roots of GO-045).
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

- **[GO-045] Package initialisation.** Go runs the `init` functions and package-level variable initialisers of every Go
  package linked into the program (the transitive import closure of the packages named by `import go`) before `main`,
  with ambient authority and before any capability value exists. Blank imports (`import _ "net/http/pprof"`) run them
  without any call, so GO-010 to GO-012 never apply. The **init set** of a package is its `init` functions and its
  variable initialisers; it is classified per package:
  1. *Standard library.* The init-class test applies to **every standard package in the closure**, including those reached
     only through a third-party package (a third party's `import _ "plugin"` is as much an error as an Égide
     `import go "plugin"`). The purity list (GO-041, appendix A.4) holds one line `<import path>.init <class>` per package;
     it covers the package's own initialisers and those of the standard packages it imports. A package without a line has
     the class `forbidden` if A.3 lists it as `forbidden`, otherwise `go`. Only `pure` is accepted: any other class is
     E0705, and no `allow` entry lifts it. The packages the Égide runtime links (A.5) are exempt;
  2. *Third-party modules.* The init set is an additional root of the analysis of GO-042. A package whose init set is
     impure requires `"go_init:<module>"` in `allow` (E0704), a key distinct from `go:<module>` so that approving the calls
     of a module does not approve initialisers it gains later. The entry grants the **set of capability classes** the
     init set has when it is recorded, and that grant holds wherever the callbacks the init set registers are reachable,
     including through dispatchers the list classifies pure (`image.Decode`, `crypto.Hash.New`, `sql.Open` with a registered
     driver), not only at start-up; `egide audit` prints the registered callbacks. A package whose init set is `forbidden` (it imports, by name
     or blank, a standard package of class `forbidden` such as `net/http/pprof` or `expvar`) is E0705;
  3. cgo, `.syso` objects, `//go:cgo_*` directives and any file the build does not compile are not part of the init set
     **because GO-046 rejects them (E0706) and requires a static binary (E0710)**; GO-045 is sound only together with
     GO-046 and MUST NOT be applied without it;
  4. drift detection (GO-043), the lock (PKG-043) and `egide audit` cover init sets. Drift compares the **capability set**,
     not "impure": a module approved for `env` whose update adds `net` fails the build (E0704) until `go_init:<module>` is
     confirmed again by `egide lock`. No capability can mediate an
     initialiser; the OS sandbox (GO-013) is the only barrier left after these gates.

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
