# Review checklist

Reviewers (`code-reviewer`, `security-reviewer`, humans) go through this list and answer each applicable item in the
review. End with `APPROVE`, `REQUEST_CHANGES` (numbered items) or `ESCALATE` (reason).

## 1. Scope and process

1. Does the PR correspond to exactly one task, with the task file moved and the Outcome filled?
2. Are all changes inside the task's `paths` (plus allowed exceptions)?
3. Is the PR small enough to review properly? If not, request a split.

## 2. Spec conformance

4. For each rule the PR claims to implement: read the rule, then read the code. Does the code do exactly that — no
   more, no less? Invented behaviour not in the spec is a defect, even if it looks useful.
5. Are edge cases in the rule text tested (boundaries, empty input, nested constructs, error paths)?
6. Do diagnostics carry the right code and rule, point at the right span, and suggest a fix where possible?

## 3. Tests

7. Do the new tests fail without the change? (Ask for evidence or check one.)
8. Were existing tests or snapshots changed? Each change must be justified by a spec rule in the PR description.
9. Are positive **and** negative cases present?

## 4. Code quality (OCaml)

10. Exhaustive matches, no catch-all on AST variants without justification.
11. No exceptions for user errors; diagnostics are reported and recovery continues.
12. No global mutable state; no `Obj.magic`; no `ignore` on a value that should be checked.
13. `.mli` present and documented for new public modules; interface changes listed and all callers updated.
14. Names, structure and comments follow `agents/style-guide-ocaml.md`.
15. Determinism: no output depends on hash-table order, time, or environment.

## 5. Security (mandatory for security-reviewer)

16. Can any program obtain authority it was not given (CAP-*)? Try to construct one.
17. Can a sink type be built from `Untrusted` or `str` without the template (SEC-*)?
18. Can a `Secret` be printed, logged, serialised, hashed or leaked through an error message?
19. Can comptime code or a package build perform I/O (CT-*, PKG-042)?
20. Memory and races: can the change break exclusivity, moves, resource closing or Send checks?
21. Go interop: can an impure Go function be reached without `Go` or the right capability?
22. Is there a new `tests/security/` case for the attack surface touched?

## 6. Verdict format

```
Verdict: REQUEST_CHANGES
1. parser.mly: `case` arm guard accepts `if` without expression — SYN-051 requires an expression. Add a parse-fail test.
2. layout.ml line 88: DEDENT emitted before NEWLINE, contradicts LEX-032 step 3.
```
