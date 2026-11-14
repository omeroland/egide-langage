# Go toolchain parity for `egide`

- Task: T-1120. Status: analysis and plan, no compiler code. Companion: ADR-0019 (Proposed), spec-questions Q-0040..Q-0045.
- Go version inspected: go1.24.7 linux/amd64 (the only Go installed in the session).

## Executive Summary

The owner asked that the tools of the Go language be added to Égide. Interpretation retained: the `egide` toolchain
offers at least **functional parity with the standard Go toolchain**, so that Go developers are not lost; it does not
mean copying Go's command names or its execution-of-host-code features. Of the **55 tools** inventoried
(9 covered, 13 partial, 18 absent, 15 deliberately excluded), plus 25 test/build modes and 33 `go vet`
analyzers, the plan creates **36 backlog tasks (T-1121..T-1156)**, one ADR proposal and six spec-questions; the largest
single finding is not a Go gap: spec chapter 13 already promises `egide test`, `egide audit`, `egide expand`,
`egide explain` and a VS Code extension for which **no task existed**.

## 1. Core Analysis

### 1.1 Method and evidence levels

- *established*: read from the local Go 1.24.7 (`go help`, `go help <cmd>`, `go tool`, `go tool vet help`, `go doc cmd/<tool>`)
  or from the Égide repository at commit c4c4df4. Column `Src` = `L`.
- *emerging*: facts about tools that are not in the Go distribution (gopls, govulncheck, pkgsite, godoc, staticcheck,
  modernize) and about Go releases after 1.24. `go.dev`, `pkg.go.dev` and the Go module proxy are unreachable from the
  session (proxy refusal and no DNS), so these rest on prior knowledge and are **not verified**. Column `Src` = `M`.
  Rows with `M` must be re-checked against upstream documentation before any task that depends on their behaviour starts.
- *extrapolated*: every proposal for Égide (commands, phases, designs). Proposals are in the `Égide equivalent`, `Phase`
  and `Note` columns and in ADR-0019.

Spec state definitions (relative to `spec/` and `docs/roadmap.md` before this plan):

| State | Meaning |
|-------|---------|
| Covered | the function is normatively specified (a rule or a row of the chapter 13 table), or replaced by a specified language rule |
| Partial | named only in passing (flag, testing.md, a task, a related rule) or specified for one part of the function |
| Absent | not mentioned |
| Excluded | deliberately not provided, with the reason in the Note column |

Dispositions: *Provide* (same function), *Exceed* (same function, stricter or richer for security), *Replace* (a
language property or another command removes the need), *Reuse* (emit a standard format, reuse the external viewer),
*Exclude*.

### 1.2 Inventory of the Go toolchain

`go help` lists 19 commands: bug, build, clean, doc, env, fix, fmt, generate, get, install, list, mod, work, run,
telemetry, test, tool, version, vet. `go mod` has 8 subcommands (download, edit, graph, init, tidy, vendor, verify, why),
`go work` has 5 (edit, init, sync, use, vendor). `go tool` lists 18 built-in tools. Three entries in D are the back-ends
of commands already in A (doc, fix, vet) and are kept as separate rows because they are separate programs.

