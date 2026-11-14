---
id: Q-0053
rule: SYN-023, GO-032, PKG-030, SYN-018, SEC-002, LEX-006, LEX-003, LEX-002, CT-002, CAP-040, LEX-055, CT-040
raised_by: security-reviewer/T-1038 (re-review of ADR-0017)
blocking: [T-0009, T-1031, T-1039]
severity: high
status: open
---
## Question

Executive summary. The four blockers of the first review are closed by ADR-0017; the re-review found one grammar
defect that makes the mandatory `reason` of `@go_threadsafe` unparseable, and nine places where the text is silent or
ambiguous about a security-relevant behaviour. Items 1-4 should be settled before T-0009 and T-0092 are claimed.
Labels: *established* = reproduced or read in the text; *extrapolated* = inference.

### 1. The EBNF cannot parse `@go_threadsafe(reason: "…")` (high, *established*)

`attribute = "@" IDENT [ "(" [ expr_list ] ")" ]` and `expr_list` holds `expr`s; `reason: "…"` is not an `expr`.
Menhir (a transcription of the v0.3 EBNF, the same one that gave 0 conflicts for ADR-0017, driven with `menhir --interpret`) answers REJECT for
`@go_threadsafe(reason: "x")` and ACCEPT for the bare `@go_threadsafe`. SYN-023 and GO-032 require the named argument,
so today the only accepted spellings are the ones the spec forbids. Fix, 0 conflicts reproduced:

```
attribute = "@" IDENT [ "(" [ attr_arg { "," attr_arg } [ "," ] ] ")" ] ;
attr_arg  = [ IDENT ":" ] expr ;
```

with the closed table of SYN-023 deciding which attribute takes which argument, and a code for a missing, extra,
duplicated or non-string argument (E0118 or a new one).

### 2. Diagnostics the spec does not fix

| Program | Question |
|---------|----------|
| `@go_threadsafe` without `reason`, with `reason: 1`, twice, or with extra arguments | which code? (E0117 is "unknown or not allowed here", E0118 is "bad string") |
| `@go_threadsafe` on an alias of a non-Go type, of another alias, or of `GoRef[T]` | allowed? which code? |
| `let P = unsafe(…):` / `given` / `with` at the head of a top-level initialiser | SYN-015 says "a grammar restriction"; the generic E0100 is assumed by the tests; a dedicated code would read better |
| `u.trust(reason: "\u{1B}[2K")` | SYN-018 lists trust (SEC-002) without a code; E0118? |
| `f(api: c)` where `api` is a `using` parameter | SYN-030 says it never fills it; E0120 or an unknown-argument error? |
| `if c: unsafe(…):` (single-line block) | SYN-061 and SYN-015 give E0104 or E0109? |

### 3. `<go module>` in `go_threadsafe:<go module>` (medium, *extrapolated*)

(a) For a standard-library type (`bytes.Buffer`, `sync.Pool`) there is no Go module; the E0420 gate ("the package runs
`import go` of the module of T") is then vacuous, since any package may import `bytes`, and the manifest entry has no
defined spelling. (b) Module granularity lets a package that is allowed `go_threadsafe:k8s.io/client-go` assert any
type of that module, not the one the root reviewed. Option A: `go_threadsafe:<import path>.<Type>`. Option B: keep the
module and require `egide audit` to print the type. Recommendation: A.

### 4. Does the root package need an allow for its own attribute? (low)

GO-032(3) says "every package that transitively contains it"; PKG-030 speaks of dependencies. The tests
`go_threadsafe_requires_manifest_allow_*` assume that a manifest-less file (TOOL-011) has an empty allow set, so the
attribute is E0421 there.

### 5. `Untrusted.trust` reason is not required to be a literal (medium, *established*)

`unsafe`'s reason is a `STRING` in the grammar. `trust` is an ordinary method call; no rule says that `reason:` must be
a plain literal. A computed string defeats the audit listing and SYN-018 (checked on a value that exists only at run
time). Recommendation: `reason` of `trust` MUST be a plain `"…"` literal satisfying SYN-018, checked by the type
checker with a code.

### 6. LEX-006 is scoped by origin, not by sink (medium, *extrapolated*)

LEX-006 covers output that "includes source text or the value of a string literal". Strings that are neither:
manifest values (`[go.overrides]` reasons, `allow` entries, package names) of dependencies, registry and Sigstore
identity strings, comptime-computed strings in a CT-004 panic message, `embed()` file names. `egide audit` prints
several of them. Recommendation: every byte the toolchain writes to a terminal or a viewer passes through the
function, except text the tool itself generated.

### 7. E0610 names two contexts only (low)

CT-001/CAP-041 forbid impure compile-time evaluation everywhere, but E0610 is defined for top-level `let` and
`comptime` arguments. Not named: `comptime let` in a body, default parameter values (SYN-022), field defaults,
`@derive`/`@template` expansions, `where` predicates. Recommendation: one code for every compile-time context.

### 8. Purity through `dyn`, trait objects and function values (low, *extrapolated*)

CAP-040 says a function is pure if everything it calls is pure, but not how a call through `dyn Trait` or a function
value is classified (GO-042 has the conservative rule for Go only). A trait method implementation may contain
`unsafe` (not in the signature, MEM-071). Recommendation: such a call is impure unless the callee is statically known
or a lambda argument.

### 9. Wording

- SYN-018 defines "printable" by exclusion only; it does not state whether U+0009 (allowed raw inside a string by
  LEX-003) is rejected in a `reason`, nor how Co, Mn runs and U+2800 are treated. Recommendation: allow only
  `U+0020` and General_Category L, M (limited run), N, P, S.
- LEX-003 forbids all of Cc but LEX-002 accepts CR LF; say that LEX-003 is applied after CRLF normalisation.
- LEX-055 says prefixes "that declare a spec grammar in their `@template` registration" accept `:spec`, but the
  registration takes one string and declares nothing. When that syntax is added, "result type is a sink type" must be
  transitive (`Result[Sql, E]`, `Option[Html]`, a newtype or struct holding a sink).
- ADR-0017 says the top-level `let` guarantee is "grammar-level and evaluator-level"; the grammar restricts the head
  only, nested `unsafe`/`given`/`with` in an `if` branch, a lambda body or a trailing block parse and rely on E0610.

## Recommendation

One ADR (ADR-0018) for items 1, 2, 3, 5, 6 and the wording; items 4, 7, 8 by the architect directly.

## Partial answer (language-architect, 2026-11-11)

Item 1 and the first row of item 2 (attribute argument codes) are settled in ADR-0021 (Proposed): E0122. The top-level `let` row is Q-0024 (ADR-0021, E0104). Items 2 (other rows), 3-9 remain open. This file was renamed from Q-0022 to Q-0053 (2026-11-11) because it shared its id with `Q-0022-attribute-arguments-cannot-express-reason.md`. Older documents that say "Q-0022 items 1-9" (T-1038) mean this file; "Q-0022" without items in T-1030 and T-0009 means the attribute-argument question.
