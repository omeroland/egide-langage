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
     the user-package closure and reports E0706 for: a file of any kind that the file tables of the `go/build` package of the pinned toolchain assign to C, C++, Objective-C,
     Fortran, SWIG, C-preprocessed assembly or system objects (the set is the toolchain's, not an enumeration here; it
     includes names that differ only by case) (Go assembly `.s` is allowed and impure, GO-042.2), whether or not the tuple
     compiles it, because Go drops a
     stray C source silently when cgo is off and fails when it is on; a package that needs cgo to build; and any
     `//go:cgo_*` or `//go:wasmimport` directive in a Go file (`//go:cgo_import_dynamic` is accepted by the Go compiler
     in an ordinary file under `CGO_ENABLED=0` and makes the binary load a shared library before `main`). The scan reads the
     comments of every Go file of the closure, **including files the tuple ignores**, at the token level (the lexical
     comments of `go/scanner`), at every position: the compiler honours the directive when it is indented, inside a function
     body, in a file with CRLF line ends and after a `//line` directive, so a scan of column 1 or of the header of the file
     is not enough. On the Go
     backend a Go file that imports `"C"` and is excluded by the tuple, with a pure-Go fallback, is never compiled and is not
     an error. As defence in depth the compiler checks the produced binary: it MUST be statically linked (no dynamic
     interpreter, no dynamic-library dependency outside a per-operating-system allow-list), otherwise the build fails
     (E0710), and this check runs before `egide run` or `egide test` executes the artefact.
     *Native backend (GO-003).* The `c-archive` build needs cgo to export symbols, and `//export` works only in a file that
     imports `"C"`. The glue is therefore split into two packages. The **template package** is fixed: its bytes (the only
     file that imports `"C"`, with the preamble) are embedded in the compiler and checked against their hash, and it exports
     only fixed symbols (for example one dispatcher `egide_call(id, buf, len)`). The **program package** holds everything
     derived from the program; it does not import `"C"`, contains no comment produced from program data, and is reached by
     the template only through **one exported entry point, `Egide_Dispatch`** (Go exports only names that start with an
     upper-case letter, so this name is the single exception to the prefix). Every other identifier in it is
     `egide_` followed by the **mangled name** of an Égide item: for each dot-separated segment of its qualified name, the
     length of the segment in decimal, `_`, and the segment itself, concatenated (`a_b.c` becomes `egide_3_a_b1_c`, `a.b_c`
     becomes `egide_1_a3_b_c`). The mangling is injective and reversible, since each length says where its segment ends, so two
     different items never collide and the compiler can recover the item from the name. After the prefix the identifier
     cannot be a Go keyword, a predeclared identifier or start with `_C` or `_cgo`, so it can neither redefine `error`, `nil`,
     `len` or `true` for the template nor collide with generated code. The dispatcher decodes its buffer only into the
     **closed list of decodable types**: `bool`, the fixed-width integers, `f32`, `f64`, `str`, `bytes`; `Option[T]`,
     `List[T]`, `Map[K, V]` and tuples of decodable types; structs and enums, all of whose fields are decodable and that
     do not implement `Drop`, **and every field of the struct is `pub`** (settable from outside the declaring module,
     PKG-003 read as applying to fields). A struct with a non-`pub` field is not decodable: the generated dispatcher is
     outside the module and builds the value field by field, so a private field would let it bypass the type's
     constructor. This is a decidable test on the declaration. The spec does not yet say whether PKG-003 governs fields
     or whether a field can be `pub` individually (chapters 4 and 10 are silent): this rule relies on that reading and
     the gap is flagged for a spec-question. A **validated type** (TYP-031) is
     decoded only through its constructor, so a buffer cannot produce a value that the type would refuse; the constructor's
     error is returned to the host. Nothing else is decodable: capability types, resource types, `Secret`, sink types,
     `std.unsafe.Ptr`, `GoRef`, `Shared`, `Chan`, function values, closures and trait objects cannot be built from bytes,
     so the dispatcher cannot forge authority, a reference or code for a sandboxed host. Length and depth are bounded by
     the limits of the host call (an oversized or too deep buffer is an error, never a partial value). The hash subject is the template, the interface and this mangling rule. With `CGO_ENABLED=1` the compiler compares every list that the Go tool reports for
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
  2. *Toolchain.* `GOTOOLCHAIN=local`: the pinned toolchain is the only one that runs and none is downloaded. *Assumption to verify in T-0100:* the official Go distribution archive contains only regular files and
     directories within the limits of item 4; if it does not, the limits or the entry kinds for that one archive are changed in an
     ADR, never relaxed silently. The compiler
     extracts the verified distribution into its own read-only directory and, before **every** `go` start, recomputes the hash
     of the installed `GOROOT` tree and compares it with the lock. The tree hash is canonical: sorted relative names, file
     modes, symlink targets and contents, and no extra file. The lock holds the version, the hash of the archive and the hash
     of the tree. The source of truth for the first archive hash (the Go checksum database, or the signed hashes published
     by the Go project) and the pinning policy are Q-0042;
  3. *Environment and command line.* Every `go` process is started by the compiler with an explicit environment, and every
     variable not listed here is removed: the pinned `GOROOT`; a private `HOME`, `TMPDIR` and `GOTMPDIR`; a **fresh, empty
     `GOCACHE` for each build** (Go trusts its entries, so a shared cache could make the compiled bytes differ from the
     analysed ones; the cost is that the standard library is recompiled for each build, and a compiler-owned cache that the
     compiler keys and re-verifies may replace it); `GOMODCACHE` an empty private directory (modules are not read from it, item 4); a `PATH` of the pinned
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
     copies each module into a compiler-owned tree while hashing it (the archive is treated as hostile, see below), compares the hash with the `go.sum` lines of the lock
     (PKG-041), and runs both the analysis and the build against that snapshot, through the layout that works without `go.sum` entries
     for extracted trees: the generated main module (item 5) names every module of the closure with a directory
     `replace` to its snapshot directory, for which Go does not consult `go.sum` (an extracted-only module cache fails with
     "missing go.sum entry"), so the compiler's own hash comparison is the only verification and cannot be skipped. Read-only permissions do not bind the owning
     user, so the compiler uses a separate user, a read-only bind mount or a private mount namespace where the operating
     system offers one, and in every case re-hashes the snapshot and the `GOROOT` tree after the build and before it accepts
     any artefact, failing the build on a difference. The bytes analysed, compiled and locked are the same. **Hostile archives.** Building the
     snapshot, and extracting any archive of a build (a Go module archive, an Égide package archive, PKG-041, and the
     toolchain distribution), accepts only regular files and directories, and is bounded.
     (a) *Entry kinds and names.* An entry is E0711 if it is a symbolic link, a hard link, a device, a FIFO, a sparse entry or
     any other non-regular file; if its path is absolute, contains a `..` or `.` segment, a NUL or other control
     character, invalid UTF-8, or a drive or UNC prefix; if it would resolve outside the destination (checked on the
     resolved path, after the parent directories exist); or if it breaks the **portable-name rules**, applied on every
     host so that the result does not depend on it: no backslash and no `:` in a name, no segment ending in a dot or a space,
     no segment that is a Windows device name (`CON`, `PRN`, `AUX`, `NUL`, `COM1` to `COM9`, `LPT1` to `LPT9`, the superscript forms `COM¹`, `COM²`, `COM³` and `LPT¹`, `LPT²`, `LPT³`, `CONIN$`, `CONOUT$`, with or
     without an extension, in any case) and no segment of the 8.3 short-name form (`NAME~1`); that Windows reserves exactly
     these names is recalled, not verified against Windows documentation, and is a conformance-test item. Two entries **collide** if their paths are equal after Unicode NFC normalisation
     and full case folding, and the dotted capital `İ` (U+0130) and dotless `ı` are folded by that same table, not by a
     host's simple lowercase mapping (that the simple mapping of `İ` differs is recalled, not verified), whatever the host file system does.
     (b) *Bounds, checked before the first write.* The compiler constants are, for a module or package archive: at most
     500 MiB uncompressed in total (the cap Go applies to module zips), 100 MiB per file, 100 000 entries, a path depth of
     32, 255 bytes per segment, 4096 bytes per path, and a compression ratio of at most 100 to 1 per entry; for the
     toolchain distribution: 2 GiB, 200 000 entries, the same depth and name limits. Sizes declared by the archive are
     checked first (zip central directory); the bytes actually produced are counted while extracting and the same limits
     apply to them, since a declared size can lie. A violation is E0711.
     (c) *Staging.* A streamed archive (tar) cannot be checked before it is read, so extraction goes to a private staging
     directory on the same file system, with exclusive creation and no following of existing links; only after every check
     and the hash comparison succeeded is the tree moved into place. On any failure the staging directory is deleted and
     nothing reaches the snapshot.
     (d) *Metadata.* Modes, owners, timestamps, extended attributes and ACLs of the archive are discarded: files get a fixed
     mode (0644, 0755 where the archive marks them executable), directories 0755, no setuid, setgid or sticky bit.
     Without this, a path-traversal entry writes outside the snapshot, and a link to a host
     file lets `//go:embed` copy that file into the artefact. Trees produced
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
     it and the drift check (GO-043) has passed, so cross-compiling needs `egide lock --target` for each target;
  7. *Diagnostic text derived from untrusted data.* Every string that a diagnostic of the override, initialiser and build-environment
     rules (E0701 to E0711) copies from data the user does not control (an archive entry name, a Go identifier, an import
     path, a file name, a module path, a build tag, a registered callback, and any text relayed from a `go`, `git` or C
     compiler child process) passes through the output escaping of LEX-006 in its **strict mode** (`ascii`). LEX-006 itself
     leaves printable non-ASCII text alone, because source text is legitimate Unicode; names from outside the
     user's control are different (a Go identifier may be non-ASCII, so a homoglyph can sit next to the ASCII name), so
     the strict mode writes every scalar value that is not printable ASCII as `\u{H…}` (canonical form: upper-case
     hexadecimal digits, no leading zeros, at least one digit, no prefix; two spellings of one scalar value never occur). Both are the same function with
     one switch, and the switch is on for every string listed here. (a) *Backslash and invalid UTF-8.* `\` is written `\\`
     (so a name that contains the characters `\u{E9}` never prints like `é`) and each byte of an invalid UTF-8 sequence
     (the E0711 case) is written `\x{HH}`. The escaping is applied **exactly once**, at the final rendering of a
     value. A message is built from typed fragments, `Text` (fixed template text, never escaped) and `Raw` (untrusted
     bytes, escaped when the message is rendered); the output of a child tool is `Raw` too: its bytes are never trusted
     to be escaped, whatever the tool did, and are escaped once by this compiler when the message is rendered, and a rendered string is not a fragment that can be rendered a second time (a second
     pass would turn each `\` into `\\` and make two different names print alike). (b) *Truncation is for humans only.* A diagnostic shown to a person may truncate a derived
     string to 120 characters followed by `…(N more)`. Output that carries identity (`egide.lock`, the SBOM, `egide audit`
     listings, `--confirm` and its difference) is never truncated, and neither are the machine fields below. Where a human
     line shortens such a value it also prints its length and the first 16 hexadecimal digits of the SHA-256 of the full
     escaped value. That digest is **display only**: it is never stored, compared, or used as an identity, and two values
     are the same only if their full bytes are equal. (c) *Machine formats.* The JSON, SARIF and LSP fields of diagnostics,
     CycloneDX and the lockfile use the **format's own escape syntax**, such that no raw code point of the LEX-006 set
     appears in the output bytes, and are not truncated. The lockfile, and the `allow` entries that `--confirm` writes into the manifest, are TOML, which has no `\u{…}`
     escape: a `"` is written `\"`, a backslash `\\`, a backspace, tab, line feed, form feed and carriage return with `\b`, `\t`, `\n`, `\f`, `\r`, every other control
     character and DEL with `\u00XX` (one spelling per value), and
     every other scalar value that is not printable ASCII `\uXXXX` (up to U+FFFF) or `\UXXXXXXXX`, with upper-case
     hexadecimal digits and the full width; surrogate code points do not exist in the input (they are not scalar
     values). The readers of the lock and of the manifest decode these escapes and reject a raw LEX-003 character, a raw
     control character and an escape that spells a LEX-003 character differently than above (E0118, as for `reason`).
     The dialect is **TOML 1.0.0**. A reader also rejects (E0118) any escape that is not the canonical spelling of its
     value: an escape of a printable ASCII character other than `\"` and `\\`, lower-case hexadecimal digits, the
     eight-digit form for a value up to U+FFFF, or a four-digit form where the short escape exists, so that two byte
     sequences never denote one identity and a lock diff is deterministic. In an **identity-bearing field** (a name, a
     key, an import path, an `allow` entry; not free text such as `reason`) the reader accepts only a basic string `"…"`
     with those canonical escapes: a TOML literal string `'…'`, the multi-line forms `'''…'''` and `"""…"""`, and a raw
     non-ASCII scalar are rejected (E0118), so `é` written raw and `\u00E9` cannot both denote one identity. The goal is
     one spelling per decoded value in these fields; free text keeps TOML's own rules and the checks of SYN-018. A BOM
     (U+FEFF, category Cf) and a carriage return (Cc) are already in the LEX-003 set and are rejected by it, so the
     reader has no separate rule for them. (Hand-written `allow` entries use the canonical spelling.)
     A name that is not valid UTF-8 never reaches the lock: archive entries fail with E0711 first, and Go identifiers
     and import paths are valid UTF-8 by the Go specification, so no separate byte-string key exists.

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
| `time.Time` | an Égide instant | **[GO-025]** a `time.Time` crossing into Égide is converted with `.UTC()` and loses its location: Égide time values carry no zone, so the process-wide `Local` zone (`$TZ`, `/etc/localtime`) never reaches Égide data; the other direction builds `time.Unix(s, ns).UTC()`. The Égide standard library offers UTC constructors only |
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
  (`Clock`, `Rand`, `Stdout`, `Stderr`, `Stdin`, `Dir`, `Env`, `Proc`, `Net`, `Log`) or **impure** (requires `Go`). The
  class names of the list and of overrides are, in this order, `clock`, `rand`, `stdout`, `stderr`, `stdin`, `fs`
  (capability `Dir`), `env`, `proc`, `net`, `log`.
