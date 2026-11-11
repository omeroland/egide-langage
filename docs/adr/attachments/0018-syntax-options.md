# ADR-0018 annex: the same programs in four surface syntaxes

Companion of [ADR-0018](../0018-surface-syntax-familiarity.md). Status: Proposed. Nothing here is normative.

**Options.** D = status quo (ADR-0005, indentation). B = braces, TypeScript/Rust-shaped, Go-style line termination.
A = Go skin on B. C = ReasonML-shaped. Only the surface changes; semantics, keywords and the rules of ch. 4-12 are the
same in every column, except where a note says otherwise.

| | D (status quo) | B (braces) | A (Go skin) | C (Reason-shaped) |
|---|---|---|---|---|
| Blocks | `:` + indentation | `{ }` | `{ }` | `{ }` |
| Statement end | line break | line break, Go rule | line break, Go rule | `;` |
| Function | `fn f(x: T) -> R:` | `fn f(x: T) -> R {` | `func f(x T) R {` | `fn f(x: T): R => {` ... `};` |
| Conditional | `if c:` ... `elif c:` | `if c {` ... `} else if c {` | same as B | `if (c) {` ... `} else if (c) {` |
| Match | `match e:` + `case p:` | `match e {` + `case p:` | `switch e {` + `case p:` | `switch (e) {` + `\| p =>` |
| Multi-line lambda | trailing `f(a) fn(x):` | trailing `f(a) fn(x) {` | trailing `f(a) func(x: T) {` | `f(a, (x) => { ... })` |
| Comments | `#` | `#` | `#` | `#` (Reason has `//` and `/* */`; not adopted) |

Rules the rewrites follow, so that a reader can check them:

- **B**: a NEWLINE token ends a physical line when its last token is an identifier, a literal, `true`, `false`, `self`,
  `Self`, `return`, `break`, `continue`, `)`, `]`, `}` or `?`, unless the next line starts with `.`, `|>`, `and`, `or`, `)`, `]` or `}`
  (Go's rule, plus the method-chain continuation that LEX-030 already has, plus "no NEWLINE before a closer" so that
  a call or literal closed on its own line needs no trailing comma). `{` MUST be on the line of its header
  (`else` MUST follow `}` on the same line). The last statement before `}` needs no terminator, so `if c { return 1 }`
  is one line. `case` arms hold a statement list. Open-ended ranges (`a..`) only inside `[ ]` or `( )`.
- **A**: B plus `func`, `switch`, and `name Type` in parameters, fields, variant fields, `using` entries and generic
  bounds (`[T Ord]`), no `->`. Lambda heads keep `(x: T) => e` (see the ADR: `(x T) => e` is a grammar conflict).
- **C**: `;` separates statements, `if`/`for`/`while`/`switch` heads are parenthesised, variants start with `|`, records
  are `{ a: T, b: U }`, guards are `when (g)`, lambdas with blocks are `(x) => { ... }` and are passed inside the
  parentheses. No bitwise `|`, no set literals, no `{}` map literal (the four concessions of the ADR). SYN-030
  (positional arguments before named ones) would have to be relaxed for `retry(attempts: 3, () => { ... })`.

## 1. Constructs, one by one

### 1.1 `match`

```text
# D
match s:
    case Circle(radius: r) if r > 100.0: 0.0
    case Rect(w, h): w * h
    case Empty: 0.0
```

```text
# B
match s {
    case Circle(radius: r) if r > 100.0: 0.0
    case Rect(w, h): w * h
    case Empty: 0.0
}
```

```text
# A
switch s {
case Circle(radius: r) if r > 100.0: 0.0
case Rect(w, h): w * h
case Empty: 0.0
}
```

```text
# C
switch (s) {
| Circle(radius: r) when (r > 100.0) => 0.0
| Rect(w, h) => w * h
| Empty => 0.0
}
```

### 1.2 `inout` and `take`

```text
# D
fn add_item(inout cart: Cart, take item: Item) -> Result[(), Error]:
    cart.items.push(item)
    Ok(())

add_item(&cart, Item(name: "pen", cents: 150))?
```

