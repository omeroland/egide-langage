# 3. Syntax

The complete grammar is in [`grammar/egide.ebnf`](grammar/egide.ebnf); this chapter explains it and states the rules
that a context-free grammar cannot express. `NEWLINE`, `INDENT` and `DEDENT` come from the layout algorithm (§2.4).

## 3.1 Files and modules

- **[SYN-001]** Every file starts (after an optional shebang, doc comment and blank lines) with `module path`, where
  `path` is a dotted `snake_case` name. The module path MUST match the file's location relative to the package root
  (`src/api/tenants.egd` → `module api.tenants`), except for scripts run with `egide run` (TOOL-011).
- **[SYN-002]** `import` declarations follow the module declaration and precede all other declarations:
  `import std.fmt`, `import std.http.{Server, Request}`, `import egide.pg as pg`,
  `import go "k8s.io/client-go/kubernetes" as kube` (GO-001). Wildcard imports do not exist.
- **[SYN-003]** Top-level declarations: `fn`, `struct`, `enum`, `trait`, `impl`, `type`, `let` (compile-time constant,
  CAP-021) and `comptime let`. Declarations are private to the module unless prefixed with `pub`.
- **[SYN-004]** Declaration order at top level does not matter; declarations may be mutually recursive.

## 3.2 Blocks and statements

- **[SYN-010]** A block is either an indented sequence of statements (`: NEWLINE INDENT … DEDENT`) or a single-line
  block (`: simple_statement`, LEX-033).
- **[SYN-011]** Everything that can produce a value is an expression. The value of a block is the value of its last
  statement if that statement is an expression; otherwise the block has type `()`.
- **[SYN-012]** Statements:

| Statement | Form |
|-----------|------|
| Immutable binding | `let pattern [: Type] = expr` |
| Mutable binding | `var name [: Type] = expr` |
| Let-else | `let pattern = expr else: block` — the block MUST diverge (`return`, `break`, `continue`, `panic`) |
| Assignment | `place = expr`, `place op= expr` (only on `var` bindings, `inout` parameters and their fields/elements) |
| Conditional | `if c: … elif c: … else: …` |
| Match | `match e:` followed by `case` arms (§3.5) |
| Loops | `for pattern in expr:`, `while c:`, `loop:`; `break [expr]`, `continue` |
| Resources | `with [name =] expr [, …]: block` (ERR-030) |
| Capabilities | `given expr [, …]: block` (CAP-031) |
| Cleanup | `defer expr` (ERR-035) |
| Generator | `yield expr` (only in functions returning `Iter[T]`, SYN-075) |
| Return | `return [expr]` |