- **[GO-041] Standard library.** Functions of the Go standard library are classified by the official, versioned
  **Go purity list** ([appendix](appendix/go-purity-list.md)), one file per Go minor version, reviewed by humans.
  A standard-library function absent from the list is **impure**.
- **[GO-042] Third-party modules.** *Baseline.* A function or method of any non-standard package of the Go closure (GO-046:
  the packages of the modules of `[go]` and every non-standard package they import, so transitive modules are included)
  is **impure**, class `go`, whatever its body. "Third-party" in this chapter means exactly this; the standard library is
  classified by GO-041. It leaves that class only through a **reviewed entry**, which is
  a Go override of GO-044 naming the function (and the module version, GO-044.5): the class of a third-party function that
  Égide calls is the class of its reviewed entry, and `go` when there is none. No analysis result changes a class.
  *Review aid.* The static call-graph analysis (in the spirit of Google's capslock) computes, for each function, the
  classification that a reviewer should consider: the union of the classifications of everything it may call, bottoming
  out at standard-library functions classified by GO-041. `egide audit`, `egide lock --confirm` and the override
  review print its findings. They are advice and the seed of a reviewed entry; they restrict only by failing closed: the
  residual rule of GO-044.2 refuses an entry, the caps of E0712 and E0713 refuse a build whose bookkeeping would grow
  without limit, and GO-043 reports a changed classification. None of them grants a class. An evasion of the analysis can therefore hide a finding
  from a reviewer but cannot grant a class, because the class of an unreviewed function is `go` regardless. The analysis
  is conservative:
  1. a call through an interface value or a function value may call anything, unless the value comes from Égide;
  2. `unsafe`, cgo, `//go:linkname`, assembly, `reflect` calls that can reach unexported state, a function without a Go
     body and any `//go:wasmimport` classify as impure;
  3. writing an exported package-level variable classifies as impure. **Every use** of an exported package-level variable
     of the standard library takes the class of its line in the list as refined by its type below (`io.ReadFull(rand.Reader, b)` uses
     `crypto/rand.Reader`, an interface, hence `go`), and a variable with no line is `go` (GOP-007). **Taking the
     address of such a variable (`&rand.Reader`, `&os.Args`) is a use and also counts as a write**, because the pointer
     allows both reads and writes that the analysis does not see; it is therefore impure. A method value, a slice of the
     variable and an implicit address-of (a call `v.M()` where `M` has a pointer receiver and `v` is the variable) count
     as uses, and the last also as a write. **Mutation through a copy or an alias is not visible to any syntactic rule**
     (`a := os.Args; a[0] = "x"`, `p := time.UTC; *p = *time.FixedZone(…)`, `unicode.Upper.R16 = nil`), so the class of
     a variable is decided by its **type**: a variable whose type is a pointer, slice, map, function, channel or interface,
     or a struct or array that contains one, is `go` on any use, whatever its line says, unless the line carries the
     annotation `immutable` (GOP-007), which the reviewer may add only after showing that nothing reachable from the value
     can be changed through any exported operation. A variable of value type that contains none of those (a boolean, a
     number, a string, and arrays and structs of them) takes the class of its line; assigning to it is a write. `io.EOF`
     is an `error` interface holding a pointer to a struct with unexported fields and no mutating method, and is
     `immutable`; `os.Args` (a slice), `crypto/rand.Reader` (an interface), `time.UTC` and `time.Local` (pointers to a
     mutable `Location`) and `unicode.Upper` (a pointer to a table whose slices are exported) are `go`;
  4. **any function value that is not the callee of a direct call counts as called at the expression where it appears**
     (`return map[string]any{"run": evil.Run}`, an argument, a stored value, a method value, a deferred or `go`
     function, a function placed in a composite), and so does a value converted to an interface type, **implicitly as
     well as explicitly** (assignment, argument passing, return, composite literal, channel send). It counts as called by
     the function that does it (so a callback registered with `image.RegisterFormat`
     or `sql.Register` is classified through the registering function).
     **A value converted to an interface type counts as calling every method of the method set of its dynamic type**
     (including methods promoted through embedded fields) in the function that converts it, whatever the interface type
     is and whatever the callee is, **and of every type in the type closure of that dynamic type**: the types of its
     fields (exported or not), the element types of arrays, slices, channels and maps (keys and values), the pointees of
     pointers, and, for a field or element of interface type, every **implementer** of that
     interface (the dynamic type is not known, so all possible ones count), each with its pointer and value method sets.
     The **implementer set** of an interface is defined once, here and for item 5: every type of the Go closure (every
     non-standard package of GO-046's closure) that implements it, together with the standard types of the pinned
     `GOROOT` that implement it, at their classes in the list. The type closure is a **set indexed by type identity**:
     each type is visited once, so recursive types terminate and two spellings of one type are one element.
     `fmt.Sprint(Outer{E: Evil{}})` and `json.Marshal(Outer{…})` reach `Evil`'s methods this way. A function stored into a composite
     value (a struct field, a slice, a map such as a `template.FuncMap`) is covered by the first sentence of this item,
     whether or not the composite is later passed to a standard function; `text/template` and `html/template` run such
     functions when a template is executed. **Generic functions are
     analysed per instantiation**: the body is analysed with the type arguments substituted, so a conversion of a value of
     type-parameter type counts the method sets of the actual type argument (`Gen[T any](v T)` calling `fmt.Sprint(v)` is
     pure for `Gen[int]` and impure for `Gen[Evil]`), and the classification and the lock entry are those of the
     instantiation the program uses, keyed by its type arguments (PKG-040, PKG-043). *Spelling of a type argument in the
     key:* the string of `go/types.TypeString` after resolving aliases to their targets, with every package written by its
     full import path (never its name), the arguments in parameter order separated by a comma without a space; an
     anonymous struct is spelled with its field names, types and tags in declaration order. A type declared inside a
     function is `<import path>.<owner>.<name>#<n>`, injective across owners: `<owner>` is the function name, or
     `<Receiver>.<Method>` with the receiver type spelled as above (so `func (A) String` and `func (B) String` differ), or
     `init.<k>` for the `k`-th `init` function of the package in the order of the sorted file names and then of the source,
     and a function literal appends `.func<k>`, where `k` is its ordinal among the literals directly inside the owner in
     source order (nested literals append again, `func1.func2`); `n` counts the local types of that name in the innermost
     owner in source order from 1. The ordinals depend on source order only, not on line numbers, so they do not change
     under an unrelated edit. *Aggregate bounds:* the Go closure holds at most 512 modules and 8192 packages, a build locks at most 16 tuples, a
     package declares at most 1024 overrides, and a build holds at most 8192 overrides in all; beyond that the build fails with E0712, so that the digest and the
     classification bookkeeping stay bounded. *Bounds:* at most 64 distinct instantiations of one generic function or of the methods of one
     generic type, 4096 in the whole program, and a type argument nested at most 16 deep. The **length of the spelling**
     is at most 1024 bytes, and the total of all lock keys at most 4 MiB. Because the spelling of a nested instantiation
     repeats its arguments, its length can be exponential in the depth, so it is computed bottom-up on the type graph with
     saturating arithmetic (the sum of the sizes of the parts, capped at 2^32) **before any string is built**; a
     spelling over the cap fails the build with E0712 without having been allocated. (The key of an entry is the pair of
     the tuple and function and the SHA-256 of the full spelling, hashed over the shared type graph, with the readable
     spelling stored next to it for display; the cap applies to the readable form.) *An Égide generic that calls a Go generic* is analysed per instantiation of the Égide
     function: the Égide type arguments are substituted and mapped to Go types by §11.3, and the Go instantiation is
     classified as above; a type argument with no Go mapping (a capability, a resource, a trait object) is E0713 at the call. A standard function that the list marks `pure` can invoke such a method without the
     call graph showing it (`fmt.Sprint(T{})` runs `T.String`, `sort.Sort(x)` runs `x.Less`), so the conversion, not the
     callee, is where the method is reached. Conversions in the standard library are covered by the list (GO-041);
     conversions in the user-package closure are analysed, and the method set of a standard type that is converted there
     counts with the classes of its methods in the list (`json.Unmarshal(&t)` with `t` a `time.Time` reaches
     `Time.UnmarshalJSON`, whose line is `clock`). Accepted cost: a user type with an impure method reports it
     at every conversion to an interface, even to `any`. The same applies to `*os.File`: a conversion of `os.Stdout` to
     `io.Writer` counts the methods of `os.File`, which are `go`, so Go code that writes to `os.Stdout` directly is `go`
     and the `os.var.Stdout` line (GOP-007) does not make it `stdout`. The way to write to the standard output with the
     `Stdout` capability is the writer that Égide passes to the Go function (it comes from Égide, item 1), or `fmt.Print*`,
     which the list classes `stdout`. No override
     lifts it: a method's findings are those of its body (GO-044.2 discharges only the findings listed there).
  5. *Arguments at a call site from Égide.* This item is **normative** (it is a rule about the call, decided from types
     the Égide compiler already holds, and does not use the call-graph analysis); the definition of the type closure in
     item 4 is normative for it. A call from Égide to **any** Go function whose own class is below `go`, that is a standard
     function of any class (`fmt.Printf` is `stdout`, and still dispatches to `String`) and a third-party function with a
     reviewed entry (a reviewed `Render(v any)` that calls `fmt.Sprint(v)`), takes, in addition to its own class, the union
     over its arguments of the following. The **static type** of an argument is the type of the argument *expression*
     (`Int`, `str`, `GoRef[Evil]`), not the type of the parameter, mapped to its Go type by §11.3; a variadic call is
     classified element by element, and a spread `*xs` by the element type of `xs`. So `fmt.Printf("%d", n)` with `n: Int`
     stays `stdout`, while a real `GoAny` or `any` element is `go` (accepted, fail-closed cost).
     (a) *Type closure, with or without methods.* The Go type of the argument is walked through the type closure of item 4
     **whether or not the type has methods itself**: slices, maps (keys and values), arrays, channels, pointers, structs
     with or without methods, and the Égide composites `List`, `Map`, `Option`, tuples and structs through the Go mapping
     of each component (`List[GoRef[Evil]]` is `[]*Evil`), and likewise `Result`, enums (every payload), `Array` and
     `Shared[T]` (through `T`). A type with no Go mapping (a capability, a resource, a trait object `dyn Trait`) passed as
     an argument is E0713. The class of every method of the method set of every type reached counts;
     (b) *Go interface types.* If the expression's static type is a **Go interface type** (a value that comes from Go),
     every member of its implementer set (item 4) counts, and the result is
     `go` when the implementers cannot be enumerated (`GoAny`, `any`). It does not apply to an Égide nominal type that
     implements a Go interface, such as the writer that Égide passes to a Go function (that one comes from Égide and its
     methods are Égide code under its own capabilities). `GoError` wraps `error`, so `errors.Is` and `errors.As` on a
     `GoError` are `go` once an unreviewed third-party error type is in the closure (accepted cost);
     (c) *Function values.* A Go function value or method value that is **not the callee of a direct call** counts as
     called at the expression where it appears, **in Égide source as well as in Go bodies (item 4)**, wherever it ends up:
     an argument, a field (`net.Dialer{Control: f}`), a `List`, a `Map`, a `Chan`, a spawned function, a stored value.
     A **direct callee** is the function position of a call expression `f(…)`, where `f` is a function name, a method
     selector `x.M` or an instantiated generic `f[T]`; a method value `x.M` and a method expression `T.M` that are not in
     that position, and an instantiated generic stored as a value, are function values. It takes the class of its target, and `go` when the target is not statically known. An Égide lambda keeps the
     rule of §11.3 (it runs with the capabilities it captured);
     (d) *Opaque types.* `reflect.Value`, `unsafe.Pointer`, `atomic.Value`, `sync.Map` and any type whose closure ends in
     `any`, in a non-enumerable interface or in a type parameter hide their dynamic type, and count as `go`;
     (e) *Per instantiation.* The rule is evaluated for each instantiation of an Égide generic with its type arguments
     substituted (`show[T](x: T)` calling `fmt.Println(x)` is `stdout` for `Int` and `go` for `GoRef[Evil]`); a type
     parameter that is not instantiated counts as `go`.
     (f) *Receiver.* The receiver of a method call is argument 0 and is classified with the static type of its
     expression under (a) to (e): `c.Do(req)` with `c` an `http.Client` is classified by the type closure of `c`, not
     only by `Do`.
     (g) *Construction.* A Go value built in Égide source (a struct literal, or a composite with Go-typed components,
     such as `http.Client(Transport: ref)`) is classified at the place where it is built, by the type closure of the
     components it contains and the function values among them (c), and that class belongs to the function that contains
     the expression, whether or not the value is ever passed to a call.
     A method of a non-standard type is `go` unless it has a reviewed entry, so `fmt.Sprint(x)`, `fmt.Println(outer)` and
     `Render(x)` with `x` a `GoRef` of a third-party type that has a `String` method, or `outer` a methodless struct
     holding one, are `go`.
  The review aid and the reviewed entries are recorded per function in `egide.lock` (PKG-040).
- **[GO-043] Drift detection.** When a new version of a Go module changes the classification of a function called by
  the Égide program, `egide lock` fails and prints the per-function capability diff of the review aid and the lock diff
  of the reviewed entries. The class of a function changes only through its reviewed entry (GO-044); the failure is
  closed, not a classification.
- **[GO-044] Overrides.** A package declares the reviewed classification of a Go function of a non-standard module of the
  Go closure of its own `[go]` section (GO-042, a module of `[go]` or a transitive one, item 1) with
  `[go.overrides] "<import path>.Func" = { class = "pure", reason = "…" }` (`class` is `pure` or one capability class,
  item 1) (a method is keyed
  `"<import path>.<Type>.<Method>"`; the import path is the longest prefix that is a package of such a module, and an
  ambiguous key is E0702). Like `@go_threadsafe` (GO-032) an override asserts a property the compiler cannot check, and is
  gated like it:
  1. `class` is `pure` or one capability class of GO-040 (`clock`, `rand`, `stdout`, `stderr`, `stdin`, `fs`, `env`,
     `proc`, `net`, `log`); `go` and `forbidden` are not classes of an entry. The key MUST resolve to an exported function or method **declared** in a package of a
     non-standard module of the Go closure of the `[go]` section of the same package (a module of `[go]` or a module that
     closure imports, so the methods of a type reached through a `GoRef` from a transitive module can have an entry), and
     the function MUST have a Go body. The entry is keyed by the import path of the declaring package, and the lock records
     the module path and version that declare it.
     Ownership is decided by the package that declares the resolved object (the Go type checker's `Func.Pkg()` after alias
     resolution, `Func.Origin()` for a generic function), not by the package named in the key and not by string prefix. A
     key that resolves to a method promoted through an embedded field, to a method or function of a type alias of a foreign
     type, to a package-level variable of function type, to a method of an interface type (also one promoted from an
     embedded local interface or reached through a type parameter), to a function without a Go body, to the standard
     library, to a module outside that closure, to a nested module, or to `init` or a variable initialiser, is E0702;
  2. **what an override discharges.** It discharges only findings of GO-042 item 1 (a call through a function or interface
     value) and item 3 (a write to an exported package-level variable) in the call graph reachable from the function, and only
     as follows. *Per instantiation:* all of the following is evaluated for each instantiation of a generic function that the program
     uses, with the type arguments substituted; a new instantiation is a new classification and, if it adds a discharged
     finding, a new digest (E0701) or a non-empty residual (E0702). *Item 1:* before a finding is discharged, the possible targets of the call are resolved inside the
     user-package closure (class-hierarchy or variable-type analysis), and the classes of the resolved targets enter the
     residual; a call through a value whose target is statically known (`w := os.Stdout.Write; w(p)`), through a
     package-level function variable (`hook(p)`) or through an interface with implementations in the closure is therefore
     not discharged. Only a call whose function value **originates from a parameter of the overridden function itself** is
     discharged; a function value merely *selected* by a parameter (`handlers[name]()`, a map or slice of functions indexed
     by a parameter) is not, because its targets are a bounded set the analysis resolves. A mixed target set
     (`if f == nil { f = hook }; f()`) discharges only the parameter-origin part; the resolved targets stay in the
     residual. A call the analysis cannot resolve (no targets given by the call-graph builder, a generic body analysed
     without instantiation) is never discharged: unbounded counts only as positive evidence, and an unresolved call stays in
     the residual. *Item 3:* only writes to exported variables **declared in the overridden function's own
     module**; a write to a variable of any other package, the standard library included, is residual. The **residual** is
     everything else GO-042 finds below the function: every item 2 finding (`unsafe`, cgo, assembly, `reflect`, a body-less
     function, `go:linkname`), every resolved target of item 1 and every call to a function whose classification by the aid (not by the baseline) is other than `pure`
     (`os.WriteFile` is `Dir`); a callee that is classified `Go` only because of a discharged item 1 finding does not count.
     The residual MUST be empty for `class = "pure"`, and for a capability class `C` MUST contain only classes `pure` and `C`;
     otherwise E0702, which prints it. **`--confirm` can never lift E0702**;
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
     dependency edge (PKG-030, PKG-031, PKG-032), where `<digest>` is the SHA-256 of (i) the **path, version and directory hash (GO-046.4) of every module that contains a
     package of the transitive import closure of the function's package**, and the hash of the `GOROOT` tree (GO-046.2);
     and (ii) the canonical map from every locked build tuple and instantiation (type arguments) to its set of discharged
     findings and the class. An entry asserts the whole call graph below the function, and that graph spans other modules,
     so a bump of a callee module under a fixed declaring module also changes the digest, even when no finding changes;
     the function is `go` again until the entry is confirmed, so a reviewed class never carries over to code nobody has
     read (so `x_windows.go` against `x_linux.go` is covered, and `egide lock
     --target` for a new tuple changes the digest). A missing entry, or a digest that differs from the computed one, fails the
     build (E0701). `egide audit` and `egide lock --confirm` print the sets in full, the old and the new class, and every module path and
     version of the preimage that changed, and `egide lock` writes the readable
     sets into `egide.lock` (the `allow` entry is a digest, so the lock diff is what a reviewer reads; the lock is committed
     and reviewed, PKG-040);
  6. **confirmation is a manifest edit.** `egide lock` and `egide update` never modify `allow`. When a dependency update
     changes the discharged sets, the build fails (E0701) until a person runs `egide lock --confirm
     go_override:<import path>.<Func>=<old digest>`, which names the function and the digest it replaces (so a stale script
     cannot confirm a changed set), rewrites that one entry and prints the difference, so the change appears as a manifest
     diff in review. The difference starts with the counts of added and removed findings, and every Go identifier in it is
     printed with the escaping of LEX-006 (Go identifiers may be non-ASCII, so a homoglyph `Wrіte` cannot pass for
     `Write`). The confirmation is meant for a person, which no tool can enforce: a script that runs `--confirm` after
     reading the old digest from the manifest is an accepted residual, visible in the manifest and lock diff. `--confirm` refuses to run without both. It does not apply to E0702. The checks of items 1 and 2 and the
     digest are evaluated for every locked build tuple;
  7. `egide audit` lists every override with its reason and its discharged sets, and `egide run` of a script prints the
     `allow` entries the script declares for itself (TOOL-011); `egide.lock` records them (PKG-040).

- **[GO-045] Package initialisation.** Go runs the `init` functions and package-level variable initialisers of every Go
  package linked into the program (the transitive import closure of the packages named by `import go`) before `main`,
  with ambient authority and before any capability value exists. Blank imports (`import _ "net/http/pprof"`) run them
  without any call, so GO-010 to GO-012 never apply. The **init set** of a package is its `init` functions and its
  variable initialisers; it is classified per package:
  1. *Standard library.* A package is **standard** when its import path resolves to a directory of the pinned `GOROOT`
     `src` tree, its `vendor` directory included (`go list` reports `Standard`); nothing else is, whatever its path looks
     like. The init-class test applies to **every standard package in the closure, for every locked build tuple** (the
     imports of a file selected by one tuple only count for that tuple), including those reached
     only through a third-party package (a third party's `import _ "plugin"` is as much an error as an Égide
     `import go "plugin"`). The purity list (GO-041, appendix A.4) holds one line `<import path>.init <class>` per package;
     it covers the package's own initialisers and those of the standard packages it imports. A package without a line has
     the class `forbidden` if A.3 lists it as `forbidden`, otherwise `go`. Only `pure` is accepted: any other class is
     E0705, and no `allow` entry lifts it. The packages the Égide runtime links (A.5) are exempt;
  2. *Third-party packages.* This item covers **every non-standard package of the Go closure** (GO-046): the packages of
     the modules of `[go]` and every non-standard package they import, so a transitive module is included, and the
     standard-library check of item 1 applies to what each of them imports. The init set of such a package is **trivial**
     when all of the following hold: the package has no `init` function; every package-level variable initialiser is a
     constant expression or a composite literal of constant expressions (no call, no function value, no explicit
     conversion to an interface type; an implicit conversion runs nothing); and the package uses none of `//go:linkname`
     (a linknamed variable overwrites a symbol of another package with no call), an import of `unsafe` (blank imports
     included), an assembly file, an import of `embed` or a `//go:embed` directive, or cgo. That is a syntactic test on
     the files, evaluated **for every locked build tuple** (a file selected by one tuple only counts for that tuple, and
     the package is trivial only if it is trivial under all of them), not an analysis. A trivial init set needs no entry.
     Any other init set is `go` and requires
     `"go_init:<module>@<version>=<classes>"` in `allow` (E0704), where `<classes>` is the sorted, comma-separated set of
     capability classes that a person assigned to it, or `pure` (for example `go_init:example.com/m@v1.2.3=env,net`). The
     entry is a reviewed assertion, like `unsafe`: no analysis lowers, raises or checks it, and a static analysis, where
     one exists, is only a review aid that `egide audit` prints (the init functions, the variable initialisers and the
     callbacks they register). It is a key distinct from `go:<module>` so that approving the calls of a module does not
     approve initialisers it gains later, and it names the version, so that a new version needs a new decision. The entry
     grants exactly the **set of capability classes** it names, and that grant holds wherever the callbacks the init set
     registers are reachable, including through dispatchers the list classifies pure (`image.Decode`, `crypto.Hash.New`,
     `sql.Open` with a registered driver), not only at start-up. A package that imports, by name or blank, a standard
     package of class `forbidden` such as `net/http/pprof` or `expvar` fails item 1 (E0705);
  3. cgo, `.syso` objects, `//go:cgo_*` directives and any file the build does not compile are not part of the init set
     **because GO-046 rejects them (E0706) and requires a static binary (E0710)**; GO-045 is sound only together with
     GO-046 and MUST NOT be applied without it;
  4. drift detection (GO-043), the lock (PKG-043) and `egide audit` cover init sets. For a package that has an entry or
     is not trivial, a change of the module version, or of the set of init functions and variable initialisers that the
     lock records for the package (a package that was trivial and no longer is, or that gains a function), fails the
     build (E0704) until a person confirms it, whatever the classes: an entry never carries over to a version nobody
     read. A package that is trivial before and after a version bump needs nothing. The first entry of a package that
     has just stopped being trivial is written by hand in the manifest (`--confirm` replaces an existing entry and cannot
     create one). `egide lock` and `egide update` never modify `allow`;
     only `egide lock --confirm go_init:<module>@<old version>=<old classes>` rewrites that entry, prints the difference
     and refuses to run without the module, the version and the classes it replaces, so the change appears as a manifest
     diff in review and a bot cannot clear it. No capability can mediate an initialiser; the OS sandbox (GO-013) is the
     only barrier left after these gates.

## 11.5 Calling Égide from Go

- **[GO-050]** `egide build --go-package <dir>` generates an idiomatic Go package for the `pub` API of an Égide package:
  `Result[T, E]` → `(T, error)`, `Option[T]` → `*T`, enums → sealed interfaces with one type per variant,
  `List`/`Map` → slices/maps (copied), capabilities → values obtained from `rt.Ambient()` in package `github.com/omeroland/egide-langage/runtime/go/rt` (Go has ambient
  authority anyway).