```text
# B
fn add_item(inout cart: Cart, take item: Item) -> Result[(), Error] {
    cart.items.push(item)
    Ok(())
}

add_item(&cart, Item(name: "pen", cents: 150))?
```

```text
# A
func add_item(inout cart Cart, take item Item) Result[(), Error] {
    cart.items.push(item)
    Ok(())
}

add_item(&cart, Item(name: "pen", cents: 150))?
```

```text
# C
fn add_item(inout cart: Cart, take item: Item): Result[(), Error] => {
  cart.items.push(item);
  Ok(())
};

add_item(&cart, Item(name: "pen", cents: 150))?;
```

### 1.3 `using` and `given`

```text
# D
fn get_tenant(req: Request) -> Response using db: Pool, log: Log:
    ...

given db, sys.log.json(level: Info):
    Server(sys.net.listen(":8443")?, tls: tls).serve()
```

```text
# B
fn get_tenant(req: Request) -> Response using db: Pool, log: Log {
    ...
}

given db, sys.log.json(level: Info) {
    Server(sys.net.listen(":8443")?, tls: tls).serve()
}
```

```text
# A
func get_tenant(req Request) Response using db Pool, log Log {
    ...
}

given db, sys.log.json(level: Info) {
    Server(sys.net.listen(":8443")?, tls: tls).serve()
}
```

```text
# C
fn get_tenant(req: Request): Response using db: Pool, log: Log => {
  ...
};

given db, sys.log.json(level: Info) {
  Server(sys.net.listen(":8443")?, tls: tls).serve()
};
```

### 1.4 `with` and `defer`

```text
# D
with f = dir.open(name)?:
    defer log.info(f"closed {name}")
    f.read_all()?
```

```text
# B and A
with f = dir.open(name)? {
    defer log.info(f"closed {name}")
    f.read_all()?
}
```

```text
# C
with f = dir.open(name)? {
  defer log.info(f"closed {name}");
  f.read_all()?
}
```

### 1.5 `Result`, `?` and let-else

```text
# D
let Ok(id) = TenantId.parse(req.param("id")) else: return Response(Status.BadRequest)
```

```text
# B and A
let Ok(id) = TenantId.parse(req.param("id")) else { return Response(Status.BadRequest) }
```

```text
# C
let Ok(id) = TenantId.parse(req.param("id")) else { return Response(Status.BadRequest) };
```

`?` is the same postfix operator in all four. (Reason has no `?`; its error handling is `switch` or a `let%` ppx. The
column C keeps `?` and `return`, which Reason does not have either: see the ADR, risk "C is not Reason".)

### 1.6 Trailing block

```text
# D
retry(attempts: 3, delay: 200.ms) fn:
    api.put("/tenants", json: t)
```

```text
# B
retry(attempts: 3, delay: 200.ms) fn {
    api.put("/tenants", json: t)
}
```

```text
# A
retry(attempts: 3, delay: 200.ms) func {
    api.put("/tenants", json: t)
}
```

```text
# C (no trailing blocks in Reason; the lambda is an argument)
retry(attempts: 3, delay: 200.ms, () => {
  api.put("/tenants", json: t)
});
```

### 1.7 Templates, `import go`, `comptime`, `unsafe`, discard

These forms contain no block and are the same in all four options, except for the terminating `;` in C and the block
around the last four:

```text
# template, import go (D, B, A; C adds `;`)
match db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}") ...
type TeamName = new str where re"^[a-z][a-z0-9-]{{2,62}}$".matches(self)
import go "k8s.io/client-go/kubernetes" as kube
```

```text
# comptime
# D                                          # B (A: func, C: => { })
fn shifted(comptime n: int, x: int) -> int:  fn shifted(comptime n: int, x: int) -> int {
    comptime let mask = (1 << n) - 1             comptime let mask = (1 << n) - 1
    x & mask                                     x & mask
                                             }
```

