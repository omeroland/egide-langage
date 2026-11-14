---
id: Q-0062
rule: CON-001, CON-010, CON-011, GO-022
raised_by: owner/feasibility-review-2026-11-14
blocking: [T-0038, T-0081]
severity: medium
status: open
---
## Question

**Executive summary.** Cancellation is implicit (CON-011) and every blocking operation checks "the cancellation state of
the current task" (CON-010). Go has no goroutine-local storage, so the Go backend needs a defined way to find the current
task. Separately, a scope returns only when all its tasks have finished (CON-001), and a Go function that blocks without
taking a `context.Context` can never be cancelled, so a scope with a timeout may not return.

## Core analysis

*Established*: the rules above; GO-022 injects the context only when the Go function's first parameter is one.
*Extrapolated*: the options for the current task on the Go backend are a hidden parameter on generated functions, or a
runtime lookup keyed by goroutine (not offered by Go without unsupported tricks).

| Sub-question | Option | For | Against |
|--------------|--------|-----|---------|
| Current task | A1: hidden first parameter on every generated function that can reach a blocking operation (computed like purity), none on the others | plain Go; cost only where needed | function values need a uniform convention, so closures always take it |
| Current task | A2: hidden parameter on every function | uniform | cost on every call; measure in T-1163 |
| Blocked Go call | B1: the scope still waits (CON-001 kept); debug builds report the task and the Go function after the deadline | no orphan task | a timeout is not a bound on return time |
| Blocked Go call | B2: the scope returns `Err(Cancelled.Timeout)` and abandons the goroutine | timeout is a bound | reintroduces orphan tasks, which ADR-0007 excludes |

## Recommendations / Next Steps

A1 unless T-1163 shows A2 is free; B1, with CON-004 reworded to say what a timeout guarantees when foreign code blocks,
and an `egide audit` line for calls to blocking Go functions without a context.
