# 1. Introduction

## 1.1 What Égide is

Égide is a compiled, statically typed, general-purpose language for the domains where Go and Python dominate:
network services, command-line tools, infrastructure tooling, Kubernetes operators and, eventually, its own compiler.
Its defining property is that **the simplest way to write a program is also the secure way**.

A well-typed Égide program that does not use `unsafe` or foreign code:

- **[INT-001]** cannot violate memory safety (no use-after-free, double free, out-of-bounds access, null dereference);
- **[INT-002]** cannot contain a data race;
- **[INT-003]** cannot perform any interaction with the outside world (file system, network, processes, environment,
  clock, randomness, standard streams) except through a capability value it was explicitly given;
- **[INT-004]** cannot silently ignore an error or an integer overflow;
- **[INT-005]** cannot run code with any authority during compilation.

## 1.2 Heritage

| From | Taken | Refused |
|------|-------|---------|
| Rust | algebraic data types, exhaustive `match`, `Result` + `?`, traits, no null, no data races | lifetimes, global borrow checking, coloured `async`, procedural macros, slow builds |
| Go | lightweight tasks, channels, static binaries, fast builds, one formatter, rich stdlib, `defer`, minimal version selection | `nil`, ignorable errors, data races, orphan goroutines |
| Python | indentation-based blocks, REPL, scripts without ceremony, named arguments, f-strings, comprehensions, generators, `with`, doctests, "batteries included" | dynamic typing, `None` everywhere, runtime type errors, `eval`, packaging chaos |
| Swift / Hylo | mutable value semantics, `inout` | reference-type classes by default |
| Zig | `comptime`, types as compile-time values | manual memory management |
| Koka / Lean 4 / Nim | Perceus reference counting, ORC-style cycle collection, C as a portable backend target | — |
| E / Pony / WASI | object capabilities, no ambient authority | — |

## 1.3 Design principles

1. **Secure by default, explicit opt-out.** Every dangerous operation is visible in the source, in the signature of the
   enclosing function, and in the package manifest.
2. **Small core, rich library.** A feature goes into the compiler only if it cannot be a library type made sound by the
   existing rules.
3. **Local reasoning.** Every diagnostic can be explained by looking at one function body and the signatures it uses.
4. **One obvious way.** One formatter, one build tool, one package manager, one error-handling mechanism.
5. **Diagnostics teach.** Every error names the rule violated, the risk avoided and a concrete fix.

## 1.4 Complexity budget

**[INT-010]** The following are deliberately **excluded** from the language. Re-introducing any of them requires an
ADR that explains what it replaces and why the cost is worth it.

| Excluded | Alternative in Égide |
|----------|----------------------|
| Lifetimes, stored or returned references | Value semantics, `inout`, `take` (ch. 5) |
| A separate effect system | `using` capability clauses (ch. 6) |
| Macros of any kind | `comptime` and prefixed templates (ch. 9) |
| `async` / `await` | Uncoloured lightweight tasks (ch. 7) |
| Exceptions | `Result` + `?`; `panic` only for bugs (ch. 8) |
| Inheritance, subtyping, function overloading | Traits, named arguments |
| Free operator overloading | Fixed operator traits with documented laws |
| Implicit conversions | Explicit calls |
| Units of measure, contracts, dependent types | Newtypes and validated types; re-evaluate after 1.0 |
| Runtime reflection, `eval`, dynamic loading | Compile-time reflection |
| Mutable global variables | Capabilities and `Shared` values passed explicitly |
| Non-ASCII identifiers | ASCII identifiers; Unicode allowed in strings and comments |
| Formatter options | A single `egide fmt` style |

The price of these choices, accepted knowingly: no self-referential structures, no fine control over memory layout,
a small reference-counting overhead in the native backend. Égide does not target OS kernels or game engines.

## 1.5 Implementations

The reference implementation is `egidec`, written in OCaml 5 (ADR-0001). It has two permanent backends:
**Go** (ecosystem access and interoperability, ch. 11) and **native** (C with Perceus reference counting, no GC).
**[INT-020]** The observable behaviour of a program that does not use `unsafe`, Go interop or timing MUST be identical on
both backends, except for the timing of memory reclamation, which no program can observe (ch. 5).