```text
# unsafe(reason:)
# D
unsafe(reason: "length checked by caller"):
    xs.get_unchecked(0)
# B, A, C
unsafe(reason: "length checked by caller") {
    xs.get_unchecked(0)
}
```

```text
# ERR-002 discard: the same line rule in all four
let _ = audit(c)  # ignored: best effort
```

## 2. Complete programs (machine-checked)

`python3 -I docs/adr/attachments/0018-check.py` tokenises each block below (`name=` in the info string) with the lexer
rule of its option and asks `menhir --interpret` on the matching grammar. All eight are ACCEPT. `d_tenants` is
`examples/tenants_api.egd` verbatim.

Size (lines / characters): tour D 85 / 2302, B 106 / 2409, A 106 / 2362, C 99 / 2303; tenants D 44 / 1670, B 51 / 1709,
A 51 / 1687, C 47 / 1612.

### 2.1 Feature tour

#### D (D, status quo (indentation))

```text name=d_tour
# phase: 5
## Feature tour used by ADR-0018 to compare surface syntaxes (not a conformance test).
module examples.tour

import std.http.{Server, Request, Response, Status}
import go "strings" as strings

let MAX_ITEMS = 64

enum Shape:
    Circle(radius: float)
    Rect(w: float, h: float)
    Empty

@derive(Eq, Show)
struct Item:
    name: str
    cents: int

struct Cart:
    owner: str
    items: List[Item]

type Cents = new int where self >= 0

fn largest[T: Ord](xs: List[T]) -> Option[T]:
    xs.iter().max()

fn area(s: Shape) -> float:
    match s:
        case Circle(radius: r) if r > 100.0: 0.0
        case Circle(radius: r): 3.14159 * r * r
        case Rect(w, h): w * h
        case Empty: 0.0

fn bucket(cents: int) -> str:
    if cents < 100:
        "small"
    elif cents < 1000:
        "medium"
    else:
        "large"

fn add_item(inout cart: Cart, take item: Item) -> Result[(), Error]:
    if cart.items.len() >= MAX_ITEMS:
        return Err(Error("cart full"))
    cart.items.push(item)
    Ok(())

fn load(dir: Dir[Read], name: str) -> Result[Cart, Error] using log: Log:
    with f = dir.open(name)?:
        defer log.info(f"closed {name}")
        let Ok(cart) = f.read_json[Cart]() else: return Err(Error("bad cart"))
        Ok(cart)

fn upper(s: str) -> str using go: Go:
    strings.ToUpper(s)

fn first_raw(xs: List[int]) -> int:
    unsafe(reason: "length checked by caller"):
        xs.get_unchecked(0)

fn shifted(comptime n: int, x: int) -> int:
    comptime let mask = (1 << n) - 1
    x & mask

fn index(items: List[Item]) -> Map[str, int]:
    {i.name: i.cents for i in items}

fn cheap(items: List[Item]) -> List[Item]:
    items
        |> filter(i => i.cents < 500)
        |> sorted_by(i => i.name)

pub fn main(sys: Sys) -> Result[(), Error]:
    var cart = Cart(owner: "ana", items: [])
    add_item(&cart, Item(name: "pen", cents: 150))?
    let dir = sys.fs.dir("/data", mode: Read)?
    given sys.log.json(level: Info):
        let c = load(dir, "cart.json")?
        let _ = audit(c)  # ignored: best effort
        retry(attempts: 3, delay: 200.ms) fn:
            sys.net.client(hosts: ["pay.internal"], ports: [443]).post("/pay", json: c)
        print(f"{c.owner}: {c.items.len()} items, area {area(Shape.Circle(radius: 2.0))}")
    Ok(())
```

#### B (B, braces)

