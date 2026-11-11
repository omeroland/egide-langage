# 4. Types

## 4.1 Type system overview

- **[TYP-001]** Égide is statically and nominally typed. Two named types are equal only if they are the same
  declaration (with equal type arguments). Transparent aliases (`type A = B` without `new`) are the only exception.
- **[TYP-002]** Type inference is **local**: types of `let`/`var` bindings, lambda parameters and generic arguments are
  inferred within a function body using bidirectional type checking. Function signatures are never inferred.
- **[TYP-003]** Signatures of `pub` items MUST be fully annotated, including the return type (unless `()`) and the
  `using` clause (CAP-030).
- **[TYP-004]** There is no `null`, no `nil`, no `None` outside `Option`. Absence is `Option[T]`, written `T?`.
- **[TYP-005]** There are no implicit conversions of any kind, including between numeric types. Conversions are
  explicit method calls: `x.to_i64()`, `u8.try_from(x)?`, `f64.from(x)`.

## 4.2 Primitive types

| Type | Description |
|------|-------------|
| `bool` | `true` / `false` |
| `int` | 64-bit signed integer — **the default integer type** of integer literals |
| `i8` `i16` `i32` `i64` `i128` | signed fixed-width integers |
| `u8` `u16` `u32` `u64` `u128` | unsigned fixed-width integers |
| `f32` `f64` | IEEE-754 floats; `f64` is the default type of float literals |
| `char` | a Unicode scalar value |
| `str` | an immutable UTF-8 string (value type, cheap to copy, MEM-010) |
| `Bytes` | an immutable byte string |
| `()` | the unit type |
| `Never` | the type of diverging expressions (`return`, `panic`, infinite `loop`) |

- **[TYP-006] Type syntax disambiguation.** `(T)` is `T`; a one-element tuple type is `(T,)` (as `(x,)` in SYN-038).
  In a return type, `?` binds to the nearest type: `fn() -> int?` returns `Option[int]`; an optional function type is
  `(fn() -> int)?`. A function type used as a return type MUST be parenthesised:
  `fn f() -> (fn(int) -> int) using log: Log:`; the unparenthesised form is E0105 "parenthesise a function type used
  as a return type". A function type with several `using` capabilities joins them with `+`:
  `fn(Config) using Client + Log`.

- **[TYP-010] Integer overflow.** `+ - * ** <<` and unary `-` on integer types panic on overflow **in all build
  modes**. Explicit alternatives: `wrapping_add`, `checked_add` (→ `T?`), `saturating_add`, and the same for the
  other operators. Division by zero panics. `int.MIN / -1` panics.
- **[TYP-011]** `usize` does not exist; lengths and indices are `int`. A negative index panics except in slices
  (SYN-040).
- **[TYP-012]** Floats never convert silently; `f64` comparison with `==` is allowed, but `Eq`/`Hash` are not
  implemented for floats (use `total_cmp` or the `Ordered[f64]` wrapper).

## 4.3 Composite types

- **[TYP-020] Structs** are product types with named fields. Field defaults are compile-time evaluable.
- **[TYP-021] Enums** are sum types. Variants may carry positional or named fields. There is no implicit integer
  representation; `@derive(Ordinal)` provides one when needed.
- **[TYP-022] Tuples** `(A, B)` are anonymous product types. Anonymous structs do not exist.
- **[TYP-023] Standard generic types** (defined in `std`, known to the compiler): `Option[T]`, `Result[T, E]`,
  `List[T]`, `Map[K, V]` (insertion-ordered), `Set[T]`, `Array[T, n]` (fixed size, `n` comptime), `Iter[T]`,
  `Chan[T]`, `Shared[T]`, `Weak[T]`, `Mutex[T]`, `RwLock[T]`, `Atomic[T]`.

## 4.4 Newtypes and validated types

- **[TYP-030] Newtypes.** `type UserId = new int` declares a distinct type with the same representation and zero
  runtime cost. It has no operations except those derived or implemented explicitly; conversion uses
  `UserId(42)` and `id.value`.
- **[TYP-031] Validated types.** `type Port = new u16 where <predicate on self>` declares a newtype with an invariant.
  The predicate MUST be a pure expression (CAP-040) of type `bool` and is evaluated at compile time for literals, so it cannot reach Go code (CT-006, E0611), directly or through helpers.
  - `Port.parse(x)` returns `Result[Port, ValidationError]`; it is the only runtime constructor.
  - A literal assigned to a validated type is checked at compile time: `let p: Port = 0` is a compile-time error.
  - Construction via `Port(x)` without validation requires `unsafe`.
- **[TYP-032]** A validated type's invariant is assumed everywhere the type appears; it is not re-checked.

## 4.5 Traits and generics

- **[TYP-040] Traits** declare method signatures, optional default implementations and associated types.
- **[TYP-041] Coherence.** An `impl Trait for Type` is allowed only in the module tree of the package that defines
  `Trait` or `Type` (orphan rule). Overlapping implementations are errors.
- **[TYP-042] Generics** are monomorphised. Bounds are traits: `fn max[T: Ord](a: T, b: T) -> T`.
- **[TYP-043] `dyn Trait`** is an explicit runtime-polymorphic value (a vtable pair). Only object-safe traits
  (no generic methods, no `Self` in argument position except the receiver) can be used with `dyn`.
- **[TYP-044] Operator traits.** `Add`, `Sub`, `Mul`, `Div`, `Rem`, `Neg`, `Index`, `Eq`, `Ord`, `Hash` are the only
  overloadable operators. Implementations MUST respect the documented laws (e.g. `Eq` is an equivalence); the
  standard library property tests (`std.testing.laws`) check them for derived and std types.
- **[TYP-045] Marker traits** inferred by the compiler: `Send` (may cross a task boundary, CON-020) and
  `Resource` (must be closed, cannot be implicitly copied, ERR-030). There is no `Copy` trait: every non-resource
  value can be copied, because copies are logical (MEM-010).

## 4.6 Derivation

- **[TYP-050]** `@derive(Eq, Hash, Ord, Show, Json, Default, Ordinal)` generates trait implementations by calling
  `comptime` derivation functions defined in `std.derive` (CT-030). Users may write their own derivation functions.

## 4.7 Exhaustiveness and reachability

- **[TYP-060]** A `match` MUST cover all values of the scrutinee type. The compiler reports the missing patterns
  (with an example value) in the diagnostic.
- **[TYP-061]** An unreachable `case` arm is a compile-time error.
- **[TYP-062]** `let` with a refutable pattern MUST use the `else` form (SYN-012, ERR-012); `let … else` with an irrefutable pattern is an error (the `else` could never run).

## 4.8 Type inference details

- **[TYP-070]** Integer literals default to `int`, float literals to `f64`, unless the expected type says otherwise.
- **[TYP-071]** Empty collection literals need an expected type: `let xs: List[int] = []`.
- **[TYP-072]** A lambda's parameter types are taken from the expected function type; without one, they MUST be
  annotated.
