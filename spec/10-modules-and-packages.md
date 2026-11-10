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

- **[PKG-010]** `[package]` keys `name`, `version`, `edition` are mandatory.
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
  the matching `allow` entries: `"unsafe"`, `"ffi:<library>"`, `"go:<module>"`, `"go_threadsafe:<go module>"` (GO-032), `"test-capabilities"`.
  A dependency update that introduces a new breach fails the build until the manifest is updated.
- **[PKG-031]** `allow` entries are not transitive: every package that (transitively) depends on a breaching package
  declares it, so the breach is visible at every level.

## 10.5 Lockfile and integrity

- **[PKG-040]** `egide.lock` records, for every package: exact version, SHA-256 of the source archive, the publisher's
  Sigstore signature bundle, the `allow` breaches found, and for Go modules the `go.sum` lines and the per-function
  capability classification (GO-042).
- **[PKG-041]** Builds verify every hash and signature. A mismatch is a fatal error; there is no flag to skip it.
- **[PKG-042]** Installing or building a package never executes code of that package with authority: there are no
  build scripts, install hooks or post-install steps (INT-005).

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