```text name=b_tour
# phase: 5
## Feature tour used by ADR-0018 to compare surface syntaxes (not a conformance test).
module examples.tour

import std.http.{Server, Request, Response, Status}
import go "strings" as strings

let MAX_ITEMS = 64

enum Shape {
    Circle(radius: float)
    Rect(w: float, h: float)
    Empty
}

@derive(Eq, Show)
struct Item {
    name: str
    cents: int
}

struct Cart {
    owner: str
    items: List[Item]
}

type Cents = new int where self >= 0

fn largest[T: Ord](xs: List[T]) -> Option[T] {
    xs.iter().max()
}

fn area(s: Shape) -> float {
    match s {
        case Circle(radius: r) if r > 100.0: 0.0
        case Circle(radius: r): 3.14159 * r * r
        case Rect(w, h): w * h
        case Empty: 0.0
    }
}

fn bucket(cents: int) -> str {
    if cents < 100 {
        "small"
    } else if cents < 1000 {
        "medium"
    } else {
        "large"
    }
}

fn add_item(inout cart: Cart, take item: Item) -> Result[(), Error] {
    if cart.items.len() >= MAX_ITEMS {
        return Err(Error("cart full"))
    }
    cart.items.push(item)
    Ok(())
}

fn load(dir: Dir[Read], name: str) -> Result[Cart, Error] using log: Log {
    with f = dir.open(name)? {
        defer log.info(f"closed {name}")
        let Ok(cart) = f.read_json[Cart]() else { return Err(Error("bad cart")) }
        Ok(cart)
    }
}

fn upper(s: str) -> str using go: Go {
    strings.ToUpper(s)
}

fn first_raw(xs: List[int]) -> int {
    unsafe(reason: "length checked by caller") {
        xs.get_unchecked(0)
    }
}

fn shifted(comptime n: int, x: int) -> int {
    comptime let mask = (1 << n) - 1
    x & mask
}

fn index(items: List[Item]) -> Map[str, int] {
    {i.name: i.cents for i in items}
}

fn cheap(items: List[Item]) -> List[Item] {
    items
        |> filter(i => i.cents < 500)
        |> sorted_by(i => i.name)
}

pub fn main(sys: Sys) -> Result[(), Error] {
    var cart = Cart(owner: "ana", items: [])
    add_item(&cart, Item(name: "pen", cents: 150))?
    let dir = sys.fs.dir("/data", mode: Read)?
    given sys.log.json(level: Info) {
        let c = load(dir, "cart.json")?
        let _ = audit(c)  # ignored: best effort
        retry(attempts: 3, delay: 200.ms) fn {
            sys.net.client(hosts: ["pay.internal"], ports: [443]).post("/pay", json: c)
        }
        print(f"{c.owner}: {c.items.len()} items, area {area(Shape.Circle(radius: 2.0))}")
    }
    Ok(())
}
```

#### A (A, Go skin)

```text name=a_tour
# phase: 5
## Feature tour used by ADR-0018 to compare surface syntaxes (not a conformance test).
module examples.tour

import std.http.{Server, Request, Response, Status}
import go "strings" as strings

let MAX_ITEMS = 64

enum Shape {
    Circle(radius float)
    Rect(w float, h float)
    Empty
}

@derive(Eq, Show)
struct Item {
    name  str
    cents int
}

struct Cart {
    owner str
    items List[Item]
}

type Cents = new int where self >= 0

func largest[T Ord](xs List[T]) Option[T] {
    xs.iter().max()
}

func area(s Shape) float {
    switch s {
    case Circle(radius: r) if r > 100.0: 0.0
    case Circle(radius: r): 3.14159 * r * r
    case Rect(w, h): w * h
    case Empty: 0.0
    }
}

func bucket(cents int) str {
    if cents < 100 {
        "small"
    } else if cents < 1000 {
        "medium"
    } else {
        "large"
    }
}

func add_item(inout cart Cart, take item Item) Result[(), Error] {
    if cart.items.len() >= MAX_ITEMS {
        return Err(Error("cart full"))
    }
    cart.items.push(item)
    Ok(())
}

func load(dir Dir[Read], name str) Result[Cart, Error] using log Log {
    with f = dir.open(name)? {
        defer log.info(f"closed {name}")
        let Ok(cart) = f.read_json[Cart]() else { return Err(Error("bad cart")) }
        Ok(cart)
    }
}

func upper(s str) str using go Go {
    strings.ToUpper(s)
}

func first_raw(xs List[int]) int {
    unsafe(reason: "length checked by caller") {
        xs.get_unchecked(0)
    }
}

func shifted(comptime n int, x int) int {
    comptime let mask = (1 << n) - 1
    x & mask
}

func index(items List[Item]) Map[str, int] {
    {i.name: i.cents for i in items}
}

func cheap(items List[Item]) List[Item] {
    items
        |> filter(i => i.cents < 500)
        |> sorted_by(i => i.name)
}

pub func main(sys Sys) Result[(), Error] {
    var cart = Cart(owner: "ana", items: [])
    add_item(&cart, Item(name: "pen", cents: 150))?
    let dir = sys.fs.dir("/data", mode: Read)?
    given sys.log.json(level: Info) {
        let c = load(dir, "cart.json")?
        let _ = audit(c)  # ignored: best effort
        retry(attempts: 3, delay: 200.ms) func {
            sys.net.client(hosts: ["pay.internal"], ports: [443]).post("/pay", json: c)
        }
        print(f"{c.owner}: {c.items.len()} items, area {area(Shape.Circle(radius: 2.0))}")
    }
    Ok(())
}
```

