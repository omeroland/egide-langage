# ADR-0021: Attribute arguments, `_x` bindings and unsafe top-level initialisers

- Status: Proposed
- Date: 2026-11-11
- Deciders: owner
- Decided by: proposed by the `language-architect`; **not accepted**. The owner's merge of this PR is the acceptance.
  The owner-delegated regime of ADR-0013..0017 does not cover this ADR.
- Spec chapters affected: 3 (SYN-015, SYN-023, SYN-053), `spec/grammar/egide.ebnf`, `docs/diagnostics.md`
- Answers: Q-0022 (attribute arguments; the ADR-0017 re-review file, formerly a second Q-0022 and renamed Q-0053 in this PR: item 1 and the first row of
  item 2), Q-0023, Q-0024
- Consistency with ADR-0018 (braces, Proposed): the three productions below do not mention blocks except through the
  existing `block_expr` nonterminal, which ADR-0018 redefines; they carry over unchanged. Examples use the braces form. Until T-1101/T-1102
  migrate the spec, the normative text is the indentation-based `spec/03-syntax.md` of this tree; the Menhir check
  below was run on the ADR-0018 braces attachment, so it shows shape-compatibility, not conformance of this tree's
  grammar (the real `parser.mly` was not checked).

## Executive Summary

Three parser-level gaps are closed with minimal grammar and no new feature: attributes accept labelled arguments
(`@go_threadsafe(reason: "…")` becomes parseable, 0 Menhir conflicts reproduced), an identifier that does not start with
an uppercase letter is a binding and only the exact name `_` is the wildcard, and `unsafe`/`given`/`with` as a top-level
`let` initialiser is E0104 produced by a post-parse cover check instead of a generic syntax error. Owner choices are
marked; each has a default.

## Core Analysis

### 1. Q-0022: the EBNF cannot parse `@go_threadsafe(reason: "…")`

*Established* (text, and reproduced with Menhir 0 conflicts, see "Verification"): `attribute` takes `expr_list`;
`reason: "x"` is not an `expr`; SYN-023 and GO-032 require it. Today only the spellings the spec forbids parse.

| Option | Assessment |
|--------|------------|
| **A (recommended)** `attr_arg = [ IDENT ":" ] expr` | Smallest change that is self-documenting. After an `IDENT` the lookahead `:` decides; no conflict (verified). The closed attribute table decides which labels exist, so no general feature is added. |
| B reuse call `args` | One production fewer but `&x` and `using` need a post-parse rejection: more cover checks than A. |
| C positional `@go_threadsafe("reason")` | No grammar change, but the label is what makes the audit listing and a review read as a justification; GO-032 and SYN-023 would need rewording. |

Counter-hypothesis to A: a labelled form invites user-defined attributes with arguments. The set of attributes is
closed (SYN-023, E0117), so it does not.