#### A. `go` commands (17 counted; `go mod` and `go work` are counted through B and C)

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| A01 | `go build` | L | egide build | Covered | Provide | 5/6 | go-backend, tooling | T-0081, T-1153 | spec 13 table, PKG-050/051, GO-050; Go flags beyond the table in T-1153 |
| A02 | `go run` | L | egide run | Covered | Provide | 1 | tooling | T-0036 | TOOL-010..012; interpreter, not compile-and-exec |
| A03 | `go install` | L | egide install PKG@VER | Absent | Exceed | 6 | tooling | T-1140 | Sigstore-verified, no install hooks (PKG-042) |
| A04 | `go test` | L | egide test | Covered | Provide | 2/4/6 | tooling | T-1122, T-1123, T-1124 | TOOL-030/031; no task existed before this plan |
| A05 | `go vet` | L | egide check (compiler diagnostics) | Covered | Replace | 1-4 | per pass owner | none | TOOL-040/041; see section 5 |
| A06 | `go fmt` | L | egide fmt | Covered | Provide | 6 | tooling | T-0090, T-1154 | TOOL-020 |
| A07 | `go doc` | L | egide doc | Partial | Provide | 6 | tooling | T-1143 | only LEX-011 doc comments and T-1040 mention it |
| A08 | `go get` | L | egide add / remove / update | Partial | Provide | 6 | tooling | T-1134 | egide lock resolves; no command edits requirements |
| A09 | `go list` | L | egide list [--json] | Absent | Exceed | 6 | tooling | T-1139 | adds capabilities and allow breaches per package |
| A10 | `go generate` | L | comptime, derive, templates, egide expand | Covered | Replace | 2 | comptime | T-1146 | ADR-0004, CT-060; never run arbitrary commands (INT-005) |
| A11 | `go clean` | L | egide clean | Absent | Provide | 6 | tooling | T-1142 |  |
| A12 | `go env` | L | egide env (read-only) | Absent | Provide | 6 | tooling | T-1141 | no -w: no persistent config surface |
| A13 | `go version` | L | egide version [-m FILE] | Partial | Exceed | 6 | tooling | T-1141 | T-0019 has --version only; -m prints embedded SBOM data |
| A14 | `go bug` | L | egide bug (prints, no browser) | Absent | Provide | 6 | tooling | T-1142 | report text only; no network, no browser |
| A15 | `go fix` | L | egide fix | Partial | Provide | 6 | tooling | T-1144 | PKG-070 names only --edition; TOOL-040 edits are the engine |
| A16 | `go telemetry` | L | none | Excluded | Exclude | - | - | Q-0042 | no telemetry of any kind |
| A17 | `go tool` | L | none as generic runner | Excluded | Exclude | - | - | - | module-defined tools run host code; built-in tools: section D |

#### B. `go mod` subcommands

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| B01 | `go mod init` | L | egide new | Absent | Provide | 6 | tooling | T-1133 | PKG-010 mandates the manifest, nothing creates it |
| B02 | `go mod tidy` | L | egide lock + unused-dependency diagnostic | Partial | Provide | 6 | tooling | T-0092, T-1138 |  |
| B03 | `go mod download` | L | egide fetch | Absent | Provide | 6 | tooling | T-1136 | populates cache for air-gapped CI; verifies (PKG-041) |
| B04 | `go mod vendor` | L | egide vendor | Covered | Provide | 6 | tooling | T-0092 | PKG-052 |
| B05 | `go mod verify` | L | egide verify | Partial | Exceed | 6 | tooling | T-1136, T-1137 | PKG-041 verifies at build only; add on-demand and artifact rebuild |
| B06 | `go mod graph` | L | egide graph | Absent | Exceed | 6 | tooling | T-1135 | edges annotated with allow breaches |
| B07 | `go mod why` | L | egide why | Absent | Provide | 6 | tooling | T-1135 |  |
| B08 | `go mod edit` | L | none | Excluded | Exclude | - | - | T-1134, T-1139 | TOML edited by add/remove/update, read by list --json |

#### C. `go work` subcommands

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| C01 | `go work init` | L | egide workspace init | Absent | Provide | 6 | tooling | T-1145 | needs Q-0043 (manifest design) |
| C02 | `go work use` | L | egide workspace use | Absent | Provide | 6 | tooling | T-1145 |  |
| C03 | `go work sync` | L | part of egide lock in workspace mode | Absent | Provide | 6 | tooling | T-1145 |  |
| C04 | `go work edit` | L | none | Excluded | Exclude | - | - | - | same reason as B08 |
| C05 | `go work vendor` | L | egide vendor in workspace mode | Partial | Provide | 6 | tooling | T-1145 | PKG-052 exists, workspaces do not |