#### C (C, Reason-shaped)

```text name=c_tour
# phase: 5
## Feature tour used by ADR-0018 to compare surface syntaxes (not a conformance test).
module examples.tour;

import std.http.{Server, Request, Response, Status};
import go "strings" as strings;

let MAX_ITEMS = 64;

type Shape =
  | Circle(radius: float)
  | Rect(w: float, h: float)
  | Empty;

@derive(Eq, Show)
type Item = {name: str, cents: int};

type Cart = {owner: str, items: List[Item]};

type Cents = new int where self >= 0;

fn largest[T: Ord](xs: List[T]): Option[T] => {
  xs.iter().max()
};

fn area(s: Shape): float => {
  switch (s) {
  | Circle(radius: r) when (r > 100.0) => 0.0
  | Circle(radius: r) => 3.14159 * r * r
  | Rect(w, h) => w * h
  | Empty => 0.0
  }
};

fn bucket(cents: int): str => {
  if (cents < 100) {
    "small"
  } else if (cents < 1000) {
    "medium"
  } else {
    "large"
  }
};

fn add_item(inout cart: Cart, take item: Item): Result[(), Error] => {
  if (cart.items.len() >= MAX_ITEMS) {
    return Err(Error("cart full"));
  };
  cart.items.push(item);
  Ok(())
};

fn load(dir: Dir[Read], name: str): Result[Cart, Error] using log: Log => {
  with f = dir.open(name)? {
    defer log.info(f"closed {name}");
    let Ok(cart) = f.read_json[Cart]() else { return Err(Error("bad cart")) };
    Ok(cart)
  }
};

fn upper(s: str): str using go: Go => {
  strings.ToUpper(s)
};

fn first_raw(xs: List[int]): int => {
  unsafe(reason: "length checked by caller") {
    xs.get_unchecked(0)
  }
};

fn shifted(comptime n: int, x: int): int => {
  comptime let mask = (1 << n) - 1;
  x & mask
};

fn index(items: List[Item]): Map[str, int] => {
  {i.name: i.cents for i in items}
};

fn cheap(items: List[Item]): List[Item] => {
  items
    |> filter(i => i.cents < 500)
    |> sorted_by(i => i.name)
};

pub fn main(sys: Sys): Result[(), Error] => {
  var cart = Cart(owner: "ana", items: []);
  add_item(&cart, Item(name: "pen", cents: 150))?;
  let dir = sys.fs.dir("/data", mode: Read)?;
  given sys.log.json(level: Info) {
    let c = load(dir, "cart.json")?;
    let _ = audit(c);  # ignored: best effort
    retry(attempts: 3, delay: 200.ms, () => {
      sys.net.client(hosts: ["pay.internal"], ports: [443]).post("/pay", json: c)
    });
    print(f"{c.owner}: {c.items.len()} items, area {area(Shape.Circle(radius: 2.0))}")
  };
  Ok(())
};
```

