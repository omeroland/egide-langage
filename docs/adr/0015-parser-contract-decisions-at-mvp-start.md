# ADR-0015: Parser-contract decisions at the start of the MVP

- Status: Accepted
- Date: 2026-11-10
- Deciders: owner
- Decided by: owner-delegated (language-architect), review at MVP ("take the best decisions; we will review once an MVP
  exists")
- Spec chapters affected: 2, 3, 4, 9, 11, 13 and `spec/grammar/egide.ebnf`
- Raised by: T-0022 (spec audit) and the syntax engineer. Answers Q-0010, Q-0011, Q-0013, Q-0017, Q-0020 (and records
  that ADR-0013 answers Q-0002 and Q-0008, ADR-0014 answers Q-0009).

## Context

The parser tasks T-0009..T-0013 cannot be written while the EBNF contains non-LR(1) productions, constructs used
elsewhere in the spec but missing from the grammar, and prose/grammar mismatches. The rule applied to every
choice: restrict rather than add, prefer what the parser can decide from tokens alone, and keep security-relevant
constructs visible at the start of a line.

## Decision

| Q | Decision | Spec change |
|---|----------|-------------|
| Q-0010 | Cover grammar for `( item, … )` (lambda heads) and for `&` arguments, with post-parse checks E0107 / E0106. | SYN-005, SYN-033, SYN-065, EBNF `paren_form`, `cover_item`, `arg` |
| Q-0011.1 | `using name: expr` argument (CAP-032) enters the grammar. | SYN-030, EBNF `arg` |
| Q-0011.2 | `pub(package)`; `package` contextual; other word is E0111. | SYN-003, EBNF `visibility` |
| Q-0011.3 | Option (b): remove type-returning functions and anonymous `struct:`. Parametric types are generic declarations with `comptime` parameters. | CT-011, CT-012 rewritten; TYP-022 unchanged |
| Q-0011.4 | `@go_threadsafe` is an ordinary attribute on a `type` alias of an imported Go type. | SYN-023 table, GO-032 |
| Q-0011.5 | Closed attribute table in ch. 3; attributes on their own line; E0117. | SYN-023, TOOL-030 wording |
| Q-0011.6 | `unsafe` is a block-ended expression, `reason` checked (E0110), semantics stay in MEM-070/071. | SYN-017 |
| Q-0013 | Case-based patterns (option B): uppercase or dotted/constructor names are constants/variants and MUST resolve; lowercase lone names bind. Literal patterns gain duration, raw string, bytes; ranges stay closed. | SYN-050, SYN-053, SYN-024 (E0113) |
| Q-0017 | Pipeline right side restricted to a path or call, optional `?` (option A), E0108. | SYN-037 |
| Q-0020.1 | Single-line block holds a `single_stmt` (no bindings), E0109. | SYN-061 |
| Q-0020.2 | The empty block is `()`. | SYN-010 |
| Q-0020.3 | `struct Name` and `impl T for U` may omit the body; empty enum/trait stay errors. | SYN-024 |
| Q-0020.4 | `as` only on a single-path import. | SYN-002 |
| Q-0020.5 | `pub impl` is a syntax error. | SYN-003 |
| Q-0020.6 | `where` requires `new`. | SYN-024 |
| Q-0020.7 | `comptime let` at top level is a syntax error. | SYN-003 |
| Q-0020.8 | `..=` requires an upper bound. | SYN-040, EBNF `range_expr` |
| Q-0020.9 | `self` only first parameter in a `trait`/`impl` function, no `comptime self` (E0114). | SYN-021, EBNF `params` |
| Q-0020.10 | No module path may start with `go` (E0116). | SYN-001 |
| Q-0020.11 | LEX-060 is plain maximal munch. | LEX-060 |

Where I deviate from or sharpen the audit's recommendation:

- **Q-0011.5, field attributes.** The table has no attribute whose target is a field, but the grammar and the AST keep
  `{ attribute NEWLINE }` on fields and impl items, so that adding one later is a spec change only. An attribute on a
  wrong target is E0117.
- **Q-0013, declaration side.** Option B needs variant and constant names to start uppercase, otherwise `case foo:`
  could not be told from a unit variant `foo`. The audit left this implicit; SYN-024 makes it an error (E0113). All
  other naming rules remain LEX-023 warnings.
- **Q-0013 item 3.** Positional sub-patterns follow SYN-032 (decided in ADR-0016, which also fixes SYN-032 for
  positional variants).
- **Q-0017.** The grammar keeps `cond_expr` on the right of `|>` and the parser checks the shape (cover), because a
  grammar-level restriction can only say "syntax error", whereas E0108 can give the parenthesise hint.

## Mechanical check

`docs/adr/attachments/0013-menhir-check.mly` is a Menhir transcription of the complete EBNF (declarations,
statements, types, expressions with the cover productions, patterns; abstract tokens; empty actions). `menhir
--explain` reports **0 conflicts** and an empty `.conflicts` file. Interpreter runs: the §2.4 token stream, two
consecutive one-line functions and a trailing-block `let` ACCEPT; `1 + match c: …` REJECTs. The first version of the
transcription found real problems that are fixed in the EBNF: the paren cover needs the optional mode factored out
(`cover_item`), and trailing commas must be written as `x | x "," | x "," list` to stay LR(1) in Menhir (the EBNF
notation `{ "," x } [ "," ]` is fine for readers; the parser uses the factored form).

## Alternatives considered

| Option | Why not |
|--------|---------|
| Q-0010 B: `fn(a, b) => …` | moves the conflict to ADR-0014's `fn` types in `[ … ]` |
| Q-0010 C: single-parameter short lambdas only | too restrictive for `reduce`, `sort_by` |
| Q-0011.3 (a): keep `-> type` functions | new syntax, anonymous structs, contradicts TYP-022 |
| Q-0013 A: resolution-based | a typo silently becomes a catch-all binding |
| Q-0017 B: any callable on the right | loses "exactly `f(x, a)`" |

## Consequences

- Complexity budget: net reduction (a feature removed in Q-0011.3, several forms made errors); additions are
  `pub(package)` (already in PKG-003), `using` arguments (already CAP-032) and bare `struct Name`.
- Security: INT-001..005 unaffected. Tightenings: `unsafe` cannot be an operand; no silent catch-all patterns;
  `@go_threadsafe` is an ordinary, audited attribute (ch. 11 touched, `security-reviewer` to confirm); removing
  type-returning functions removes a comptime code-generation path (ch. 9 touched).
- Implementation: T-0009..T-0013 and  tasks T-1030 (AST), T-1031 (post-parse checks), T-1032 (layout tests).
- Diagnostics: E0104..E0117 added to `docs/diagnostics.md` (allocated).
- Migration: none (pre-1.0).

## Amendment

Amended by ADR-0017 (resolution of the security review): see its table for the rules changed (LEX-003, LEX-006, LEX-055, SYN-018, GO-032, PKG-030, ERR-002 and others). Where this ADR and ADR-0017 differ, ADR-0017 wins.