#### D. `go tool` built-in tools (`go tool` output, Go 1.24.7)

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| D01 | `addr2line` | L | none | Excluded | Exclude | - | - | - | internal helper of pprof |
| D02 | `asm` | L | none | Excluded | Exclude | - | - | - | no assembly language in Égide |
| D03 | `buildid` | L | egide version -m | Excluded | Replace | - | - | T-1141 | reproducible content hashes (PKG-050) replace build ids |
| D04 | `cgo` | L | import go; allow ffi:<lib> | Covered | Replace | 5 | go-interop | T-0082 | ADR-0008, GO-001; a C FFI mechanism is only named (PKG-030, MEM-070): Q-0045 |
| D05 | `compile` | L | egide build --emit=... | Partial | Provide | 6 | tooling | T-1153 | lex/parse exist as debug commands; no HIR/MIR/Go dump |
| D06 | `covdata` | L | egide cover merge/report | Absent | Provide | 6 | tooling | T-1126 | coverage of compiled binaries |
| D07 | `cover` | L | egide test --cover; egide cover | Absent | Provide | 6 | tooling | T-1125 |  |
| D08 | `doc` | L | backend of A07 | Partial | Provide | 6 | tooling | T-1143 | duplicate entry of go doc |
| D09 | `fix` | L | backend of A15 | Partial | Provide | 6 | tooling | T-1144 | duplicate entry of go fix |
| D10 | `link` | L | none | Excluded | Exclude | - | - | - | backend internal |
| D11 | `nm` | L | none (host tools on Go-backend binaries) | Excluded | Reuse | - | go-backend | T-1152 | //line directives make host tools show .egd positions |
| D12 | `objdump` | L | none (host tools) | Excluded | Reuse | - | go-backend | T-1152 | as nm |
| D13 | `pack` | L | none | Excluded | Exclude | - | - | - | Go archive format |
| D14 | `pprof` | L | --cpuprofile/--memprofile flags; viewer reused | Absent | Reuse | 6 | tooling | T-1128 | emit pprof format, do not reimplement the viewer |
| D15 | `preprofile` | L | none | Excluded | Exclude | - | - | - | PGO is phase 7+ (no task in this plan) |
| D16 | `test2json` | L | egide test --json (native) | Excluded | Replace | 6 | tooling | T-1124 | no converter needed |
| D17 | `trace` | L | egide test --trace | Absent | Provide | 7 | native-backend | none | deferred: needs scheduler events (phase 7); Go backend can use runtime/trace |
| D18 | `vet` | L | backend of A05 | Covered | Replace | 1-4 | per pass owner | none | duplicate entry of go vet |

#### E. Standalone tools of the Go project and ecosystem

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| E01 | `gofmt` | L | egide fmt (--check, --diff, stdin) | Partial | Provide | 6 | tooling | T-0090, T-1154 | -l = --check; -d, stdin, -e not in spec; -s and -r excluded (TOOL-020: no options) |
| E02 | `godoc (server)` | M | egide doc --html (static) | Excluded | Exclude | - | - | - | legacy local server; toolchain stays offline |
| E03 | `pkgsite` | M | registry-hosted documentation | Absent | Provide | 6+ | none owns it | none | needs the registry (PKG-060); open question 4 |
| E04 | `gopls` | M | egide lsp | Partial | Provide | 6 | tooling | T-0091, T-1148, T-1149 | TOOL-050 lists 9 features; gopls has more |
| E05 | `govulncheck` | M | egide audit (vulnerabilities) | Partial | Exceed | 6 | tooling | T-1131, T-1132 | spec 13 says 'known vulnerabilities'; no database, no rule |
| E06 | `staticcheck (third party)` | M | none; compiler warnings (W-codes) | Excluded | Exclude | - | - | - | outside the Go standard chain |
| E07 | `modernize` | M | egide fix | Absent | Provide | 6 | tooling | T-1144 | rewrites to newer idioms; part of fix |

### 1.3 Test and build modes (flags and mechanisms)

All flags below were read from `go help testflag`, `go help build`, `go help cache`, `go help get` (Go 1.24.7).

