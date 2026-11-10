# 3. Syntax

The complete grammar is in [`grammar/egide.ebnf`](grammar/egide.ebnf); this chapter explains it and states the rules
that a context-free grammar cannot express. `NEWLINE`, `INDENT` and `DEDENT` come from the layout algorithm (§2.4,
token contract LEX-036).

- **[SYN-005] Normative grammar.** The accepted language is the EBNF **plus** the checks stated in this chapter. A
  production marked COVER in the EBNF is parsed more liberally than the language it defines; the parser MUST reject
  the excess with the diagnostic named in the rule (SYN-012, SYN-017, SYN-033, SYN-037, SYN-065). The grammar is LR(1)
  and has no conflicts. Positive: `(a, b) => a + b`. Negative: `(a: int)` used as a value is E0107.

## 3.1 Files and modules

- **[SYN-001]** Every file starts (after an optional shebang, doc comment and blank lines) with `module path`, where
  `path` is a dotted `snake_case` name. The module path MUST match the file's location relative to the package root
  (`src/api/tenants.egd` → `module api.tenants`), except for scripts run with `egide run` (TOOL-011). The first segment
  of a module path MUST NOT be `go` (it would be unimportable, LEX-022): error E0116.
- **[SYN-002]** `import` declarations follow the module declaration and precede all other declarations:
  `import std.fmt`, `import std.http.{Server, Request}`, `import egide.pg as pg`,
  `import go "k8s.io/client-go/kubernetes" as kube` (GO-001). Wildcard imports do not exist. `as` applies only to a
  single path or a single item, never to a brace list: `import std.http.{Server, Request} as h` is a syntax error.
- **[SYN-003]** Top-level declarations: `fn`, `struct`, `enum`, `trait`, `impl`, `type` and `let` (a compile-time
  constant, implicitly `comptime`, CT-002, CAP-021; `comptime let` at top level is a syntax error, there is one
  spelling). Declarations are private to the module unless prefixed with `pub`; `pub(package)` makes an item visible to
  the package only (PKG-003). `package` is a contextual word: any other word in `pub( … )` is E0111. `pub` does not
  apply to `impl` (an impl has no visibility): `pub impl …` is a syntax error.
- **[SYN-004]** Declaration order at top level does not matter; declarations may be mutually recursive.

## 3.2 Blocks and statements

- **[SYN-010]** A block (`suite` in the EBNF) is either an indented sequence of statements (`:` `INDENT` … `DEDENT`)
  or a single-line block (`:` one single statement, SYN-061, LEX-033). An empty block is written `()`:
  `fn noop(): ()`.
- **[SYN-011]** Everything that can produce a value is an expression. The value of a block is the value of its last
  statement if that statement is an expression; otherwise the block has type `()`.
- **[SYN-012]** Statements:

| Statement | Form |
|-----------|------|
| Immutable binding | `let pattern [: Type] = expr` |
| Mutable binding | `var name [: Type] = expr` |
| Let-else | `let pattern = expr else: block` — the block MUST diverge (`return`, `break`, `continue`, `panic`) |
| Assignment | `place = expr`, `place op= expr` |
| Conditional | `if c: … elif c: … else: …` |
| Match | `match e:` followed by `case` arms (§3.5) |
| Loops | `for pattern in expr:`, `while c:`, `loop:`; `break`, `continue`; `break expr` only inside `loop` (SYN-016) |
| Resources | `with [name =] expr [, …]: block` (ERR-030) |
| Capabilities | `given expr [, …]: block` (CAP-031) |
| Cleanup | `defer expr` (ERR-035) |
| Generator | `yield expr` (only in functions returning `Iter[T]`, SYN-075) |
| Return | `return [expr]` |

The left-hand side of an assignment MUST be a place: a `var` binding, an `inout` parameter, `self` in a method whose
receiver is `inout self`, or a field `.f` or element `[i]` of a place. The parser reads any postfix expression and
checks this; anything else is E0106 "cannot assign to this expression". Positive: `self.count += 1` in
`fn bump(inout self)`. Negative: `f(x).y = 1`, `1 = x`.

