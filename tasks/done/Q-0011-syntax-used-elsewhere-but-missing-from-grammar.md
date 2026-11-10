---
id: Q-0011
rule: SYN-023, CAP-032, PKG-003, CT-011, CT-012, TYP-022, GO-032, LEX-023
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0009, T-0011, T-0008]
severity: high
status: decided
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
6. **`unsafe` block**: semantically it is defined by MEM-070 (what it permits; the reason string is mandatory and
   non-empty) and MEM-071 (the manifest `allow = ["unsafe"]`, `egide audit` lists every block); TYP-031, CAP-002 and
   SEC-017 depend on it. What is missing is its **syntactic** role in ch. 3: `"unsafe" "(" "reason" ":" STRING ")"
   ":" block` appears only in the EBNF, as a `primary`, so it can be used as an operand (`1 + unsafe(…): …`), and
   no SYN rule says whether it is an expression or a statement, what its value is, or how the `reason` identifier
   is checked.
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
6. Add a SYN rule that only places the construct: `unsafe(reason: "…"): block` is a block-ended expression
   (ADR-0013, SYN 015), so it cannot be an operand; the identifier before the string MUST be `reason`. Its effect,
   the non-empty reason, the manifest entry and the audit listing stay in MEM-070/MEM-071 and are not restated.
   Ask `security-reviewer` to confirm that moving `unsafe` out of `primary` loses no use that MEM-070 intends.

## Decision

Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone.

Item 1: add `using name: expr` argument. 2: `pub(package)`, `package` contextual (E0111). 3: option (b), type-returning functions and anonymous `struct:` removed; use generic declarations with `comptime` parameters. 4: `@go_threadsafe` is an attribute on a `type` alias of an imported Go type. 5: closed attribute table in ch. 3, own line, E0117. 6: `unsafe(reason: "…"): block` is a block-ended expression; `reason` checked (E0110); effect stays MEM-070/071. 7: covered by ADR-0014.

ADR-0015 (items 1-6), ADR-0014 (7). Rules: SYN-017 (new), SYN-023 (table), SYN-003, SYN-030, CT-011, CT-012, GO-032, TOOL-030. Security-relevant, for `security-reviewer`: items 3, 4, 6.

Amended 2026-11-10 by ADR-0017 (security review, owner-delegated): see the ADR for the changed rules (`@go_threadsafe` gated by the manifest and a reason, GO-032, PKG-030; top-level `let` restriction; SYN-018 for `unsafe` reasons).