| ID | Go tool | Src | Égide equivalent | Spec state | Disposition | Phase | Role | Tasks | Note |
|----|---------|-----|------------------|------------|-------------|-------|------|-------|------|
| F01 | `go test -race` | L | INT-002; `egide test --race` is unavailable on the Go backend (needs cgo, ADR-0024 E0708) until a cgo story exists | Covered | Replace | 6 | tooling | T-1129 | races only through GoRef/unsafe (GO-032, MEM-070); the race detector itself is deferred |
| F02 | `-msan, -asan` | L | none now; --sanitize on native backend | Excluded | Exclude | 7 | native-backend | none | cgo-oriented; revisit with the C backend |
| F03 | `-fuzz, -fuzztime, -fuzzminimizetime` | L | egide test --fuzz | Partial | Provide | 6 | tooling | T-1130 | @property exists, coverage guidance does not (TOOL-030) |
| F04 | `-bench, -benchtime, -benchmem` | L | egide bench | Partial | Provide | 6 | tooling | T-1127 | docs/testing.md only; not in spec 13 |
| F05 | `-cover, -covermode, -coverprofile, -coverpkg` | L | egide test --cover | Absent | Provide | 6 | tooling | T-1125 |  |
| F06 | `-json` | L | egide test --json | Partial | Provide | 6 | tooling | T-1124 | TOOL-042 covers diagnostics only |
| F07 | `-run, -skip, -list, -shuffle, -count, -short, -timeout, -failfast, -parallel, -cpu, -fullpath` | L | egide test --filter/--skip/--list/--shuffle/... | Absent | Provide | 6 | tooling | T-1124 |  |
| F08 | `-c, -exec, -o` | L | none | Excluded | Exclude | - | - | - | -exec runs a host command with ambient authority |
| F09 | `-cpuprofile, -memprofile, -blockprofile, -mutexprofile, -trace` | L | --cpuprofile, --memprofile | Absent | Provide | 6 | tooling | T-1128 | block/mutex/trace deferred |
| F10 | `test result cache` | L | egide test cache | Absent | Exceed | 6 | tooling | T-1124 | sound for non-@integration tests: fake capabilities only (TOOL-031) |
| F11 | `go test -vet` | L | full type-check before tests | Covered | Replace | 1 | tooling | none |  |
| F12 | `Example functions` | L | doctests | Covered | Replace | 2 | tooling | T-1122 | TOOL-030 |
| F13 | `build -trimpath` | L | default behaviour | Covered | Replace | 6 | go-backend | T-0081 | PKG-050 normalises paths; no flag |
| F14 | `-ldflags, -gcflags, -asmflags, -gccgoflags, -compiler` | L | none | Excluded | Exclude | - | - | - | -ldflags -X injects untracked values into the artefact |
| F15 | `-tags, //go:build constraints` | L | conditional compilation | Absent | Provide | 6 | type-system | T-1153 | Q-0040 |
| F16 | `-buildmode (archive, c-archive, c-shared, exe, pie, plugin, ...)` | L | --go-package (GO-050); others undecided | Partial | Provide | 6 | go-backend | T-1153 | plugin excluded: dynamic code loading bypasses audit |
| F17 | `-pgo` | L | none now | Absent | Provide | 7 | native-backend | none | phase 7+ |
| F18 | `-overlay` | L | none | Excluded | Exclude | - | - | - | editor buffers are handled inside the LSP |
| F19 | `-mod, -modfile, -modcacherw` | L | none: lockfile is always authoritative | Covered | Replace | 6 | tooling | T-0092 | PKG-041, no bypass |
| F20 | `-toolexec, vet -vettool` | L | none | Excluded | Exclude | - | - | - | runs host code with ambient authority during build/check |
| F21 | `-buildvcs (VCS stamping)` | L | none; provenance via SBOM | Excluded | Exclude | - | - | - | breaks PKG-050 unless the commit is an input |
| F22 | `-n, -x, -v, -work, -a, -p` | L | egide build --verbose/--dry-run | Absent | Provide | 6 | tooling | T-1153 |  |
| F23 | `build -json` | L | egide build --error-format=json (+ events) | Partial | Provide | 6 | tooling | T-1153 | TOOL-042 |
| F24 | `module authentication (go.sum, GOSUMDB, GOPROXY, GOPRIVATE, GONOSUMDB, GOAUTH)` | L | lockfile hashes + Sigstore | Partial | Exceed | 6 | tooling | T-0092 | PKG-040/041; private registries: Q-0041 |
| F25 | `toolchain selection (GOTOOLCHAIN, go get toolchain@)` | L | none | Absent | Provide | 6 | tooling | Q-0042 | auto-download of a compiler = download and run code |

### 1.4 `go vet` analyzers

