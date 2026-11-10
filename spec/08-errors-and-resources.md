# 8. Errors and resources

## 8.1 Errors are values

- **[ERR-001]** Recoverable errors are values of type `Result[T, E]`. There are no exceptions.
- **[ERR-002]** A value of type `Result` MUST be used: matching it, propagating it with `?`, returning it, passing it
  on, or binding it to a name that is later read. Discarding it is a compile-time error (E0304); a `Result`-typed
  binding that is never read, including a name starting with `_`, is a discard. The explicit discard is
  `let _ = f()  # ignored: <reason>`. The check reads the comment side table (LEX-031), not the text: the comment MUST
  be of kind `#` (a `##` comment does not count), MUST be on the line of the statement's last token, MUST start with
  `# ignored:` and MUST have a reason with at least one character that is not whitespace or `Zs`. The text `# ignored:`
  inside a string or triple-quoted literal is not a comment. `egide audit` lists these sites.

## 8.2 Propagation

- **[ERR-010]** Postfix `e?` on `Result[T, E]` evaluates to the `T` of `Ok`, or returns `Err(From.from(err))` from the
  enclosing function, whose return type MUST be `Result[_, F]` with `impl From[E] for F`.
- **[ERR-011]** `e?` on `Option[T]` inside a function returning `Option[_]` returns `None` early. Mixing
  `Option` and `Result` requires `opt.or(err)?` / `res.ok()?`.
- **[ERR-012]** `let pattern = expr else: block` matches `pattern` against the value of `expr`; when it does not match,
  the block runs and MUST diverge (SYN-012). It is the form for unwrapping: `let Some(port) = cfg.port else: …`,
  `let Ok(id) = TenantId.parse(s) else: …`. There is no implicit unwrap: `let id = TenantId.parse(s) else: …` binds the
  whole `Result`, the `else` is unreachable (TYP-061) and the compiler rejects it. The error value is not bound; use
  `match`, or `?` with `.context(…)`, to read it. `egide audit` lists every `let … else` whose scrutinee has type
  `Result`, because the `else` block silently consumes the error.
- **[ERR-013]** `res.context("while loading config")` wraps an error with a message, keeping the cause chain;
  `Error` (the dynamic application error type in `std.error`) prints the chain.

```egide decls
enum ConfigError:
    Read(cause: IoError)
    Format(line: int, message: str)
    Missing(key: str)

fn load_config(dir: Dir[Read]) -> Result[Config, ConfigError]:
    with f = dir.open("app.toml").map_err(ConfigError.Read)?:
        let cfg = toml.parse[Config](f.read_all()?)
            .map_err(e => ConfigError.Format(line: e.line, message: e.msg))?
        let Some(port) = cfg.port else: return Err(ConfigError.Missing("port"))
        Ok(cfg.replace(port: port))
```

## 8.3 Error types

- **[ERR-020]** Libraries SHOULD expose precise enum error types. Applications MAY use `std.error.Error`
  (a boxed `dyn Display + Send` with a cause chain).
- **[ERR-021]** The `Display` output of an error MUST NOT contain the clear text of a `Secret` nor the raw content of an
  `Untrusted` value (SEC-012, SEC-001); the standard derivations enforce this.

## 8.4 Resources

- **[ERR-030]** A type that implements the `Close` trait (`fn close(take self) -> Result[(), E]`), or that contains a
  field of such a type, is a **resource**. Resources cannot be logically copied (MEM-001 does not apply): assignment
  and passing in the default mode are errors; they can only be read (default mode), passed `inout`, or moved with
  `take`.
- **[ERR-031]** `with name = expr: block` binds a resource and closes it when `block` exits by any path (normal
  completion, `return`, `break`, `?`, panic). Multiple items are closed in reverse order. If `close` fails and the block
  succeeded, the `with` evaluates to the close error when the enclosing function returns a `Result`; otherwise the
  error is logged to the task's stderr.
- **[ERR-032]** A resource MUST NOT escape its `with` block except by `take`. At the end of every scope, every live
  resource binding MUST have been moved out (`take`) or be managed by `with`; otherwise compile-time error
  "resource may leak".
- **[ERR-035]** `defer expr` evaluates `expr` when the enclosing block exits, in reverse order of declaration,
  including on panic. `defer` MUST NOT be used on a resource binding (use `with`).

## 8.5 Panics

- **[ERR-040]** `panic(msg)`, failed `assert`, overflow, out-of-bounds indexing and division by zero **panic**. A panic
  unwinds the current task: `defer` actions and `with` closes run, then the enclosing scope treats the task as failed
  (CON-003). A panic in `main`'s task prints the message and a stack trace and exits with status 101.
- **[ERR-041]** Panics are for bugs, not for expected failures. The standard library documents every panic condition of
  every public function.
- **[ERR-042]** `std.task.catch_panic(() => …) -> Result[T, Panic]` exists for test frameworks and servers that
  isolate requests; it MUST NOT be used for control flow (lint).
- **[ERR-043]** A panic never crosses a C FFI boundary; a Go panic crossing into Égide becomes an Égide panic (GO-024).
