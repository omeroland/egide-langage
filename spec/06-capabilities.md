# 6. Capabilities

**Égide code can act on the outside world only through a capability it was given** (ADR-0003). There is no global
function to open a file, reach the network, read the environment, start a process, read the clock, get randomness or
write to standard output.

## 6.1 Capability types

- **[CAP-001]** The capability types are defined in `std.cap`:

| Capability | Grants | Typical attenuations |
|------------|--------|----------------------|
| `Sys` | everything below; received only by `main` | — |
| `Fs` | file-system roots | `fs.dir(path, mode: Read)` → `Dir[Read]` |
| `Dir[M]` (`M` = `Read`, `ReadWrite`) | files under one root directory | `dir.sub("logs")`, `dir.read_only()` |
| `Net` | network access | `net.client(hosts: […], ports: […])` → `Client`; `net.listen(addr)` → `Listener` |
| `Client` | outbound connections to an allow-list | `client.only(hosts: […])` |
| `Env` | environment variables and `argv` | `env.only(["HOME", "KUBECONFIG"])` |
| `Proc` | starting processes | `proc.only(["/usr/bin/git"])` |
| `Clock` | wall clock and monotonic time, timers | — |
| `Rand` | cryptographic randomness | — |
| `Stdout`, `Stderr`, `Stdin` | standard streams | — |
| `Log` | structured logging sink | `log.with(field: value)` |
| `Secrets` | secret sources (files, Vault, env) | `secrets.only(paths: […])` |
| `Go` | calling impure Go code (GO-010) | — |

- **[CAP-002] Unforgeable.** Capability types have no public constructor. Only the runtime creates them, once, for
  `main`. Constructing one outside `std` requires `unsafe` (intended for test doubles, see CAP-060).
- **[CAP-003] Attenuation only.** Every method that derives a capability from another MUST return a capability whose
  authority is a subset of the original's. No API may amplify authority.
- **[CAP-004] Confinement of paths.** `Dir[M]` resolves paths without ever leaving its root: absolute paths, `..`
  components that escape the root and symbolic links pointing outside the root are rejected
  (equivalent to `openat2` with `RESOLVE_BENEATH`).
- **[CAP-005] Network allow-lists.** A `Client` connects only to its allowed hosts and ports. Unless listed explicitly,
  private, loopback and link-local addresses — including cloud metadata endpoints such as `169.254.169.254` — are
  refused, **after** DNS resolution (defeats DNS rebinding).

## 6.2 The entry point

- **[CAP-010]** A program's entry point is `pub fn main(sys: Sys) -> Result[(), E]` where `E: Display`.
  If `main` returns `Err(e)`, the runtime prints `e` to stderr and exits with status 1.
- **[CAP-011]** Before calling `main`, the runtime provides `sys.stdout` and `sys.stderr` as implicit capabilities
  (`given`, CAP-031) for the body of `main` so that `print` works in `main` without ceremony. Other functions that print
  MUST declare `using out: Stdout`.

## 6.3 No ambient authority

- **[CAP-020]** The standard library MUST NOT expose any function that performs I/O without a capability argument or
  `using` clause.
- **[CAP-021]** There are no mutable global variables. Top-level `let` declarations MUST be compile-time evaluable and
  are immutable. Consequently a capability can never be stored globally.
- **[CAP-022]** Capabilities are ordinary values: they can be stored in structs, captured by lambdas and sent to tasks.
  Authority therefore follows the data flow of the program, visibly.

## 6.4 `using` and `given`: implicit capabilities

Passing capabilities through deep call chains is noisy; `using` makes them implicit **but still visible in signatures**.

```egide decls
fn sync(cfg: Config) -> Result[(), Error] using api: Client, log: Log:
    log.info(f"syncing {cfg.tenants.len()} tenants")
    for t in cfg.tenants:
        api.put(f"/tenants/{t.id}", json: t)?

pub fn main(sys: Sys) -> Result[(), Error]:
    let api = sys.net.client(hosts: ["api.internal"], ports: [443])
    given api, sys.log.json(level: Info):
        sync(load_config()?)
```

- **[CAP-030]** A `using` clause declares named implicit parameters whose types MUST be capability types or types that
  contain capabilities (e.g. a `Pool` holding a `Client`).
- **[CAP-031]** A call to a function with `using p: T` is well-typed only if a value of type `T` is **in implicit scope**
  at the call site: either a `using` parameter of the enclosing function with a compatible type, or a value introduced
  by an enclosing `given` block. If several candidates match, the innermost wins; ambiguity at the same level is an
  error. Implicit resolution never searches globals or imports.
- **[CAP-032]** Explicit override: `sync(cfg, using api: other_client)`.
- **[CAP-033]** `using` clauses are part of the function type: `fn(Config) -> () using Client`. A lambda that uses an
  implicit capability captures it at creation time.
- **[CAP-034]** For private functions, the compiler MAY infer the `using` clause; `pub` functions MUST declare it
  (TYP-003). A dependency update that adds a `using` requirement to a public function therefore breaks the build
  instead of silently gaining authority.

## 6.5 Purity

- **[CAP-040]** A function is **pure** if it has no capability parameter, no `using` clause, does not call `unsafe` or
  impure Go code, and all functions it calls are pure (lambda arguments excepted: they are evaluated with the caller's
  authority). A pure function cannot perform I/O and, given equal arguments, returns equal results except for
  panics.
- **[CAP-041]** Only pure functions may run at compile time (CT-001) and in validated-type predicates (TYP-031).

## 6.6 Operating-system sandbox

- **[CAP-050]** `egide build --sandbox` derives, from the capability kinds that `main` can distribute (a static
  over-approximation computed by the compiler), an OS policy applied at process start: Landlock rules and a seccomp
  filter on Linux; `pledge`/`unveil` on OpenBSD. A program that never distributes `Proc` cannot call `execve`,
  even through a memory-safety bug in foreign code.
- **[CAP-051]** The sandbox is defence in depth; the language guarantees (CAP-001 to CAP-041) do not depend on it.

## 6.7 Testing

- **[CAP-060]** `std.testing` provides fake capabilities (in-memory `Dir`, recording `Client`, fixed `Clock`, seeded
  `Rand`) usable only from `@test` functions and from packages declaring `allow = ["test-capabilities"]`.