`go tool vet help` of Go 1.24.7 lists 33 analyzers. Égide does not need a `vet`: the checks are either impossible
to violate by a language rule, or are compiler diagnostics (TOOL-040). The `Absent` rows are candidates for new
warning codes and are the only vet-related work; they go to the owners of the passes, not to a vet command.

| Analyzer | Égide mechanism | State | Category |
|----------|-----------------|-------|----------|
| `appends` | no `append` builtin in spec | Excluded | Go-specific |
| `asmdecl` | no assembly | Excluded | Go-specific |
| `assign` | self-assignment | Absent | candidate W-code |
| `atomic` | MEM-002 (no address-of), CON-040 Atomic[T] | Covered | language |
| `bools` | redundant boolean expressions | Absent | candidate W-code |
| `buildtag` | Q-0040 | Absent | depends on conditional compilation |
| `cgocall` | GO-021 (copy at boundary), no cgo | Covered | language |
| `composites` | TYP-020 named fields, SYN-032 | Covered | language |
| `copylocks` | CON-040, MEM-051 (locks live in Shared) | Covered | language |
| `defers` | ERR-035 (expr evaluated at block exit), ERR-031 | Covered | language |
| `directive` | no //go: directives | Excluded | Go-specific |
| `errorsas` | ERR-020 (error enums, match) | Covered | language |
| `framepointer` | no assembly | Excluded | Go-specific |
| `httpresponse` | ERR-030..032 (resources closed by with) | Covered | language |
| `ifaceassert` | TYP-043 (dyn is explicit) | Covered | language |
| `loopclosure` | MEM-001 (capture by logical copy), CON-021 | Covered | language |
| `lostcancel` | CON-001..004 (scopes own cancellation) | Covered | language |
| `nilfunc` | INT-001 (no null) | Covered | language |
| `printf` | CT-041, CT-042 (f-strings checked at compile time) | Covered | language |
| `shift` | TYP-010 (overflow panics, `<<` listed) | Covered | language |
| `sigchanyzer` | signals only via capabilities | Excluded | Go-specific |
| `slog` | std.log API not specified yet | Excluded | revisit with the stdlib |
| `stdmethods` | TYP-040, TYP-041 (trait conformance) | Covered | language |
| `stdversion` | std symbol since-version gating | Absent | candidate E-code; PKG-070 covers syntax only |
| `stringintconv` | TYP-021 (no implicit integer conversion) | Covered | language |
| `structtag` | no struct tags; derive (CT-030) | Excluded | Go-specific |
| `testinggoroutine` | CON-003 (task panics propagate) | Covered | language |
| `tests` | TOOL-030 signature of @test | Partial | rule exists, no diagnostic code allocated |
| `timeformat` | no layout-string time API specified | Excluded | revisit with the stdlib |
| `unmarshal` | SEC-030 typed deserialisers | Covered | language |
| `unreachable` | unreachable code | Absent | candidate W-code |
| `unsafeptr` | MEM-070, MEM-071 (reason, manifest, audit) | Covered | language |
| `unusedresult` | ERR-002 (E0304) | Covered | language |

### 1.5 Counts

| Group | Entries | Covered | Partial | Absent | Excluded |
|-------|---------|---------|---------|--------|----------|
| A. `go` commands | 17 | 6 | 4 | 5 | 2 |
| B. `go mod` subcommands | 8 | 1 | 2 | 4 | 1 |
| C. `go work` subcommands | 5 | 0 | 1 | 3 | 1 |
| D. `go tool` built-in tools | 18 | 2 | 3 | 4 | 9 |
| E. Standalone tools of the Go project and ecosystem | 7 | 0 | 3 | 2 | 2 |
| **Tools A-E** | **55** | **9** | **13** | **18** | **15** |
| F. Test/build modes | 25 | 5 | 6 | 8 | 6 |
| G. vet analyzers | 33 | 19 | 1 | 5 | 8 |

Dispositions over A-E: Exceed 6, Exclude 11, Provide 29, Replace 6, Reuse 3.
The counts are generated from the tables of this document; D08, D09 and D18 duplicate A07, A15 and A05, so the number
of distinct functions is 52. Reading of the numbers: "Covered" mostly means "specified", not "implemented":
nothing of chapter 13 beyond `lex`/`parse` exists yet (phase 0).