Rule: arguments are `expr` or `label: expr`; after a labelled argument all are labelled (as SYN-030 for calls). Each
attribute accepts exactly the arguments of its table row. A new code **E0122** covers missing, extra, repeated,
unlabelled or unknown-label arguments and a non-literal `reason`; E0118 stays for a string that breaks SYN-018. This
also settles the first row of item 2 of Q-0053 (formerly the duplicate Q-0022) ("which code?"): E0122, not E0117 (which means "unknown
attribute or wrong target") and not E0118 (string content). The AST change is `attribute.args : (string option * expr)
list option` (syntax-engineer, T-1031 follow-up). The E0107 PoC (`@derive((a: int))`) is unaffected: a parenthesised
item is still an `expr`.

### 2. Q-0023: identifiers starting with `_` in patterns

*Established* from the text: SYN-053 names two classes (uppercase initial, lowercase initial) and `_`; `_x` is an IDENT
by LEX-020, ERR-002 already treats `_x` as a binding, and SYN-024/E0113 forbid a variant or constant name that does not
start with an uppercase letter, so a `_`-initial name can never denote a variant (the first-character rule stays
decidable without name resolution).

| Option | Assessment |
|--------|------------|
| A `_x` is a binding; only `_` is the wildcard | Needed by ERR-002 anyway. |
| **B (recommended)** = A plus exemption from unused-binding diagnostics | The usual convention; costs one sentence. No unused-binding warning exists in the catalogue yet, so the exemption is stated as "never E0121 and exempt from any unused-binding diagnostic". E0121 compares names ignoring case with variants and `_discontinued` is not equal to `Discontinued`, so it is exempt already (*established* by the E0121 text). |
| C `_x` forbidden in patterns | Contradicts ERR-002 and breaks a common idiom. |

Hazard considered (*extrapolated*): `_x` hides an unused binding from review. Mitigation: SYN-053 now limits the exemption to
the unused-variable lint. ERR-002 still treats an unread `_`-named `Result` as a discard (E0304); must-consume and
linearity rules for resources and the `Secret`/`Untrusted` handling rules apply unchanged; `_` drops at once and `_x`
at scope end, so a lock or zeroizing guard is not released early by renaming.

### 3. Q-0024: `let X = unsafe(…) {…}` at top level

*Established*: the grammar has no derivation for it (`const_block` omits `unsafe`, `given`, `with`), so an LR parser gives
E0100, while SYN-015 calls it both "a grammar restriction" and the generic E0104 is what T-1031 plans to test.

| Option | Assessment |
|--------|------------|
| A1 Menhir error-state message for that state (the question's A) | Message tied to automaton state numbers; fragile when the grammar changes (ADR-0018 is about to rewrite it). |
| **A2 (recommended)** widen the production to `block_expr` as a COVER production and reject `unsafe`/`given`/`with` in the post-parse check with E0104 | Same diagnostic quality as A1, same mechanism as every other cover production (SYN-005, ADR-0015: `unsafe_expr` itself is one), robust to grammar changes. Conflict-free (verified). |
| B plain E0100 | Honest but a worse message, inconsistent with the other SYN-015 positions. |
| C a dedicated new code | A new code for a case E0104 already describes. |

Security note: nothing is weakened. The check still rejects exactly the same programs; CT-002/E0610 still reject
`unsafe`/`given`/`with` nested deeper in the initialiser (lambda bodies, branches), which the grammar never covered
(raised in item 9 of Q-0053 (formerly the duplicate Q-0022), still open).

### Verification (established, reproducible)

Starting from `docs/adr/attachments/0018-menhir-braces.mly` (0 conflicts) with only these changes:

```
attribute: AT IDENT option(delimited(LPAREN, option(attr_args), RPAREN)) {}
attr_args: tcl(attr_arg) {}
attr_arg: IDENT COLON expr {} | expr {}
const_decl: LET IDENT option(preceded(COLON, ty)) EQ expr {}
  | LET IDENT option(preceded(COLON, ty)) EQ block_expr {}      (* const_block removed *)
```

`menhir --explain` reports 0 conflicts. `menhir --interpret` ACCEPTs `@go_threadsafe(reason: "x")` before a `type`
alias, `@derive(A, B,)`, `let X = unsafe(reason: "r") { 1 }` and `let X = if true { 1 } else { 2 }` at top level; the
unmodified grammar REJECTs the first and third. Not verified against the real `parser.mly` (a seed) or against the
indentation grammar of `main` (the EBNF edit is the same shape there, `block_expr` instead of `const_block`).

## Decision

Apply sections 1 to 3 as written in the spec diff (SYN-015, SYN-023, SYN-053, EBNF, diagnostics E0104 text and the new
E0122).

## Alternatives considered

In the three tables above.

## Consequences

- Complexity budget: +1 production, +1 diagnostic, -1 production (`const_block`); no new feature.
- Security: INT-001..005 unaffected; E0107 attribute PoC unchanged; the audit of `@go_threadsafe` reasons keeps working.
- Implementation (follow-ups proposed, none created): syntax-engineer, `attribute.args` and the two cover checks in
  T-1031; T-0009 may carve in the `@go_threadsafe` test again; test-engineer: negative tests for E0122 and for E0104 on
  a top-level `let`; `Pat_bind` documentation in `ast.mli` ("does not start with an uppercase letter").
- Migration: none (pre-1.0).

## Recommendations / Next Steps

1. Owner: merge to accept. All three choices are mechanical; the one to look at is 3 (A2 vs plain E0100 B).
2. Q-0023, Q-0024 and Q-0022 are marked answered in this PR. Q-0053 (the re-review file, renamed here from its
   duplicate id Q-0022; `tasks/done/T-1038-...` referred to it by id and is corrected in this PR) keeps items 2 (other rows) and 3 to 9 open.
3. Not verified: behaviour with the real lexer; E0122 wording.