- **[SYN-013]** `if` used as an expression MUST have an `else` branch, and all branches MUST have the same type.
- **[SYN-014]** An expression statement whose value is not `()` and not used is a compile-time error, except for the
  last statement of a block (which is the block's value). A `Result` can never be discarded implicitly (ERR-002).

## 3.3 Declarations

```egide
pub struct Article:
    name: str
    price: Money
    stock: int = 0                  # default value

pub enum State:
    Available
    OutOfStock
    Discontinued(reason: str)

pub trait Display:
    fn display(self) -> str

impl Display for Article:
    fn display(self) -> str:
        f"{self.name} ({self.stock})"

type UserId = new int                               # newtype (TYP-030)
type Port = new u16 where 1 <= self <= 65535        # validated type (TYP-031)
type Headers = Map[str, List[str]]                  # transparent alias
```

- **[SYN-020]** A function declaration is
  `fn name[generics](params) [-> Type] [using capabilities]: block`. The return type may be omitted only when it is `()`.
- **[SYN-021]** Parameters have a passing mode: none (read, the default), `inout`, `take` or `comptime`
  (MEM-020 to MEM-023, CT-010). Methods take `self`, `inout self` or `take self` as first parameter.
- **[SYN-022]** Parameters may have default values. Default values MUST be compile-time evaluable.
- **[SYN-023]** Attributes start with `@` and precede a declaration: `@derive(Eq, Show)`, `@acyclic`, `@test`,
  `@go_threadsafe`. The set of attributes is closed and defined by this specification; unknown attributes are errors.

## 3.4 Expressions

- **[SYN-030] Calls.** `f(a, b, name: c)`. Positional arguments precede named ones. Named arguments may appear in any
  order.
- **[SYN-031] Boolean arguments MUST be named** at call sites when the parameter type is `bool`:
  `send(msg, urgent: true)`. Passing a boolean positionally is a compile-time error.
- **[SYN-032] Construction.** A struct or variant is constructed by calling its name with named arguments:
  `Article(name: "pen", price: p)`. Positional construction is allowed only for single-field variants and tuples.
- **[SYN-033] Inout arguments.** An argument passed to an `inout` parameter is written `&place` (MEM-021).
- **[SYN-034] Postfix `?`** propagates errors (ERR-010).
- **[SYN-035] Conditional expression.** `a if cond else b` (Python form).
- **[SYN-036] Chained comparisons.** `a < b <= c` means `a < b and b <= c`, with `b` evaluated once.
- **[SYN-037] Pipelines.** `x |> f(a)` is exactly `f(x, a)`; `x |> f` is `f(x)`.
- **[SYN-038] Collection literals.** Lists `[1, 2]`, maps `{"a": 1}`, sets `{1, 2}`, tuples `(1, "a")`.
  `{}` is an empty map; an empty set is `Set()`. A one-element tuple is `(x,)`.
- **[SYN-039] Comprehensions.** `[e for p in xs if c]`, `{k: v for p in xs}`, `{e for p in xs}`; several `for` and `if`
  clauses may follow each other. A parenthesised comprehension `(e for p in xs)` is a lazy `Iter[T]`.
- **[SYN-040] Slices.** `xs[a..b]`, `xs[a..]`, `xs[..b]`, `xs[..]`. Negative bounds count from the end. Out-of-range
  bounds panic (MEM-040).
- **[SYN-041] Optional type sugar.** `T?` is `Option[T]`.

## 3.5 Pattern matching

```egide
match shape:
    case Circle(radius: r) if r > 100.0: "large circle"
    case Circle(_): "circle"
    case Rect(w, h) | Square(w as h): f"{w}x{h}"
    case _: "other"
```

- **[SYN-050]** Patterns: literals, ranges (`1..=9`), `_`, bindings, constructor patterns with positional or named
  fields, tuple patterns, list patterns (`[first, ..rest]`), or-patterns (`p | q`) and `p as name`.
- **[SYN-051]** `match` MUST be exhaustive (TYP-060). Arms are tried in order; a guard (`if cond`) is evaluated only when
  the pattern matches.
- **[SYN-052]** All alternatives of an or-pattern MUST bind the same names with the same types.

## 3.6 Lambdas and trailing blocks

- **[SYN-060] Short lambdas** are single expressions: `x => x * 2`, `(a, b) => a + b`, `() => now()`.
  Parameter types are inferred from the expected function type or annotated: `(x: int) => x`.
- **[SYN-061] Single-line blocks** after `:` contain exactly one simple statement (expression, `return`, `break`,
  `continue`, assignment, `let`).
- **[SYN-062] Trailing blocks.** A multi-line function literal is written **after** the closing parenthesis of a call:

  ```egide
  server.get("/health") fn(req):
      let ok = db.ping().is_ok()
      Response.json({"ok": ok})

  retry(attempts: 3, delay: 200.ms) fn:
      api.put("/tenants", json: t)
  ```

  `f(a, b) fn(x): block` is exactly `f(a, b, fn(x): block)`. `fn:` declares a lambda without parameters.
  At most one trailing block per call.
- **[SYN-063]** `return` inside a lambda returns from the lambda, never from the enclosing function.
- **[SYN-064]** A multi-line function literal MAY also appear as the right-hand side of `let`:
  `let handler = fn(req: Request) -> Response:` followed by an indented block.

## 3.7 Generators

- **[SYN-075]** A function whose declared return type is `Iter[T]` and whose body contains `yield` is a generator.
  Calling it returns a lazy iterator; the body runs until the next `yield` each time a value is requested.

## 3.8 Operator precedence

**[SYN-100]** From highest to lowest:

| Level | Operators | Associativity |
|-------|-----------|---------------|
| 1 | call `()`, index `[]`, field `.`, `?` | left |
| 2 | `**` | right |
| 3 | unary `-`, `~` | prefix |
| 4 | `*` `/` `%` | left |
| 5 | `+` `-` | left |
| 6 | `<<` `>>` | left |
| 7 | `&` | left |
| 8 | `^` | left |
| 9 | `\|` | left |
| 10 | `..` `..=` | none |
| 11 | `==` `!=` `<` `<=` `>` `>=` | chained (SYN-036) |
| 12 | `not` | prefix |
| 13 | `and` | left |
| 14 | `or` | left |
| 15 | `a if c else b` | right |
| 16 | `\|>` | left |
| 17 | `=>` (lambda) | right |

- **[SYN-101]** Mixing `&`, `^`, `|` with comparison operators without parentheses is a compile-time error
  ("add parentheses"), avoiding the classic C precedence trap.
