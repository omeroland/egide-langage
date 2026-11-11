# 5. Values and memory

**Every variable holds an independent value; references can be neither stored nor returned.** This single rule —
*mutable value semantics*, as in Swift and Hylo — provides Rust's memory safety and data-race freedom with no
lifetime annotations (ADR-0002).

## 5.1 Value semantics

- **[MEM-001]** Assignment, parameter passing (in the default mode), returning, capturing in a lambda and storing in a
  collection all behave as **logical copies**: after `var b = a`, mutating `b` never changes `a` and vice versa.
- **[MEM-002]** There is no address-of operator, no pointer type and no way to observe the identity of a value, except
  for `Shared[T]` (MEM-050) and `GoRef[T]` (GO-032).
- **[MEM-003]** Values of every type are values in this sense, including `List`, `Map`, `str` and user structs.

```egide fragment
var a = [1, 2, 3]
var b = a            # logically a copy; physically shared (copy-on-write)
b.push(4)            # the physical copy happens here, because `a` is still alive
assert(a == [1, 2, 3])
```

## 5.2 Implementation contract

- **[MEM-010]** Implementations MUST make logical copies cheap: heap-backed values are shared and copied lazily on the
  first mutation while shared (copy-on-write). A mutation of a uniquely referenced value MUST happen in place.
- **[MEM-011]** Programs cannot observe when memory is reclaimed. Resources are never released by memory reclamation;
  they are closed by `with` or `take` (ERR-030).

## 5.3 Parameter passing modes

| Mode | Declaration | Call site | Meaning |
|------|-------------|-----------|---------|
| read (default) | `x: T` | `f(v)` | read-only access; no copy is made |
| inout | `inout x: T` | `f(&v)` | the callee may mutate; mutations are visible to the caller after the call |
| take | `take x: T` | `f(v)` | the caller gives up `v`; using `v` afterwards is a compile-time error |
| comptime | `comptime x: T` | `f(v)` | the argument MUST be compile-time evaluable (CT-010) |

- **[MEM-020]** A read parameter cannot be mutated nor passed as `inout`.
- **[MEM-021] Law of exclusivity.** During a call, an `inout` argument is exclusively accessible to the callee: the
  same place (or an overlapping place: a field or element of it, or its container) MUST NOT be passed as another
  argument of the same call, read by another argument expression evaluated after it, or captured by a lambda argument.
  Violations are compile-time errors.
- **[MEM-022]** Exclusivity is checked **per call expression**, using only the syntax of the arguments. It never
  requires inter-procedural or flow-sensitive analysis across statements.
- **[MEM-023]** After `take`, the source binding is **moved out**: any later use in any control-flow path is an error.
  A `var` that has been moved out may be reassigned, which makes it usable again.
- **[MEM-024]** `inout self` methods may be called only on mutable places (`var` bindings, `inout` parameters, or
  their fields and elements).

```egide decls
fn add_line(inout cart: Cart, item: Item):
    cart.lines.push(item)
```

```egide fragment
add_line(&cart, item)
add_line(&cart, cart.lines[0])    # error MEM-021: `cart` is borrowed as inout by the same call
```

## 5.4 No escaping references

- **[MEM-030]** An `inout` parameter cannot be captured by a lambda that outlives the call, stored in a data
  structure, or returned. Since no other reference form exists, no lifetime analysis is required.
- **[MEM-031]** Methods cannot return a reference into `self`. Accessors return values (copy-on-write makes this cheap)
  or take a lambda: `map.update(key) fn(inout v): v += 1`.

## 5.5 Bounds and arithmetic

- **[MEM-040]** Every index and slice operation is bounds-checked; failure panics. The compiler MAY elide checks it
  can prove redundant.
- **[MEM-041]** Integer overflow panics (TYP-010).

## 5.6 Shared references

- **[MEM-050]** `Shared[T]` is the only type with reference semantics. Copying a `Shared[T]` copies the reference;
  mutations through one copy are visible through all copies. It is created with `Shared(value)`.
- **[MEM-051]** A `Shared[T]` is not `Send` unless `T` is a synchronisation type (`Mutex[U]`, `RwLock[U]`,
  `Atomic[U]`) or immutable (`Shared.frozen(value)`).
- **[MEM-052]** `Weak[T]` is a non-owning reference to a `Shared[T]`; `weak.upgrade()` returns `Shared[T]?`.
- **[MEM-053]** Graphs and trees with back-pointers SHOULD use `Arena[T]` and typed indices `Id[T]` from `std.arena`
  rather than `Shared`.

## 5.7 Cycles

- **[MEM-060]** Only `Shared` values can form reference cycles. Implementations MUST reclaim unreachable cycles; a
  program MUST NOT leak memory because of a cycle (ADR-0006).
- **[MEM-061]** The native backend implements MEM-060 with ORC-style targeted cycle collection:
  1. the compiler computes the **potentially cyclic** types: `Shared[T]` is potentially cyclic iff `T` can reach a
     `Shared[T']` whose type graph leads back to `T`;
  2. values of other types are managed by Perceus reference counting only and never scanned;
  3. when the count of a potentially cyclic `Shared` is decremented without reaching zero, the object becomes a
     candidate; candidates are processed incrementally by trial deletion (Bacon–Rajan);
  4. finalisers never run during cycle collection; a `Close` value found in a collected cycle emits a runtime
     warning (it should have been closed by `with`).
- **[MEM-062]** `@acyclic` on a type removes it from cycle collection; the compiler MUST verify the claim from the type
  graph and reject it otherwise.
- **[MEM-063]** `egide run --leaks` reports collected cycles with the type path involved.
- **[MEM-064]** The Go backend relies on Go's garbage collector for MEM-060; behaviour is identical (INT-020).

## 5.8 Unsafe

- **[MEM-070]** `unsafe(reason: "…"): block` permits raw pointers (`std.ptr.Ptr[T]`; the module is not named `unsafe`, which is a reserved word, LEX-021, so that `unsafe` stays a marker that only the block form can carry), unchecked construction of
  validated types, capability construction for testing, and C FFI. The reason string is mandatory and satisfies SYN-018.
- **[MEM-071]** A function containing `unsafe` is not marked in its signature, but its package MUST declare
  `allow = ["unsafe"]` in the manifest of every dependent (PKG-030), and `egide audit` lists every `unsafe` block.
