# ADR-0023: No Go code at compile time

- Status: Proposed
- Date: 2026-11-11 (split out of ADR-0022 after its security review)
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. Needs the `security-reviewer` (ch. 9 is touched).
- Spec chapters affected: 4 (TYP-031), 9 (CT-001, CT-005, new CT-006), 13 (TOOL-010), `docs/diagnostics.md`
- Independent of ADR-0022, ADR-0024 and ADR-0025.

## Executive Summary

CT-001 plus CAP-040 let a Go function classified pure run at compile time, which would execute foreign code with the
compiler's authority (INT-005). CT-006 forbids it on the engine, not on syntax: the compile-time interpreter has no
foreign-function interface in any mode, and reaching Go from compile-time code is E0611. The conflict with TOOL-010 (the
REPL, `egide run` and `egide test` share that interpreter) is resolved by running Go-using programs through the Go backend
and rejecting Go in the REPL by a closure test. Labels: *established* = spec text; *extrapolated* = inference.

## Core Analysis

### 1. The hole

*Established*: CT-001 ("any pure function can be evaluated at compile time"), CAP-040 (pure = "does not call ... impure Go
code") and GO-011 (a pure Go function needs no capability) together make a pure-classified Go function compile-time
evaluable. A classification is a static approximation (GO-042 lists what it cannot see) and may be wrong or overridden
(GO-044), so a mistake would become code execution during the build.

### 2. Why the first rule was bypassable (security review B3, established from the text)

The first draft said "a call to a Go function" in an enumerated list of contexts. Bypasses: `comptime let xs = map(["a"],
strings.ToUpper)` (a Go function used as a value; CAP-040 exempts lambda arguments); `f"{ver}"` with a Go-typed `ver`
(implicit `String()`); a TYP-031 predicate through an Égide helper; `@template` bodies, `comptime fn`, derivations, array
lengths, const-generic arguments. Rule now: defined on the engine ("no FFI in any mode"), with the reached operations
enumerated (call, function value, operation on a Go-typed value, indirection through Égide functions, trait objects and
function values), enforced structurally and reported at the outermost compile-time site as **E0611**. The checker reports
what it sees; the engine reports the rest, so a miss is an error, never an execution. E0610 is not reused because its
message ("must be pure") is misleading for a Go function classified pure.

Second-pass additions: Go constants (`math.MaxInt64`) are legal (the type checker folds them; nothing runs) and are the only
Go values that may appear (C2); the evaluator must have no code path that can call Go (structural enforcement), and each
bypass above needs a conformance test (follow-up for `test-engineer`).

### 3. TOOL-010, CT-005, INT-020 (security review B3.5, A6)

*Established*: TOOL-010 says the REPL, `egide run` and `egide test` use the comptime interpreter with semantics identical to
compiled code; *established*: INT-020 excludes programs that use Go interop, so that claim never covered them.

| Option | Assessment |
|--------|------------|
| **A (chosen)** the interpreter has no Go interface in any mode. A program whose package closure uses `import go` is built with the Go backend and executed by `egide run`/`egide test`. The REPL applies the same closure test at every import: `import go`, or an Égide package whose closure uses Go, is E0707 | One engine; no mode flag that is "one bug from INT-005"; TOOL-010 stays true for everything INT-020 covers. Cost: a Go-using program is compiled before it runs, and the REPL cannot import Go, directly or through a dependency. |
| B one interpreter with an FFI enabled outside compile-time mode | CT-006 would depend on a context flag. Rejected. |
| C a second interpreter instance with an FFI for run/REPL | Two engines to keep identical; no user need shown. Fallback if the owner needs Go in the REPL. |

Second-pass findings fixed: the first draft rejected only the syntax `import go` in the REPL, which left a dependency whose
closure uses Go as a way in (A6); CT-005 still said the interpreter runs the REPL and `egide run` without the carve-out;
CT-006 said "in its compile-time mode" while TOOL-010 said "any mode". All three now say "no mode".

Code placement (second-pass C7): E0611 is a comptime code (E06xx); the REPL code is E0707, in the E07xx range (packages
and Go interop; empty today), not E0612, because it is not a comptime error.

## Decision

Apply the spec diff: CT-001, CT-005, new CT-006, TOOL-010, TYP-031, diagnostics E0611 and E0707.

## Alternatives considered

Allow only standard functions on the reviewed list at compile time: rejected, the list is reviewed for authority, not for
determinism or termination, and the budgets of CT-003 cannot bound native code.

## Consequences

- Complexity budget: +1 rule, +2 diagnostics, no language feature; the phase-1 interpreter (OCaml bytecode) cannot call Go,
  so today the rule costs nothing and prevents a later shortcut.
- Security: keeps INT-005 independent of GO-042's accuracy.
- Implementation (follow-ups proposed, none created): `comptime-engineer`: E0611 in the checker and the evaluator, E0707 in
  the REPL; `tooling-engineer`: `egide run`/`egide test` through the Go backend for Go-using programs (T-0036);
  `test-engineer`: one conformance test per bypass listed in section 2.
- Migration: none (no Go interop exists yet).

## Recommendations / Next Steps

1. `security-reviewer` re-reviews. 2. Owner choice, default A: Go in the REPL needs option C. 3. Not verified: nothing was run.