- **[SYN-013]** `if` used as an expression MUST have an `else` branch, and all branches MUST have the same type.
- **[SYN-014]** An expression statement whose value is not `()` and not used is a compile-time error, except for the
  last statement of a block (which is the block's value). A `Result` can never be discarded implicitly (ERR-002).
- **[SYN-015] Block-ended expressions.** `if`/`elif`/`else`, `match`, `loop`, `with`, `given`, `unsafe` (SYN-017), a
  `fn` lambda (SYN-064) and a call with a trailing block (SYN-062) end with a block, so nothing can follow them on
  their logical line. A block-ended expression may appear only (a) as a statement, or (b) as the whole right-hand side
  of `let`, `var`, a top-level `let` or an assignment. Anywhere else (operand, argument, inside brackets, after
  `return`, `break`, `defer`, `yield`, as a lambda body) it is E0104 "this block-ended expression must stand alone;
  bind it with `let` first". For a two-way value inside an expression use `a if c else b` (SYN-035).

  ```egide
  let n = match c:          # OK: whole right-hand side of let
      case Red: 1
      case _: 0
  let m = 1 + match c:      # error E0104
      case Red: 1
      case _: 0
  ```
- **[SYN-016] `if` and `loop` values.** There is one `if` construct. An `if` without `else` has type `()` (SYN-013).
  `loop` is an expression whose value is given by `break expr` (`break` alone gives `()`); `break` with a value inside
  `for` or `while` is a compile-time error.
- **[SYN-017] `unsafe`.** `unsafe(reason: "…"): block` is a block-ended expression (SYN-015) whose value is the value
  of the block. The word before the string MUST be `reason` and the string MUST be a plain `"…"` literal (E0110).
  Because of SYN-015 an `unsafe` block always starts a line (or the right-hand side of one binding), so it is visible
  in review and to `egide audit`. What it permits, the non-empty reason, the manifest entry and the audit listing are
  MEM-070 and MEM-071 and are not restated here. Negative: `f(unsafe(reason: "x"): …)` is E0104.

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
  A function type used as a return type MUST be parenthesised (TYP-006).
- **[SYN-021]** Parameters have a passing mode: none (read, the default), `inout`, `take` or `comptime`
  (MEM-020 to MEM-023, CT-010). Methods take `self`, `inout self` or `take self` as first parameter. `self` is allowed
  only as the first parameter of a function declared in a `trait` or `impl`, and never with `comptime`; otherwise E0114.
- **[SYN-022]** Parameters may have default values. Default values MUST be compile-time evaluable.
- **[SYN-023]** Attributes start with `@` and precede a declaration: `@derive(Eq, Show)`, `@acyclic`, `@test`,
  `@go_threadsafe`. An attribute is written on its own line, directly above its target. The set of attributes is
  closed; an unknown attribute, or a known one on a target not listed below, is E0117:

  | Attribute | Target | Arguments | Rule |
  |-----------|--------|-----------|------|
  | `@derive(D, …)` | `struct`, `enum`, `type` | derivation names | CT-030 |
  | `@derivation` | `fn` | none | CT-030 |
  | `@template("p")` | `fn` | one string literal | CT-040 |
  | `@acyclic` | `struct`, `enum` | none | MEM-062 |
  | `@test`, `@integration` | `fn` | none | TOOL-030, TOOL-031 |
  | `@property` | `fn` | none | TOOL-030 |
  | `@go_threadsafe` | `type` alias of an imported Go type | none | GO-032 |
- **[SYN-024] Declaration forms.** `struct Name` (no fields) and `impl Trait for Type` (no items) may omit the `:` and
  the body; empty `enum`, `trait` and inherent `impl` bodies are errors. `where` is allowed only after `new`
  (TYP-031): `type A = int where self > 0` is a syntax error. Variant and constant names MUST start with an uppercase
  letter (E0113), which keeps patterns decidable (SYN-053); other naming rules stay warnings (LEX-023).

## 3.4 Expressions

- **[SYN-030] Calls.** `f(a, b, name: c)`. Positional arguments precede named ones. Named arguments may appear in any
  order. Explicit capability arguments, `using name: expr` (CAP-032), come last.
- **[SYN-031] Boolean arguments MUST be named** at call sites when the parameter type is `bool`:
  `send(msg, urgent: true)`. Passing a boolean positionally is a compile-time error.
- **[SYN-032] Construction.** A struct or variant is constructed by calling its name with named arguments:
  `Article(name: "pen", price: p)`. Positional construction is allowed only for single-field variants and tuples.
- **[SYN-033] Inout arguments.** An argument passed to an `inout` parameter is written `&place` (MEM-021). The
  operand of `&` MUST be a place (SYN-012), otherwise E0106 "cannot take `&` of this expression"; `&xs[i] + 1` and
  `&make()` are errors.
- **[SYN-034] Postfix `?`** propagates errors (ERR-010).
- **[SYN-035] Conditional expression.** `a if cond else b` (Python form).
- **[SYN-036] Chained comparisons.** `a < b <= c` means `a < b and b <= c`, with `b` evaluated once.
- **[SYN-037] Pipelines.** `x |> f(a)` is exactly `f(x, a)`; `x |> f` is `f(x)`. The right side MUST be a path or a
  call `callee(args)`, optionally followed by `?`; `x |> o.m(a)` is `o.m(x, a)` and `x |> c(a)?` is `c(x, a)?`. Any
  other right side (`x |> a + b`, `xs |> len == 0`, a lambda, a trailing block) is E0108 "the right side of `|>` must be
  a function or a call; parenthesise: `(xs |> len) == 0`". A piped value counts as a positional argument for SYN-031.
  Piping into an `inout` first parameter is an error: write `f(&x)`.
- **[SYN-038] Collection literals.** Lists `[1, 2]`, maps `{"a": 1}`, sets `{1, 2}`, tuples `(1, "a")`.
  `{}` is an empty map; an empty set is `Set()`. A one-element tuple is `(x,)`.
- **[SYN-039] Comprehensions.** `[e for p in xs if c]`, `{k: v for p in xs}`, `{e for p in xs}`; several `for` and `if`
  clauses may follow each other. A parenthesised comprehension `(e for p in xs)` is a lazy `Iter[T]`.
- **[SYN-040] Slices.** `xs[a..b]`, `xs[a..]`, `xs[..b]`, `xs[..]`. Negative bounds count from the end. Out-of-range
  bounds panic (MEM-040). `..=` requires an upper bound (`a..=` is a syntax error).
- **[SYN-041] Optional type sugar.** `T?` is `Option[T]`.
- **[SYN-042] Generic argument lists.** A postfix `[ a1, …, an ]` holds *generic arguments*. Each argument is an
  expression, or one of the type-only forms `fn(…) [-> T] [using …]` and `dyn B1 + … + Bn`. After name resolution: if
  the operand denotes a generic function, a generic type or a comptime type constructor, the arguments are type
  arguments or comptime value arguments (an argument that resolves to a type is a type, otherwise it is a comptime
  value, evaluated under CT-001..CT-004 and CAP-041); otherwise the operation is indexing, which takes exactly one
  argument, and a type-only form or a second argument is a compile-time error. Inside a generic argument a postfix `?`
  applied to a type is `Option` (SYN-041).

  ```egide
  let t = req.json[Tenant]()?                  # instantiation
  let m = decode[Map[str, List[int]]](raw)?    # nested
  let c = cache[Key, fn(int) -> int?]()        # type-only form; `int?` is Option[int]
  let x = xs[i]                                # indexing (xs is a value)
  let y = xs[i, j]                             # error: indexing takes one index
  ```
- **[SYN-043] Slices are indexing with a range.** `xs[a..b]`, `xs[a..]`, `xs[..b]` and `xs[..]` are indexing with a
  range expression (SYN-040). `..` has the precedence of SYN-100 level 10, so `xs[a < b .. c]` means `a < (b..c)`;
  write `xs[(a < b)..c]` for the other reading. There is no separate slice production.
- **[SYN-044] Types as comptime arguments.** Outside `[ … ]`, a type passed as an expression argument (`fields(T)`,
  CT-020) MUST be a path, optionally with generic arguments, or a tuple of such. Other type forms MUST first be named
  with `type F = …`.

## 3.5 Pattern matching

```egide
match shape:
    case Circle(radius: r) if r > 100.0: "large circle"
    case Circle(_): "circle"
    case Rect(w, h) | Square(w as h): f"{w}x{h}"
    case _: "other"
```

- **[SYN-050]** Patterns: literals (integer, float, duration, string, raw string, byte string, character, `true`,
  `false`), closed ranges (`1..=9`, `'a'..'z'`), `_`, bindings, constructor patterns with positional or named fields,
  tuple patterns, list patterns (`[first, ..rest]`), or-patterns (`p | q`) and `p as name`. Ranges in patterns always
  have both bounds. Positional sub-patterns are allowed where positional construction is (SYN-032); otherwise name
  the fields (`Circle(radius: r)`, `..` for the rest).
- **[SYN-051]** `match` MUST be exhaustive (TYP-060). Arms are tried in order; a guard (`if cond`) is evaluated only when
  the pattern matches.
- **[SYN-052]** All alternatives of an or-pattern MUST bind the same names with the same types.
- **[SYN-053] Pattern names.** The first character decides, so that the parser needs no name resolution. A pattern
  name that has two or more segments (`State.Available`, `http.NOT_FOUND`) or is followed by `( … )` denotes a variant,
  struct or constant and MUST resolve (an unknown name is an error, never a binding). A lone identifier that starts
  with an uppercase letter (`None`, `Available`, `MAX`) denotes a variant or constant and MUST resolve. A lone
  identifier that starts with a lowercase letter denotes a binding, and `_` is the wildcard. A dotted or constructor
  pattern whose last segment starts with a lowercase letter is E0112. Positive: `case None:` never
  binds, and `case State.Available:` matches that variant. Negative: `case State.available:` is E0112.

## 3.6 Lambdas and trailing blocks

- **[SYN-060] Short lambdas** are single expressions: `x => x * 2`, `(a, b) => a + b`, `() => now()`.
  Parameter types are inferred from the expected function type or annotated: `(x: int) => x`.
- **[SYN-061] Single-line blocks** after `:` contain exactly one single statement: an expression, an assignment,
  `return`, `break`, `continue`, `defer` or `yield`. A binding (`let`, `var`, `comptime let`) is E0109 "binding is
  immediately out of scope". A block-ended expression, `let … else` and `for`/`while` need an indented block
  (`if c: a else: b` on one line is a syntax error; use `a if c else b`).
- **[SYN-062] Trailing blocks.** A multi-line function literal is written **after** the closing parenthesis of a call
  (the last postfix operation before `fn` MUST be `( … )`), and may declare a return type, `f(a) fn(x) -> T:`:

  ```egide
  server.get("/health") fn(req):
      let ok = db.ping().is_ok()
      Response.json({"ok": ok})

  retry(attempts: 3, delay: 200.ms) fn:
      api.put("/tenants", json: t)
  ```

  `f(a, b) fn(x): block` is exactly `f(a, b, fn(x): block)`. `fn:` declares a lambda without parameters.
  At most one trailing block per call. A call with a trailing block is a block-ended expression (SYN-015).
- **[SYN-063]** `return` inside a lambda returns from the lambda, never from the enclosing function.
- **[SYN-064]** A multi-line function literal `fn(params) [-> T]: block` (or `fn: block`) is a block-ended expression
  (SYN-015): it may be the right-hand side of `let`, `var`, an assignment or a statement:
  `let handler = fn(req: Request) -> Response:` followed by an indented block.
- **[SYN-065] Parenthesised lambda heads.** The parser reads `( item, … )` where an item is `[inout | take] expr
  [: Type]`. If `=>` follows, every item MUST be a lambda parameter (`[mode] name [: Type]`), otherwise E0107
  "invalid lambda parameter". If `=>` does not follow, no item may have a mode or a `: Type` annotation (E0107
  "type annotation outside a lambda parameter list"). Positive: `(a, b) => a + b`, `(x: int) => x`. Negative:
  `let p = (a: int)`.

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