### 2.2 `examples/tenants_api.egd`

#### D (D, status quo (indentation))

```text name=d_tenants
# phase: 5
## HTTP API reading a secret, querying PostgreSQL and validating its inputs (spec ch. 6, 12).
module examples.tenants_api

import std.http.{Server, Request, Response, Status}
import egide.pg.{Pool}

@derive(Json)
struct Tenant:
    id: TenantId
    team: TeamName
    cpu_quota_m: int

type TenantId = new int where self > 0
type TeamName = new str where re"^[a-z][a-z0-9-]{{2,62}}$".matches(self)

pub fn main(sys: Sys) -> Result[(), Error]:
    let password = sys.secrets.file("/var/run/secrets/db/password")?
    let db = Pool.connect(
        sys.net.client(hosts: ["pg.internal"], ports: [5432]),
        user: "api",
        password: password,
    )?
    let tls = sys.fs.dir("/etc/tls", mode: Read)?
    given db, sys.log.json(level: Info):
        Server(sys.net.listen(":8443")?, tls: tls)
            .get("/tenants/{id}", get_tenant)
            .post("/tenants", create_tenant)
            .serve()

fn get_tenant(req: Request) -> Response using db: Pool, log: Log:
    let Ok(id) = TenantId.parse(req.param("id")) else: return Response(Status.BadRequest)
    match db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}"):
        case Ok(Some(t)): Response.json(t)
        case Ok(None): Response(Status.NotFound)
        case Err(e):
            log.error("reading tenant", err: e)
            Response(Status.InternalError)

fn create_tenant(req: Request) -> Response using db: Pool:
    let Ok(t) = req.json[Tenant]() else: return Response(Status.BadRequest)
    match db.exec(sql"INSERT INTO tenants VALUES ({t.id}, {t.team}, {t.cpu_quota_m})"):
        case Ok(_): Response(Status.Created)
        case Err(_): Response(Status.Conflict)
```

#### B (B, braces)

```text name=b_tenants
# phase: 5
## HTTP API reading a secret, querying PostgreSQL and validating its inputs (spec ch. 6, 12).
module examples.tenants_api

import std.http.{Server, Request, Response, Status}
import egide.pg.{Pool}

@derive(Json)
struct Tenant {
    id: TenantId
    team: TeamName
    cpu_quota_m: int
}

type TenantId = new int where self > 0
type TeamName = new str where re"^[a-z][a-z0-9-]{{2,62}}$".matches(self)

pub fn main(sys: Sys) -> Result[(), Error] {
    let password = sys.secrets.file("/var/run/secrets/db/password")?
    let db = Pool.connect(
        sys.net.client(hosts: ["pg.internal"], ports: [5432]),
        user: "api",
        password: password,
    )?
    let tls = sys.fs.dir("/etc/tls", mode: Read)?
    given db, sys.log.json(level: Info) {
        Server(sys.net.listen(":8443")?, tls: tls)
            .get("/tenants/{id}", get_tenant)
            .post("/tenants", create_tenant)
            .serve()
    }
}

fn get_tenant(req: Request) -> Response using db: Pool, log: Log {
    let Ok(id) = TenantId.parse(req.param("id")) else { return Response(Status.BadRequest) }
    match db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}") {
        case Ok(Some(t)): Response.json(t)
        case Ok(None): Response(Status.NotFound)
        case Err(e):
            log.error("reading tenant", err: e)
            Response(Status.InternalError)
    }
}

fn create_tenant(req: Request) -> Response using db: Pool {
    let Ok(t) = req.json[Tenant]() else { return Response(Status.BadRequest) }
    match db.exec(sql"INSERT INTO tenants VALUES ({t.id}, {t.team}, {t.cpu_quota_m})") {
        case Ok(_): Response(Status.Created)
        case Err(_): Response(Status.Conflict)
    }
}
```

