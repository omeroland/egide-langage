---
id: Q-0019
rule: SYN-012, ERR-012, TYP-062
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0032, T-0051]
severity: medium
status: open
---
## Question

Three rules give `let … else:` two meanings:

- SYN-012: `let pattern = expr else: block`, where the block MUST diverge.
- TYP-062: "`let` with a refutable pattern MUST use the `else` form" (Rust's let-else: `pattern` is matched against
  `expr`).
- ERR-012: "`let pattern = expr else: block` **unwraps** `Option`/`Result`/any refutable pattern" (`pattern` is
  matched against the *payload*).

Every example relies on the unwrap reading with an irrefutable pattern: `let id = TenantId.parse(…) else: return …`
(README, `examples/tenants_api.egd` twice) and `let port = cfg.port else: return Err(…)` (ch. 8). Under the
refutable-pattern reading, `id` matches the whole `Result`, the `else` branch is unreachable (TYP-061), and `id` has
type `Result[TenantId, ValidationError]`.

The two readings conflict whenever the pattern is a constructor:

```egide
let opt: Option[Option[int]] = …
let Some(x) = opt else: return    # x: Option[int] (match) or x: int (unwrap, then match)?
let Ok(v) = parse(s) else: return # unwrap the Result, then match `Ok(v)` against the payload?
```

The `else` block also cannot see the error value, so `else: return Err(e)` is impossible in both readings.

## Options

A. **Pattern only** (Rust). `let Ok(id) = TenantId.parse(…) else: return …`. One meaning, no type-directed
   behaviour. The four example sites must be rewritten. ERR-012 becomes "a refutable pattern, e.g. `Some(x)`,
   `Ok(v)`".
B. **Unwrap only.** The right side MUST be `Option`/`Result`, and the pattern is matched against the payload, which
   must be irrefutable. There are no refutable patterns in `let` (TYP-062 changes to "use `match`").
C. **Both, chosen by type**: unwrap when the pattern is irrefutable and the right side is `Option`/`Result`;
   otherwise match. This is the most convenient, and also the most surprising (see `Some(x)` above).

## Recommendation

A. It is explicit, has a single meaning, and is proven in practice. It also agrees with TYP-062 and does not make
the parser or type checker depend on the right side's type to interpret a pattern. Spec edits: ERR-012 wording;
rewrite README, `examples/tenants_api.egd` (2 sites) and ch. 8 (`let Some(port) = cfg.port else: …`). Accessing the
error remains `match` or `?` with `.context(…)`. No grammar change (the AST from T-0010 is the same for all options).
