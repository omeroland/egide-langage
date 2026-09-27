# OCaml style guide for egidec

## Toolchain

- OCaml ≥ 5.2, dune ≥ 3.14, `ocamlformat` 0.26.2 (config in `.ocamlformat`). Formatting is not discussed in reviews:
  run `dune fmt`.
- Warnings: the dune `(flags)` of every library enable `:standard` plus warnings as errors in dev profile.
  Never disable a warning globally.

## Structure

- One dune library per directory under `compiler/lib/`, named `egide_<dir>`. Libraries are `(wrapped true)`.
- Every module used outside its library has an `.mli`. Types are abstract unless pattern matching outside is needed.
- Dependency direction: `source` ← `diagnostics` ← `syntax` ← `resolve` ← `types` ← `hir` ← `check`/`comptime`
  ← `mir` ← `backend_*` ← `driver` ← `bin`. No cycles; no library depends on `driver`.

## Code

- **Exhaustive matching.** No `| _ ->` on variant types of the compiler's IRs unless the omitted constructors are
  listed in a comment. When you add a constructor, the compiler shows you every place to update — that is the point
  of ADR-0001.
- **Errors.** User errors → `Diagnostics.report sink diag` and continue with a recovery value (e.g. `Ty.Error`).
  Compiler bugs → `Ice.fail "context" ...` which prints an internal-error message. Never `failwith` for user errors.
- **No global mutable state.** Pass a context record (`Ctx.t`) explicitly. Counters (fresh ids) live in the context.
- **Immutability first.** Prefer persistent maps (`Map.Make`) over `Hashtbl` except in measured hot paths;
  never iterate a `Hashtbl` to produce output.
- **Spans everywhere.** Every AST/HIR node carries `span : Span.t`.
- **Naming.** `snake_case` values and types, `Capitalized` modules and constructors; IR constructors are prefixed by
  kind only when ambiguous (`Expr.Call`, `Pat.Tuple`).
- **Comments.** Explain *why* and cite rule ids: `(* LEX-032 step 2: indentation must grow by exactly 4. *)`.
- **Performance.** No premature optimisation; measure with `bench/` before and after for hot paths.

## Tests

- Unit tests live in `compiler/test/<library>/`, use `ppx_expect` for anything printable and `alcotest` otherwise.
- Property tests (`qcheck`) for invariants: round-trips, idempotence, "never raises".
- A test name states the behaviour: `let%expect_test "dedent to unknown column reports E0022" = ...`.