#### A (A, Go skin)

```text name=a_tenants
# phase: 5
## HTTP API reading a secret, querying PostgreSQL and validating its inputs (spec ch. 6, 12).
module examples.tenants_api

import std.http.{Server, Request, Response, Status}
import egide.pg.{Pool}

@derive(Json)
struct Tenant {
    id          TenantId
    team        TeamName
    cpu_quota_m int
}

type TenantId = new int where self > 0
type TeamName = new str where re"^[a-z][a-z0-9-]{{2,62}}$".matches(self)

pub func main(sys Sys) Result[(), Error] {
    let password = sys.secrets.file("/var/run/secrets/db/password")?
    let db = Pool.connect(
        sys.net.client(hosts: ["pg.internal"], ports: [5432]),
        user: "api",
        password: password,
    )?
    let tls = sys.fs.dir("/etc/tls", mode: Read)?
    given db, sys.log.json(level: Info) {
        Server(sys.net.listen(":8443")?, tls: tls)
            .get("/tenants/{id}", get_tenant)
            .post("/tenants", create_tenant)
            .serve()
    }
}

func get_tenant(req Request) Response using db Pool, log Log {
    let Ok(id) = TenantId.parse(req.param("id")) else { return Response(Status.BadRequest) }
    switch db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}") {
    case Ok(Some(t)): Response.json(t)
    case Ok(None): Response(Status.NotFound)
    case Err(e):
        log.error("reading tenant", err: e)
        Response(Status.InternalError)
    }
}

func create_tenant(req Request) Response using db Pool {
    let Ok(t) = req.json[Tenant]() else { return Response(Status.BadRequest) }
    switch db.exec(sql"INSERT INTO tenants VALUES ({t.id}, {t.team}, {t.cpu_quota_m})") {
    case Ok(_): Response(Status.Created)
    case Err(_): Response(Status.Conflict)
    }
}
```

#### C (C, Reason-shaped)

```text name=c_tenants
# phase: 5
## HTTP API reading a secret, querying PostgreSQL and validating its inputs (spec ch. 6, 12).
module examples.tenants_api;

import std.http.{Server, Request, Response, Status};
import egide.pg.{Pool};

@derive(Json)
type Tenant = {id: TenantId, team: TeamName, cpu_quota_m: int};

type TenantId = new int where self > 0;
type TeamName = new str where re"^[a-z][a-z0-9-]{{2,62}}$".matches(self);

pub fn main(sys: Sys): Result[(), Error] => {
  let password = sys.secrets.file("/var/run/secrets/db/password")?;
  let db = Pool.connect(
    sys.net.client(hosts: ["pg.internal"], ports: [5432]),
    user: "api",
    password: password,
  )?;
  let tls = sys.fs.dir("/etc/tls", mode: Read)?;
  given db, sys.log.json(level: Info) {
    Server(sys.net.listen(":8443")?, tls: tls)
      .get("/tenants/{id}", get_tenant)
      .post("/tenants", create_tenant)
      .serve()
  }
};

fn get_tenant(req: Request): Response using db: Pool, log: Log => {
  let Ok(id) = TenantId.parse(req.param("id")) else { return Response(Status.BadRequest) };
  switch (db.one[Tenant](sql"SELECT * FROM tenants WHERE id = {id}")) {
  | Ok(Some(t)) => Response.json(t)
  | Ok(None) => Response(Status.NotFound)
  | Err(e) =>
    log.error("reading tenant", err: e);
    Response(Status.InternalError)
  }
};

fn create_tenant(req: Request): Response using db: Pool => {
  let Ok(t) = req.json[Tenant]() else { return Response(Status.BadRequest) };
  switch (db.exec(sql"INSERT INTO tenants VALUES ({t.id}, {t.team}, {t.cpu_quota_m})")) {
  | Ok(_) => Response(Status.Created)
  | Err(_) => Response(Status.Conflict)
  }
};
```
