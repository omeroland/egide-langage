# Égide

**Égide** (French for *aegis*, file extension `.egd`) is a statically typed, secure-by-default programming language.
It combines the readability of Python, the operational simplicity of Go and the guarantees of Rust — without a borrow checker.

> Status: **pre-alpha, specification phase.** Nothing here is usable yet. The compiler is being built by a team of AI agents
> coordinated through this repository (see [`AGENTS.md`](AGENTS.md)).

```egide
module api.tenants

import std.http.{Server, Request, Response, Status}
import egide.pg.{Pool}

type TenantId = new int where self > 0

pub fn main(sys: Sys) -> Result[(), Error]:
    let password = sys.secrets.file("/var/run/secrets/db/password")?   # Secret[str]
    let db = Pool.connect(sys.net.client(hosts: ["pg.internal"], ports: [5432]),
                          user: "api", password: password)?
    given db:
        Server(sys.net.listen(":8443")?).get("/tenants/{id}", get_tenant).serve()

fn get_tenant(req: Request) -> Response using db: Pool:
    let Ok(id) = TenantId.parse(req.param("id")) else: return Response(Status.BadRequest)
    match db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}"):
        case Ok(Some(t)): Response.json(t)
        case Ok(None): Response(Status.NotFound)
        case Err(_): Response(Status.InternalError)
```

## The five structural decisions

| # | Decision | Spec |
|---|----------|------|
| 1 | **Mutable value semantics** — no shared mutable references, no lifetimes, no visible GC | [spec/05](spec/05-values-and-memory.md) |
| 2 | **Object capabilities are the only source of authority** — no ambient I/O; `using` clauses act as an effect system | [spec/06](spec/06-capabilities.md) |
| 3 | **Structured lightweight tasks without function colouring** | [spec/07](spec/07-concurrency.md) |
| 4 | **`comptime` is the only metaprogramming** — no macros, builds can never do I/O | [spec/09](spec/09-comptime.md) |
| 5 | **One tool, three modes** — REPL, script, static binary | [spec/13](spec/13-toolchain.md) |

Taint tracking, secrets, safe SQL/HTML/commands are **library types**, made unforgeable by decisions 2 and 4.

## Repository map

| Path | Content |
|------|---------|
| [`spec/`](spec/) | The normative language specification. Source of truth. |
| [`docs/`](docs/) | Architecture, roadmap, testing strategy, diagnostics catalogue, ADRs |
| [`agents/`](agents/) | Operating manual for the AI agent team (protocol, definition of done, reviews) |
| [`.claude/`](.claude/) | Claude Code sub-agent roles, slash commands, settings and hooks |
| [`tasks/`](tasks/) | File-based task board (backlog → in-progress → done) |
| [`compiler/`](compiler/) | `egidec`, the bootstrap compiler, written in OCaml 5 |
| [`runtime/go/`](runtime/go/) | Go support runtime used by the Go backend |
| [`stdlib/`](stdlib/) | The Égide standard library (written in Égide) |
| [`tests/`](tests/) | Conformance suite (run-pass, compile-fail, diagnostics) |
| [`examples/`](examples/) | Example programs, kept compiling by CI once the compiler can |

## Building

Requirements: OCaml ≥ 5.2 with opam, Go ≥ 1.25 (for the Go backend and runtime).

```sh
opam install . --deps-only --with-test
make build      # dune build
make test       # unit tests + conformance suite
make fmt        # ocamlformat + gofmt
```

## Licence

Apache License 2.0 — see [LICENSE](LICENSE).
