# 7. Concurrency

**Lightweight tasks like goroutines, but always attached to a scope, and no data race is possible.** Race freedom
follows from chapter 5: tasks receive values, never mutable references.

## 7.1 Tasks and scopes

```egide
fn profiles(ids: List[UserId]) -> Result[List[Profile], Error] using api: Client:
    scope(timeout: 5.s) fn(s):
        let tasks = [s.spawn(() => api.profile(id)) for id in ids]
        [t.join()? for t in tasks]
```

- **[CON-001]** `std.task.scope(timeout: Duration? = None) fn(s): block` runs `block` with a scope handle `s`. The call
  returns only when every task spawned on `s` has finished.
- **[CON-002]** `s.spawn(f)` starts a task running `f` and returns a `Task[T]`. There is no other way to start a task:
  no free-standing `spawn`, no detached tasks.
- **[CON-003]** If a task ends with a panic or its `join` result is an `Err` that propagates out of the scope, all other
  tasks of the scope are cancelled, and the scope re-raises the first failure.
- **[CON-004]** When the scope's timeout expires, all its tasks are cancelled and `scope` returns
  `Err(Cancelled.Timeout)`.

## 7.2 Cancellation

- **[CON-010]** Cancellation is cooperative and automatic: every blocking operation of the standard library
  (I/O, channel operations, `sleep`, `join`, lock acquisition) checks the cancellation state of the current task and
  returns `Err(Cancelled)` when cancelled.
- **[CON-011]** Cancellation propagates from a scope to its tasks and to nested scopes. No `ctx` parameter is needed
  (Go's `context.Context` is implicit; see GO-022 for interop).
- **[CON-012]** Pure CPU loops are not interrupted; `std.task.check_cancelled()?` may be called explicitly.

## 7.3 No colouring

- **[CON-020]** There is no `async`/`await`. A blocking call suspends the current task and the runtime schedules
  another one (M:N scheduling over all CPU cores).
- **[CON-021]** Values passed to `spawn` lambdas are captured by logical copy (MEM-001). A lambda passed to `spawn`
  MUST be `Send`: it may capture `Shared[T]` only if `Shared[T]` is `Send` (MEM-051).

## 7.4 Channels and selection

- **[CON-030]** `Chan[T](cap: n)` creates a bounded channel; `n` MUST be ≥ 0 (0 = rendezvous). Unbounded channels
  exist only as `Chan.unbounded[T]()`, whose name makes the memory-exhaustion risk visible.
- **[CON-031]** `ch.send(v)` and `ch.recv()` block; `recv` returns `T?` (`None` when the channel is closed and empty).
  `for v in ch:` iterates until close. Sending on a closed channel returns `Err(Closed)`.
- **[CON-032]** `select` is a standard-library function taking a list of cases and running the first one ready:

```egide
select([
    ch_a.on_recv(v => handle_a(v)),
    ch_b.on_recv(v => handle_b(v)),
    timer.after(1.s, () => tick()),
])
```

## 7.5 Shared state

- **[CON-040]** Shared mutable state requires `Shared[Mutex[T]]`, `Shared[RwLock[T]]` or `Atomic[T]`. A lock owns its
  data; the data is reachable only while the lock is held:
  `counter.lock() fn(inout n): n += 1`.
- **[CON-041]** In debug builds the runtime detects deadlocks among tasks waiting on locks and channels and panics with
  the list of tasks involved and their wait points.

## 7.6 Parallelism

- **[CON-050]** `std.par.map(xs, f)` and `std.par.for_each` split pure work across cores; `f` MUST be pure or `Send`.