### 1.6 Where Égide must do better than Go (security)

| Area | Go | Égide proposal | Evidence |
|------|----|----------------|----------|
| Module authentication | checksum database and `go.sum`; `GONOSUMDB`, `GOFLAGS=-insecure`, `GOPRIVATE` weaken it (L: `go help private`, `go help module-auth`) | lockfile with SHA-256 and Sigstore bundles, no bypass (PKG-041); on-demand `egide verify` (T-1136) | established (spec), extrapolated (command) |
| Vulnerabilities | `govulncheck` outside the distribution (M) | `egide audit` in the toolchain, offline signed snapshot, reachability from the call graph of ADR-0009 (T-1132) | extrapolated |
| Authority of dependencies | none: any package can use any API | capabilities (ch. 6) and `allow` breaches listed per package (PKG-030/031), shown by `list`, `graph`, `why`, `audit` | established (spec) |
| Build-time code | `go generate`, cgo, `-toolexec`, `-vettool`, module tools run host code (L) | none (INT-005, PKG-042); comptime is pure and bounded (CT-003) | established |
| SBOM | not produced by the `go` command (L: absent from `go help`) | CycloneDX 1.6 and SPDX 2.3 with breaches (PKG-051), readable with `egide version -m` (T-1141) | established (spec) |
| Reproducibility | achievable, no built-in check | `egide verify --artifact` (T-1137), CI double build | extrapolated |
| Go interop purity | n/a | per-function purity list, call-graph classification, drift detection (ADR-0009, GO-040..044) | established |
| Test determinism | test cache keyed by observed file/env accesses (M) | sound cache because tests hold fake capabilities only (TOOL-031) | extrapolated |
| Output injection | none | every tool output goes through one escaping function (LEX-006, T-1039) | established |

### 1.7 What not to copy

| Go feature | Reason | Replacement |
|------------|--------|-------------|
| `go generate` | runs arbitrary commands, outputs are checked in and drift | comptime, derive, templates, `egide expand` (ADR-0004, CT-060) |
| `-toolexec`, `vet -vettool`, `go tool <module tool>`, `go run pkg@ver` style execution of fetched code | executes code with ambient authority in the build/check path (spirit of INT-005) | built-in diagnostics; sandboxed tooling only by a future ADR |
| `go telemetry` | collection and upload of usage data from a security-focused toolchain | none; no telemetry (Q-0042) |
| automatic toolchain download (`GOTOOLCHAIN`, `go get toolchain@`, L: `go help get`) | downloading and running a compiler on `go build` contradicts "no network when the lockfile is complete" | explicit `egide` upgrade by the user; minimum-version field is Q-0042 |
| `-ldflags -X`, `-gcflags`, `-asmflags` | inject untracked values / depend on backend internals; break PKG-050 | `embed()` (CT-050) and manifest configuration |
| `-buildmode=plugin` | dynamic loading bypasses audit and the lockfile | `--go-package` (GO-050) |
| `go mod edit`, `go work edit` | scripting surface for a file humans should not hand-edit | `add/remove/update`, `list --json` |
| `GONOSUMDB`, `GOFLAGS=-insecure`, `GOINSECURE` class of switches | PKG-041: no flag skips verification | private registries with their own trust root (Q-0041) |
| `gofmt -r`, `-s` | options on the formatter; TOOL-020 forbids options | `egide fix` for rewrites |
| `go env -w` | persistent hidden configuration | read-only `egide env` |
| a `vet`/linter plugin ecosystem (staticcheck outside the chain) | out of the standard chain; compiler warnings are the policy | W-codes in docs/diagnostics.md |
| `go bug` opening a browser | side effect with network | `egide bug` prints text |

### 1.8 Critical review of the premise

- **Counter-hypothesis 1: parity of workflows, not of commands.** A literal 1:1 copy (`egide mod tidy`, `egide tool pprof`)
  would import Go's spelling and Go's trust assumptions. Chosen instead: one verb per task (`add`, `why`, `graph`, `fetch`,
  `verify`), flat namespace, following the existing chapter 13 table. Rejected: nested `egide mod ...`, because
  chapter 13 already uses flat verbs (`lock`, `vendor`).
