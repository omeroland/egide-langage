# 13. Toolchain

**One executable, `egide`, covers the Python experience (try, script) and the Go experience (ship a binary).**

| Command | Purpose | Engine |
|---------|---------|--------|
| `egide` | typed REPL | interpreter |
| `egide run file.egd [args]` | run a script or package | interpreter |
| `egide build [--backend go\|native] [--target os-arch] [--sandbox] [--sbom]` | static binary | compiler |
| `egide check` | parse, resolve, type-check only | frontend |
| `egide test` | unit tests, doctests, property tests | interpreter |
| `egide fmt [--check]` | canonical formatting | frontend |
| `egide lock`, `egide vendor` | resolve and lock dependencies | package manager |
| `egide audit` | list breaches and trust points, known vulnerabilities | frontend |
| `egide expand` | show comptime-generated code | frontend |
| `egide lsp` | language server | frontend |
| `egide explain E0123` | long explanation of a diagnostic | — |
| `egide lex`, `egide parse` | debugging: print tokens / AST (unstable output) | frontend |

## 13.1 Execution modes

- **[TOOL-010]** The REPL, `egide run` and `egide test` use the bytecode interpreter that also evaluates `comptime`
  code (CT-005). Semantics MUST be identical to compiled code (INT-020); only performance differs. The interpreter has
  no Go interface in any mode (CT-006). Therefore `egide run` and `egide test` of a program whose package closure uses
  `import go` do not use it: they build the program with the Go backend under GO-046 and execute the result, and
  INT-020 does not apply to them (it excludes Go interop). The REPL rejects `import go` (E0612).
- **[TOOL-011] Scripts.** A single `.egd` file without manifest can be run with `egide run`. It may declare dependencies
  in a leading comment block, resolved and locked into a cache keyed by the file's content hash:

```egide
#!/usr/bin/env egide run
# requires: egide.k8s = "1.2"
module script

fn main(sys: Sys) -> Result[(), Error]:
    let k = k8s.client(sys.net, kubeconfig: sys.fs.home(mode: Read).sub(".kube"))?
    for ns in k.namespaces(label: "tenant")?:
        print(f"{ns.name}: {ns.quota.cpu}")
```

- **[TOOL-012]** Scripts follow all language rules, including capabilities.

## 13.2 Formatting

- **[TOOL-020]** `egide fmt` has no options. Its output is a fixed point: formatting formatted code changes nothing.
  Maximum line width is 100 columns; indentation is 4 spaces.

## 13.3 Testing

- **[TOOL-030]** `egide test` runs functions annotated `@test` (signature `fn() -> Result[(), E]` or `fn()`), doctests
  from `##` comments (LEX-011) and property tests (functions annotated `@property` whose parameters have generators derived via `@derive(Arbitrary)`).
- **[TOOL-031]** Tests receive fake capabilities only (CAP-060) unless annotated `@integration`, which receives a real
  `Sys` and runs only with `egide test --integration`.

## 13.4 Diagnostics

- **[TOOL-040]** Every diagnostic has: a stable code (`E0001`… errors, `W0001`… warnings), a primary source span, a
  one-line message, the spec rule it enforces, optional secondary spans and notes, and, when possible, a suggested fix
  as a machine-applicable edit. The catalogue is [`docs/diagnostics.md`](../docs/diagnostics.md).
- **[TOOL-041]** Security diagnostics state the risk avoided, e.g.:
  `E0412: Untrusted[str] passed to Cmd — risk: command injection. Validate the input into a type (Hostname.parse) or use cmd"ping {h}".`
- **[TOOL-042]** `--error-format=json` emits one JSON object per diagnostic (schema in `docs/diagnostics.md`), used by
  the LSP and by AI agents.

## 13.5 Language server

- **[TOOL-050]** `egide lsp` implements LSP 3.17: diagnostics, hover with types and `using` clauses, go to definition,
  references, rename, completion, formatting, code actions from suggested fixes, inlay hints for inferred types.
