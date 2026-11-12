# 10. Modules and packages

## 10.1 Modules

- **[PKG-001]** A module is one `.egd` file. A package is a directory tree with an `egide.toml` manifest at its root and
  sources under `src/`. The module path is the file path under `src/` with `/` replaced by `.` and without extension.
- **[PKG-002]** Imports form a directed acyclic graph; an import cycle between modules is a compile-time error that
  lists the cycle.
- **[PKG-003]** Only `pub` items are visible outside their module. `pub(package)` restricts visibility to the package.

## 10.2 Manifest

```toml
# egide.toml
[package]
name    = "qc.omeroland.sync"      # reverse-DNS namespace, verified by the registry
version = "0.3.0"                  # SemVer
edition = "2027"
license = "Apache-2.0"
allow   = ["unsafe"]               # this package's own breaches (PKG-032); a dependency's entry is in [dependencies]

[dependencies]
"egide.toml" = "1.4"
"egide.http" = "2.1"
"egide.pg"   = { version = "0.9", allow = ["ffi:libpq"] }

[go]                               # Go modules (chapter 11)
"k8s.io/client-go" = "v0.31.0"

[embed]
files = ["schemas/*.json"]

[comptime]
max_steps = 100_000_000
```

- **[PKG-010]** `[package]` keys `name`, `version`, `edition` are mandatory. `allow` is optional (PKG-032).
- **[PKG-011]** A dependency version requirement `"1.4"` means `>= 1.4.0, < 2.0.0`.
- **[PKG-012]** `[comptime]` may raise the compile-time budget of CT-003 for this package only.
- **[PKG-013]** `[embed].files` lists the glob patterns `embed()` may read (CT-050).

## 10.3 Version selection

- **[PKG-020]** Dependency resolution uses **minimal version selection** (as in Go modules): for each package, the
  highest of the minimum versions required anywhere in the graph is selected. No SAT solver; results are predictable
  and reproducible.

## 10.4 Breaches of the capability model

Thanks to capabilities (chapter 6), a dependency can only do what the code passes to it; the manifest does not list
I/O permissions. It controls only the ways around the model.

- **[PKG-030]** A dependency whose code (transitively) contains `unsafe`, C FFI, impure Go calls or `@go_threadsafe` MUST be listed with
  the matching `allow` entries: `"unsafe"`, `"ffi:<library>"`, `"go:<module>"`, `"go_threadsafe:<go module>"` (GO-032), `"go_override:<import path>.<Func>=<digest>"` (GO-044), `"test-capabilities"`.
  A dependency update that introduces a new breach fails the build until the manifest is updated.
- **[PKG-031]** `allow` entries are not transitive: every package that (transitively) depends on a breaching package
  declares it, so the breach is visible at every level. An `allow` list is read only from the manifest of the package that
  declares the dependency edge, never as a union over the graph, so a dependency cannot satisfy a gate of its dependent.
- **[PKG-032]** The gate protects a package from its dependencies and also covers its own code. A package lists its own
  breaches in `allow = [...]` of its `[package]` table, with every kind of entry of PKG-030. For the **root** package this list is mandatory: a breach in the root's own code that is not listed
  there fails the build with the code of the breach (E0421 for `@go_threadsafe`, E0701 for an override, E0703 for
  every other entry kind: `unsafe`, `ffi:<library>`, `go:<module>`, `test-capabilities` and any entry kind added later). For a dependency
  it is informational (it feeds `egide audit`) and **never** satisfies the gate of a dependent, which is the `allow` of
  the edge (PKG-031). A manifest-less script (TOOL-011) has an empty list unless its leading comment block declares one.

## 10.5 Lockfile and integrity

- **[PKG-040]** `egide.lock` records, for every package: exact version, SHA-256 of the source archive, the publisher's
  Sigstore signature bundle, the `allow` breaches found, and for Go modules the `go.sum` lines, the per-function
  capability classification (GO-042) and the overrides (GO-044) with, for each, the set of discharged findings per
  build tuple and the digest of that map. A classification is keyed by (build tuple, Go package, function); an override by (build tuple, Égide package that
  declares it, Go package, function), so that package B never reads the override of package A, even when both depend on the
  same Go module. The build tuple is the set of settings that select Go files (`GOOS`, `GOARCH`, tags and the rest of the Go
  build), so a result computed for one tuple is not reused for another.
- **[PKG-041]** Builds verify every hash and signature. A mismatch is a fatal error; there is no flag to skip it.
- **[PKG-042]** Installing or building a package never executes code of that package with authority: there are no
  build scripts, install hooks or post-install steps (INT-005). The same holds for the Go modules of `[go]`: their analysis
  and build run under GO-046 (no cgo, no toolchain download, no `go generate`, no inherited environment).
- **[PKG-043]** For the Go closure `egide.lock` also records the Go toolchain version, the SHA-256 of its distribution
  archive and of the installed `GOROOT` tree, for the native backend the hash of the C toolchain tree (GO-046.1), the SHA-256
  of every module directory used (GO-046.4) and the per-function classification, under the keys of PKG-040 ((build tuple, Go package, function); overrides add the declaring
  Égide package).

## 10.6 Reproducibility and provenance

- **[PKG-050]** Given the same sources, lockfile and compiler version, `egide build` MUST produce bit-identical
  artefacts (timestamps and absolute paths are normalised).
- **[PKG-051]** `egide build --sbom` emits CycloneDX 1.6 and SPDX 2.3 documents that include `allow` breaches.
- **[PKG-052]** `egide vendor` copies all dependencies into `vendor/` for air-gapped builds; the lockfile still
  applies.

## 10.7 Registry

- **[PKG-060]** Package names are reverse-DNS namespaces whose ownership is verified (domain or GitHub organisation).
  Published versions are immutable; yanking hides a version from new resolutions without deleting it.
- **[PKG-061]** The registry rejects names within edit distance 1 of an existing popular package in the same
  namespace level (typosquatting).

## 10.8 Editions

- **[PKG-070]** Incompatible syntax changes are introduced only in a new edition declared in the manifest. Packages of
  different editions interoperate; `egide fix --edition` migrates sources.