- **Counter-hypothesis 2: reuse Go's tools for the Go backend.** `go tool nm/objdump/pprof/trace` already work on
  binaries of the Go backend. Chosen for D01-D03, D11-D17 (Reuse/Exclude) plus `//line` directives (T-1152). Not valid for the native
  backend (phase 7), where Égide must provide its own symbol and profile story.
- **Scope risk (extrapolated).** 36 new tasks on top of three phase-6 epics (T-0090..T-0092) concentrate on one
  role (tooling-engineer owns 31 of them). Phase-6 exit criteria only require daily VS Code use and reproducible builds;
  anything beyond is a stretch. See the waves in section 2.
- **Blind spot found in the spec.** The rule "no network access in `egide build` when the lockfile and cache are complete"
  exists only in the tooling-engineer role file, not in spec chapters 10 or 13. ADR-0019 proposes to make it a rule.
- **Blind spot found on the board.** Commands that spec chapters already cite but no task covered: `egide test`
  (TOOL-030/031), `egide audit` (cited in ch. 3, 5, 8, 11, 12), `egide expand` (CT-060), `egide explain`, the
  VS Code extension of roadmap phase 6, `egide lock` and `egide vendor` (only inside epic T-0092).
- **Premise caveat.** "All the tools of Go" is an unbounded set once the ecosystem is included (delve, benchstat,
  goimports, ...). This plan bounds it to the standard distribution plus the tools the Go project maintains and that the owner named; the
  debugger is the notable omission (follow-up: DAP adapter after T-1152; not created, outside the 1120..1159 plan).

## 2. Recommendations / Next Steps

1. **Owner decision** on ADR-0019 (Proposed, branch `adr/toolchain-parity` is not needed: the file is a new Proposed ADR
   allowed by AGENTS.md rule 6) and on Q-0040..Q-0045. T-1121 turns the accepted ADR into spec text.
2. **Waves** (suggested; extrapolated):
   - Wave 0, not gated by the ADR: T-1122 (test runner core, phase 2), T-1146 (`expand`), T-1147 (`explain`), T-1131 (audit core), T-1138, T-1152.
   - Wave 1, after T-1121: command surface of the package manager (T-1133..T-1136, T-1139..T-1142), T-1154, T-1155.
   - Wave 2, needs a backend: T-1126, T-1127, T-1128, T-1129, T-1137, T-1140, T-1153.
   - Wave 3, stretch: T-1130 (fuzz), T-1132 (vulnerabilities), T-1145 (workspaces), T-1148, T-1149, T-1151.
3. **Not planned (no task in the phase <= 6 range):** `egide test --trace`, `--sanitize`, PGO (phase 7); a debugger
   adapter; registry service and hosted documentation (no role owns them).
4. **Open question for the owner:** who builds and operates the registry (PKG-060), the vulnerability database
   snapshot and hosted docs? Without an owner T-1132 and T-1151 cannot finish.
5. Re-verify every `M` row against upstream documentation when network access to go.dev is available.

### 2.1 Task list

