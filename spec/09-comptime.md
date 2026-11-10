# 9. Compile-time evaluation

**The only metaprogramming in Égide is running ordinary Égide code during compilation** (ADR-0004). There are no
macros. Compile-time code receives no capability, so no build can touch the network or the disk.

## 9.1 Evaluation

- **[CT-001]** Any pure function (CAP-040) can be evaluated at compile time. Impure functions cannot.
- **[CT-002]** `comptime let NAME = expr` evaluates `expr` at compile time. Top-level `let` is implicitly `comptime`
  (CAP-021). A top-level `let` initialiser and every `comptime` argument are evaluated under CAP-040: they MUST NOT
  contain `unsafe`, `given`, `with`, a call to an impure function or a value of a capability type (E0610).
- **[CT-003]** Compile-time evaluation is **deterministic** and **bounded**: each top-level evaluation has a budget of
  10⁸ interpreter steps and 1 GiB of memory by default (configurable per package, PKG-012). Exceeding it is a
  compile-time error that shows the evaluation stack.
- **[CT-004]** A panic during compile-time evaluation is a compile-time error pointing at the comptime call site and the
  panic location.
- **[CT-005]** The compile-time interpreter is the same engine that runs the REPL and `egide run` (TOOL-010).

## 9.2 Comptime parameters and types as values

- **[CT-010]** A `comptime` parameter's argument MUST be compile-time evaluable. The function is specialised per
  distinct argument value.
- **[CT-011]** Types are values only in comptime argument positions: generic arguments (SYN-042) and the arguments of
  `std.meta` functions (SYN-044, CT-020). There is no type of types in the syntax and no function returns a type. A
  parametric type is a generic declaration whose parameters may be `comptime` values; it is instantiated like any
  generic type:

```egide decls
struct Buffer[comptime n: int]:
    data: Array[u8, n]
    len: int

let b: Buffer[4096] = Buffer()
```

- **[CT-012]** Types are declared only by `struct`, `enum` and `type`. Anonymous struct and enum declarations do not
  exist (TYP-022); a generic declaration (CT-011) is the way to build a type from compile-time values.

## 9.3 Compile-time reflection

- **[CT-020]** `std.meta` provides read-only compile-time reflection: `fields(T)`, `variants(T)`, `name(T)`,
  `attributes(T)`, `implements(T, Trait)`. It is unavailable at run time; there is no run-time reflection.

## 9.4 Derivation

- **[CT-030]** `@derive(D, …)` on a declaration calls, for each `D`, the comptime function `std.derive.D` (or a
  user-defined function annotated `@derivation`) with the reflected type; the function returns implementation items
  that the compiler type-checks as if written by hand.

## 9.5 Templates

- **[CT-040]** A `TEMPLATE` token `p"…"` (LEX-055) is desugared to a call to the comptime function registered for
  prefix `p` with the literal parts as written (raw, LEX-055; as `comptime List[str]`) and the interpolated expressions (as run-time arguments).
  The function returns an expression of the template's result type. Registration uses `@template("p")` on a comptime
  function; a package may register prefixes only for its own module tree unless it is `std`. The standard prefixes
  (CT-041) are reserved: `@template` of one of them outside `std` is E0602. The expansion is type-checked as if
  written by hand and has no extra privilege: SEC-017 binds template functions too.
- **[CT-041]** Standard prefixes: `f` (formatted `str`, format specifiers checked at compile time), `sql` (`Sql`),
  `html` (`Html`, context-aware escaping), `cmd` (`Cmd`), `url` (`Url`), `path` (`Path`), `re` (`Regex`, compiled and
  validated at compile time). Their security semantics are defined in chapter 12. The sink prefixes (`sql`, `html`,
  `cmd`, `url`, `path`) reject a `:spec` in an interpolation (LEX-055, E0601).
- **[CT-042]** There are no dynamic format strings: formatting functions accept only `f"…"` templates or explicit
  builders.

## 9.6 Embedding files

- **[CT-050]** `embed("path")` reads a file at compile time. The path MUST match an `[embed]` pattern of the package
  manifest (PKG-013); the file's SHA-256 is recorded in `egide.lock`.

## 9.7 Inspection

- **[CT-060]** `egide expand <file>` prints the code produced by derivations and templates.
