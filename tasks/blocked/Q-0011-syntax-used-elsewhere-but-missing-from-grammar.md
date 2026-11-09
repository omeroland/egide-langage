---
id: Q-0011
rule: SYN-023, CAP-032, PKG-003, CT-011, CT-012, TYP-022, GO-032, LEX-023
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0009, T-0011, T-0008]
severity: high
status: open
---
## Question

Other chapters use syntax that neither ch. 3 nor `spec/grammar/egide.ebnf` defines. The parser tasks must either
support it or reject it, and the spec says neither.

1. **Explicit capability argument (CAP-032)**: `sync(cfg, using api: other_client)`. `arg` has no `using` form.
2. **Package visibility (PKG-003)**: `pub(package)`. The EBNF only has `"pub"`.
3. **Type-returning functions (CT-011, CT-012)**: `fn Buffer(comptime n: int) -> type:` with an anonymous `struct:`
   body. `type` is a keyword (LEX-021) and is not a `type` production. `struct:` without a name is not a statement or
   an expression. TYP-022 says "Anonymous structs do not exist", which contradicts CT-012. LEX-023 makes `Buffer`
   (a function) a naming warning.
4. **Standalone attribute (GO-032)**: `@go_threadsafe kube.Clientset` is an attribute applied to an imported type
   on its own line. SYN-023 only allows attributes before a declaration.
5. **Closed attribute set (SYN-023)**: "closed and defined by this specification", but there is no list. Found by
   grep: `@derive`, `@acyclic`, `@test`, `@go_threadsafe`, `@derivation` (CT-030), `@template` (CT-040), `@property`,
   `@integration` (TOOL-030, TOOL-031). Is this the closed set? `@property fn(x: T)` (TOOL-030) also shows an
   attribute on the same line as `fn`, which the EBNF does not allow (`attribute NEWLINE`).
6. **`unsafe` block**: `"unsafe" "(" "reason" ":" STRING ")" ":" block` exists only in the EBNF. It has no SYN rule
   or prose, although TYP-031, CAP-002 and SEC-017 depend on it. Its value, its scope (expression or
   block) and its interaction with `pub` items are unspecified. This is security-relevant (ch. 6, 12).
7. `dyn A + B` (ERR-020): the EBNF allows a single bound. ADR-0014 fixes this.

## Options and recommendation (per item)

1. Add `arg = "using" IDENT ":" expr` (after positional and named arguments). Recommended: it is already an accepted
   rule (CAP-032), and the grammar just lacks it.
2. Add `visibility = "pub" [ "(" "package" ")" ]` (`package` is contextual, like `go`). Recommended.
3. Either (a) add `"type"` as a type form valid only as a return type, plus anonymous `struct:`/`enum:` as
   block-ended expressions valid only as the body of a `-> type` function, and fix TYP-022 to "except CT-012" and
   LEX-023 to "functions returning `type` use `UpperCamelCase`"; or (b) drop CT-011/CT-012 and use generic types
   (`struct Buffer[comptime n: int]`), which `generics` already allows. **Recommend (b)**: it removes a feature
   (complexity budget §1.4), keeps types nominal, and needs no new syntax. `Array[u8, n]` already shows that
   comptime generic parameters cover the use case.
4. Recommend a declaration form `@go_threadsafe` followed by `type` on the next line, as in any other attribute, or a
   bridge-module manifest entry. Do not add a special statement-attribute form.
5. Add a table of attributes to ch. 3 (name, target, arguments, rule). Allow an attribute only on its own line
   (TOOL-030 then reads `@property` on the line before `fn`).
6. Add a SYN rule: `unsafe(reason: "…"): block` is a block-ended expression (ADR-0013). The reason MUST be a
   non-empty string literal, `egide audit` lists it, and its effect is defined in ch. 6 and ch. 12. Ask
   `security-reviewer` to review.