| Task | Title | Role | Phase | Depends on | Kind |
|------|-------|------|-------|------------|------|
| T-1121 | Spec 13 and 10 amendment for toolchain parity (ADR-0019) | language-architect | 6 | - | task |
| T-1122 | `egide test`: @test functions, doctests, @property | tooling-engineer | 2 | T-0019, T-0031, T-0034 | task |
| T-1123 | `egide test`: fake capabilities and `--integration` | tooling-engineer | 4 | T-1122, T-0070 | task |
| T-1124 | `egide test`: selection flags, JSON events, sound result cache | tooling-engineer | 6 | T-1122, T-1121 | task |
| T-1125 | `egide test --cover` and `egide cover` reports | tooling-engineer | 6 | T-1122, T-1121 | task |
| T-1126 | Coverage of compiled binaries and `egide cover merge` | tooling-engineer | 6 | T-1125, T-0081 | task |
| T-1127 | `egide bench` | tooling-engineer | 6 | T-0081, T-1122, T-1121 | task |
| T-1128 | `--cpuprofile` / `--memprofile` in test and bench | tooling-engineer | 6 | T-1127, T-1152 | task |
| T-1129 | `egide test --race` for Go-backend programs with Go interop or unsafe: blocked by ADR-0024 (E0708), to be re-planned | tooling-engineer | 6 | T-0081, T-1122, T-1121 | task |
| T-1130 | Coverage-guided `egide test --fuzz` | tooling-engineer | 6 | T-1125, T-1122, T-1121 | task |
| T-1131 | `egide audit`: breaches, trust points, overrides, JSON | tooling-engineer | 6 | T-0092, T-1039 | task |
| T-1132 | `egide audit`: known vulnerabilities with reachability | tooling-engineer | 6 | T-1131, T-0083, T-1121 | task |
| T-1133 | `egide new` and `egide init` | tooling-engineer | 6 | T-0019, T-1121 | task |
| T-1134 | `egide add`, `egide remove`, `egide update` | tooling-engineer | 6 | T-0092, T-1121 | task |
| T-1135 | `egide why` and `egide graph` | tooling-engineer | 6 | T-0092, T-1121 | task |
| T-1136 | `egide fetch` and `egide verify` | tooling-engineer | 6 | T-0092, T-1121 | task |
| T-1137 | `egide verify --artifact`: rebuild and compare | tooling-engineer | 6 | T-1136, T-0081 | task |
| T-1138 | Unused and undeclared dependency diagnostics; lock pruning | tooling-engineer | 6 | T-0092, T-0030 | task |
| T-1139 | `egide list [--json]` | tooling-engineer | 6 | T-0030, T-1121 | task |
| T-1140 | `egide install PKG@VERSION` | tooling-engineer | 6 | T-0092, T-0081, T-1121 | task |
| T-1141 | `egide version [-m]` and `egide env` | tooling-engineer | 6 | T-0019, T-0081, T-1121 | task |
| T-1142 | `egide clean` and `egide bug` | tooling-engineer | 6 | T-0019, T-1121 | task |
| T-1143 | `egide doc`: terminal and static HTML | tooling-engineer | 6 | T-1036, T-0030, T-1039, T-1040, T-1121 | task |
| T-1144 | `egide fix`: suggested fixes, edition migration, modernisation | tooling-engineer | 6 | T-0090, T-1121 | task |
| T-1145 | Workspaces: local multi-package development | tooling-engineer | 6 | T-0092, T-1121 | epic |
| T-1146 | `egide expand` | comptime-engineer | 2 | T-0019, T-0054 | task |
| T-1147 | `egide explain E0123` | tooling-engineer | 1 | T-0019 | task |
| T-1148 | LSP: symbols, implementation, call hierarchy, signature help, semantic tokens | tooling-engineer | 6 | T-0091 | task |
| T-1149 | LSP: manifest, breach and vulnerability diagnostics, test code lenses | tooling-engineer | 6 | T-0091, T-1131, T-1122 | task |
| T-1150 | VS Code extension | tooling-engineer | 6 | T-0091, T-0090 | task |
| T-1151 | `egide publish` and `egide yank` | tooling-engineer | 6 | T-0092, T-1121 | epic |
| T-1152 | Go backend emits //line directives and debug mapping | go-backend-engineer | 6 | T-0081 | task |
| T-1153 | `egide build`: output path, emit, verbose, JSON, conditional compilation | tooling-engineer | 6 | T-0081, T-1121 | task |
| T-1154 | `egide fmt`: --diff, stdin, error reporting | tooling-engineer | 6 | T-0090, T-1121 | task |
| T-1155 | CLI conformance: help, exit codes, JSON flags | test-engineer | 6 | T-0019, T-1121 | task |
| T-1156 | CI check that the parity table matches the task board | release-manager | 6 | T-1121 | task |

Existing tasks referenced, not duplicated: T-0019 (CLI), T-0030, T-0031, T-0034, T-0036 (`run`), T-0054, T-0070,
T-0081, T-0082, T-0083, T-0090 (`fmt`), T-0091 (LSP), T-0092 (package manager), T-1036, T-1039, T-1040.
Spec questions: Q-0040 conditional compilation, Q-0041 private registries and trust roots, Q-0042 network use,
telemetry and compiler pinning, Q-0043 workspaces and overrides, Q-0044 `@bench`/`@fuzz`, Q-0045 C FFI mechanism.
