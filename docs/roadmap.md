# Roadmap

Phases are sequential **gates**: a phase starts when the previous phase's exit criteria are met and verified by the
`release-manager` role. Inside a phase, tasks run in parallel according to their dependencies (`tasks/`).

| Phase | Name | Scope | Exit criteria (all required) |
|-------|------|-------|------------------------------|
| 0 | Foundations | repo, CI, source/span, diagnostics, lexer + layout, Menhir parser for the full grammar, AST printer, `egide lex/parse`, conformance runner | every `spec/grammar` production has a parse test; all `egide` code blocks in `spec/` parse; lexer fuzzed 1 h without crash; CI green |
| 1 | Interpreted core | name resolution, basic types (`int`, `bool`, `str`, functions, structs, enums), `match`, bytecode interpreter, REPL, `egide run` | examples of spec ch. 3 run in the REPL; 150+ conformance tests |
| 2 | Type system | generics, traits, `Result`/`?`, `Option`, exhaustiveness, newtypes and validated types, `comptime`, derive, templates `f""` | type-checker suite ≥ 300 cases green; spec ch. 4 and 9 fully covered by rule-tagged tests |
| 3 | Values and resources | copy-on-write collections, `inout`, `take`, exclusivity, moves, `with`, `defer`, resources, `Shared`/`Weak` | corpus of exclusivity/move/resource violations 100 % rejected; no false positive on `examples/` |
| 4 | Capabilities and security library | `Sys`, attenuation, `using`/`given`, purity, `Untrusted`, `Secret`, `sql`/`html`/`cmd`/`url`/`path`/`re` templates, crypto defaults | `examples/tenants_api.egd` type-checks; its dangerous variants (`tests/security/`) all rejected; red-team review passed |
| 5 | Go backend and concurrency | MIR, Go code generation, `runtime/go`, scopes, channels, cancellation, `import go`, purity list v1 (T-0040), call-graph analysis | a tenant operator runs against a test OpenShift/Kubernetes cluster; interpreter and Go backend agree on the whole conformance suite |
| 6 | Ecosystem | `egide fmt`, LSP, package manager, lockfile with Sigstore, MVS, SBOM, `audit`, `vendor`, VS Code extension | daily use in VS Code; reproducible builds verified in CI (two builds, same hash) |
| 7 | Native backend | C backend, Perceus RC, ORC cycle collector, M:N scheduler, `--sandbox` | conformance suite green on both backends; within 1.5× of Go on `bench/`; no leak under `--leaks` on the suite |
| 8 | Self-hosting | `egidec` rewritten in Égide | the compiler compiles itself to a fixed point (stage 2 = stage 3 byte for byte) |

## Milestone tags

`v0.1.0` = end of phase 2 (a usable interpreted language), `v0.5.0` = end of phase 5 (first compiled binaries),
`v1.0.0` = end of phase 7 + stability guarantee for edition 2027.
