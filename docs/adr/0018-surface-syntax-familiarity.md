# ADR-0018: Surface syntax familiarity

- Status: Proposed
- Date: 2026-11-10
- Deciders: owner
- Decided by: proposed, owner confirmation required. This ADR would reverse a founding decision (ADR-0005). The
  owner-delegated "decide now, review at the MVP" regime of ADR-0013..0017 does **not** cover it, and nothing in it has
  been applied: `spec/`, the grammar and the existing ADRs are untouched.
- Spec chapters affected: 1, 2, 3 (rewritten in part), 4-13 (examples only), `spec/grammar/egide.ebnf`, `spec/README.md`
  (code-block wrappers), `README.md`, `examples/`
- Supersedes (if accepted): ADR-0005. Amends: ADR-0013 (token contract LEX-036 and the layout productions of the EBNF;
  SYN-015 is kept), ADR-0015 (Q-0020.1 and Q-0020.2: SYN-061, E0109, the `()` empty block), ADR-0016 (Q-0016 and
  LEX-030/032 details become moot). ADR-0014 and ADR-0017 are unchanged apart from examples.
- Raised by: the owner, through the project's promoters: the syntax should be close to a language developers already
  know (Go, TypeScript or ReasonML) to speed up adoption.
- Annex: [`attachments/0018-syntax-options.md`](attachments/0018-syntax-options.md) (the same programs in the four
  options, machine-checked), [`0018-check.py`](attachments/0018-check.py) and the three Menhir transcriptions
  `attachments/0018-menhir-{braces,go,reason}.mly`.

## Executive Summary

Replace indentation by braces with a Go-style newline terminator (option B below) and keep everything else that makes
Égide look the way it does; reject the Go skin (A) and the Reason shape (C); keep the status quo (D) as the fallback if
the owner weighs Python-style readability above first-contact familiarity. The migration cost is established and small
today (no parser exists), the adoption benefit is only extrapolated, and the cost grows with every line of Égide
written, so the decision is cheap now and expensive later in either direction.

## Core Analysis

### 1. What the request assumes, tested

| Claim | Level | Basis and counter-hypothesis |
|-------|-------|------------------------------|
| A familiar surface lowers the cost of a first read of an Égide program. | *emerging* | Mechanism: a Go or TypeScript developer parses `{ }` blocks without effort. No measurement exists for Égide. |
| A familiar surface speeds adoption. | *extrapolated* | Adoption studies I recall (Meyerovich and Rabkin, OOPSLA 2013, "Empirical analysis of programming language adoption") attribute language choice mostly to libraries, existing code and developer experience, not to syntax. **I could not retrieve it in this session** (the egress proxy denied the hosts), so treat the recollection as unverified. Python, Rust and Go were adopted with surfaces unfamiliar to their first audiences. |
| Go and TypeScript developers find indentation blocks foreign. | *extrapolated* | Both are brace languages. Counter-hypothesis: the stated audience includes DevOps and platform engineers, who read indentation-significant YAML daily and often Python. No survey. |
| Égide is unfamiliar mainly because of its blocks. | *established* (false as stated) | The current surface already mixes Rust (`fn`, `match`, `?`, `let`, `trait`, `impl`), TypeScript/Swift (`x: T`, `x => e`, `T?`), Go (`[ ]` generics, `defer`, `import go`) and Python (indentation, `and`/`or`/`not`, `elif`, f-strings, comprehensions, `with`, `#`). Blocks are one Python trait among several. |
| A Go-looking surface makes Égide feel like Go. | *extrapolated*, with a hazard | It would, until the semantics differ where Go developers hold strong priors: copy-on-write value semantics (a Go slice or map aliases, an Égide one does not), no `nil`, `&x` meaning `inout` and not "pointer" (SYN-033), explicit `using`. A familiar look with different behaviour can mislead more than an unfamiliar look that says "learn this". |

Syntax is therefore a **first-contact** lever. What a team adopts a language for (the Go ecosystem through `import go`,
ch. 11; build speed; the `egide fmt` and LSP of phase 6; stability) is elsewhere (*emerging*). The recommendation below is
justified mostly by cost and by the layout machinery it removes, not by a proven adoption effect.

### 2. The four options

Definitions and complete rewrites (a feature tour and `examples/tenants_api.egd`, in each option) are in the annex.

| | D status quo | B braces (TS/Rust-shaped) | A Go skin | C Reason-shaped |
|---|---|---|---|---|
| Blocks | `:` + INDENT/DEDENT | `{ }` | `{ }` | `{ }` |
| Statement end | line break (layout) | line break, Go rule | line break, Go rule | `;` |
| Function | `fn f(x: T) -> R:` | `fn f(x: T) -> R {` | `func f(x T) R {` | `fn f(x: T): R => { ... };` |
| Match | `match e:` / `case p:` | `match e {` / `case p:` | `switch e {` / `case p:` | `switch (e) {` / `\| p =>` |
| Lambda with a block | trailing `f(a) fn(x):` | trailing `f(a) fn(x) {` | trailing `f(a) func(x: T) {` | argument `f(a, (x) => { })` |
| Else-if | `elif` | `else if` | `else if` | `else if` |

B and A keep `and`/`or`/`not`, `#` comments, `x: T` at use sites, `->`, `[ ]` generics and trailing blocks (A changes the
declaration order and spelling only). C is "Reason where Reason has a construct, B where it has not" (section 4).

### 3. Criteria

#### 3.1 Familiarity for the target developers (*extrapolated* throughout)

| Construct | Go developer | TypeScript developer | Python/YAML developer | D | B | A | C |
|-----------|--------------|----------------------|-----------------------|---|---|---|---|
| Blocks | `{ }` | `{ }` | indentation | reads as Python | familiar | familiar | familiar |
| Statement end | newline | `;`/ASI | newline | newline | newline | newline | `;` (unfamiliar to Go) |
| Declarations | `name Type` | `name: Type` | `name: Type` | TS-like | TS-like | Go-like | TS-like |
| Sum types and patterns | none | unions | `match` (3.10) | `match`/`case` | `match`/`case` | `switch`/`case` | `switch`/`\|` (ML) |
| Closures | `func(...) {}` in parens | `(x) => {}` in parens | `lambda` | trailing block | trailing block | trailing block | in parens (TS-like) |

No option is a clone of one language; B is closest to the union of the three audiences because it keeps `x: T` and `=>`
(TypeScript), `match`, `?`, `fn` (Rust) and Go's line termination and `[ ]` generics. A makes declarations Go-like at the
price of two things (3.3). C is the least familiar to this audience: an ML shape for people who know none of it.

#### 3.2 Interaction with Égide's distinctive traits and with ADR-0013..0017

| Trait or decision | Effect of B (A is the same unless noted) |
|-------------------|------------------------------------------|
| Mutable value semantics (`inout`, `take`, `&place`) | None. Parameter modes and `&place` (SYN-033) do not depend on blocks. Hazard in every option, D included: Go developers read `&x` as a pointer. |
| Explicit capabilities, `using`/`given` | None. `given a, b {` is a header followed by a block, like `with`. CAP-031 and CT-002 are unchanged. |
| `unsafe(reason:)` | SYN-015 is kept, so `unsafe` still stands alone at the start of a line or as a whole right-hand side (SYN-017, `egide audit`). With braces the grammar *could* allow block-ended expressions as operands (`}` closes them); the proposal does not, to keep this property. |
| `comptime`, templates | None. LEX-055 lexes a template as one token, so `{ }` inside `f"…"` or `re"…{{2,62}}"` never meets block braces. |
| ADR-0014 generics `[ ]` | Kept, and this is where Go and TypeScript differ (`<T>`); ADR-0014 rejected `<>` for the `a < b > (c)` ambiguity, which still holds. C's `list(int)` type application would reintroduce the call-versus-type ambiguity ADR-0014 removed, so C keeps `[ ]` and loses a Reason trait. |
| ADR-0015 cover grammars (`(x: int) => …`, `&place`) | Unchanged in B. In A, `(x T) => e` makes the cover production ambiguous (3.3). |
| ADR-0016 Q-0016 (layout after continuation lines) and T-1035 | Disappear: no indentation stack, no "body width = last continuation line + 4". |
| ADR-0016/0017 ERR-002 (`# ignored: <reason>` on the statement's last line) | Stays line-based, with one clarification: braces allow several statements on a line (`if c { f() }`), so the comment is accepted only if the discarded statement's last token is the last token of its line. A discard inside a one-line block cannot carry a reason and must go on its own line. A restriction, not an addition. |
| LEX-003 Trojan Source, LEX-005 W0001, E0601, LEX-055 | Unchanged: they are about characters and templates, not layout. |
| SYN-006 nesting limit | Unchanged (brace nesting is block nesting). |

#### 3.3 Parsing: Menhir results (*established*, reproducible with `0018-check.py`)

All grammars are transcriptions of the same shape as `attachments/0013-menhir-check.mly` (ADR-0015, 0 conflicts) with
abstract tokens and empty actions. Conflict states counted in `menhir --explain` output.

| Grammar | Conflicts | Note |
|---------|-----------|------|
| D status quo, re-run | 0 | |
| **B braces** | **0** | after one restriction found by Menhir (below) |
| B with open-ended ranges allowed everywhere | 4 | `for i in 0.. {`: `0..` followed by a map literal `{…}` or by a block |
| A Go skin, lambda heads keep `(x: T) => e` | 0 | |
| A with `(x T) => e` | 1 | `(f (int, str))`: a call or a tuple-typed parameter |
| C Reason-shaped, four concessions | 0 | |
| C with bitwise `\|` restored | 5 | the arm bar `\|` and the operator `\|` (a body `x \| y`) |
| C with set literals and `{}` restored | 2 | `x => {y}`: a block or a set |
| C with an unparenthesised guard | 2 | `when x => y`: a lambda `x => y` |

Findings that matter for the decision:

1. **B needs exactly one grammar restriction.** A range without an upper bound (`a..`, `..`) is allowed only inside `[ ]`
   (slices, SYN-043) and `( )`; `for i in 0.. {` is an error with the hint `(0..)`. Rust solves the same problem by
   forbidding struct literals in headers; Égide has no struct literals (SYN-032) and so pays one rule instead.
2. **The `{` of a map or set literal never conflicts with a block brace** in B, because construction is `T(name: v)`
   (SYN-032), not `T { … }`, and no statement is a bare block. A Go-style composite literal `Item{Name: "pen"}` would
   reintroduce Go's own header ambiguity (`if x == T{} {`); this is a reason not to copy it.
3. **A is feasible but its two goals conflict**: `name Type` everywhere (`(x T) => e` included) costs one conflict, so
   lambda heads must keep the colon, and A is then inconsistent with its own declarations.
4. **C needs four concessions** (no bitwise `|`, no set literals and no `{}` map, parenthesised guards) and gives up
   trailing blocks. It is no longer Reason (section 4).
5. The annex programs parse in every option (`d_tour`, `d_tenants` = `examples/tenants_api.egd`, and the six rewrites),
   with negative controls rejected (`else` on its own line, `{` on its own line, `1 + match …`, `0.. {`).

The conflict-freedom is a property of these transcriptions. The real parser adds semantic actions and cover checks
(SYN-005), as it would for D.

#### 3.4 Attack surface: what braces change (*extrapolated* unless marked)

| Attack class | D indentation | B braces |
|--------------|---------------|----------|
| Invisible or lookalike whitespace changes block membership | Closed: LEX-004 (no tabs), E0051 (no `Zs` outside strings), LEX-003 (*established*, spec text) | Structure no longer depends on whitespace; W0003 below reads ASCII spaces only |
| A **whitespace-only** edit moves a statement into or out of a block | Possible and invisible to `git diff -w` and to "hide whitespace" review modes (*established* mechanism, Git `--ignore-all-space`; not re-fetched) | Impossible: a brace must move, and braces are not whitespace |
| **Misleading indentation** (indentation says "inside", braces say "outside"; Apple's `goto fail`, CVE-2014-1266, a known instance with brace-less `if`) | Impossible by construction | Possible. Mitigations: braces are mandatory (no brace-less `if`); new **W0003** (below); `egide fmt --check` fails on it |
| Bidirectional and format characters, hidden text | LEX-003 everywhere | Same, unchanged |
| Statement-boundary confusion (JavaScript's ASI class: `return⏎value`) | A more-indented line that is not a continuation is E0020 | Go's rule is narrow and fixed by token class (below); `a⏎-b` is two statements and then SYN-014 (unused value) rejects it, so it fails closed |
| Line terminators | LEX-002 | Same: only LF; lone CR and U+2028/2029 are errors |

Net: braces trade a *review-evasion* class (whitespace-only semantic edits) for a *rendering* class (misleading
indentation), and the second has a mechanical check. The security posture is equivalent **only with W0003**; without it
B is weaker than D on that axis. W0003 follows the W0001 precedent (LEX-005): not suppressed for dependencies,
`egide fmt --check` fails on it.

#### 3.5 Migration cost, exactly (counted on `main` at `c4c4df4` by grep; "about" marks a heuristic)

| Area | Count | Detail |
|------|-------|--------|
| ADRs | 1 superseded, 3 amended | ADR-0005; ADR-0013, 0015, 0016 (see header) |
| Spec rules with a layout or `:`-block form | about 30 | LEX-004, 021, 030-036; SYN-010, 012, 015, 017, 020, 044, 062, 064; TYP-006; MEM-024, 031, 070; CAP-022; CON-001, 031, 040; ERR-012, 013, 031; CT-011; TOOL-011 (several only contain a code block that must be re-bracketed) |
| of which rewritten in substance | 9 | LEX-030, 032, 033, 034, 035, 036, SYN-010, SYN-061 (deleted), SYN-062/064 (form) |
| Spec chapters touched | 12 of 13 | ch. 1 (heritage table), 2, 3, and examples in 4-9, 11, 13; only ch. 10 and 12 are untouched |
| `egide` code blocks in `spec/` | 16 | 12 contain block forms; plus 1 in `README.md` |
| EBNF | 23 of 110 Menhir nonterminals change, 5 disappear (`suite`, `simple_stmt`, `block_stmt`, `impl_body`, `elif`), 5 appear (`block`, `nl_seq`, `else_part`, `arm_body`, `open_range`) | 100 productions in `egide.ebnf` |
| Diagnostics | retire E0020-E0023, E0109; add W0003 and about two syntax errors | `docs/diagnostics.md` |
| `.egd` files | 148 in the repository; **40 must change** | `examples/` 4 (all have blocks), `stdlib/std/prelude.egd` 1, `tests/conformance/lexical` 14 (the 13 `layout_*` files are replaced, `source_crlf_accepted` is edited), `tests/security` 26 (13 in `semantics/`, 13 in `syntax/`). The other 108 (including 38 in `tests/security/lexical` and the 25 runner fixtures under `tools/conformance/test/`) contain no block |
| Compiler | `layout.ml` (106 lines), `test_layout.ml` (209), `test_layout_props.ml` (91) replaced by a termination pass of about 60-90 lines (*extrapolated*); tokens `INDENT`, `DEDENT`, `ELIF` removed from `tokens.mly`, `token_table.ml` | `ast.mli` is layout-agnostic (its header says so) and `print.ml` prints S-expressions: no change but one comment (`elif`) |
| `parser.mly` | 50 lines, a seed | nothing to migrate |
| Tasks | cancel 1 (T-1035), replace 1 (T-1032), retarget 8 (T-0009..T-0013, T-0015, T-0017, T-1031), unaffected 12 (listed in the plan) | see section "Plan" |

The protected `tests/security/` is append-only (AGENTS.md rule 6): porting its 26 files needs an explicit owner exception.

#### 3.6 Tooling

- **`egide fmt` (T-0090, phase 6).** Both options need one canonical style. Braces add: K&R brace placement, `} else {`,
  trailing commas, and W0003 as the formatter's own check. D needs the formatter to choose where to wrap long headers
  without closers. Neutral.
- **LSP and error recovery (T-0013).** Recovery synchronises at `}` and at NEWLINE instead of DEDENT; brace languages are
  easier to resynchronise (*extrapolated*: no more "unexpected indent" cascades). Diagnostics E0020-E0023 disappear;
  "expected `{` on the header line" and "`else` must follow `}`" appear.
- **REPL (T-0035).** Braces: an input is complete when brackets balance. D needs a blank-line rule, as Python's REPL does.
- **Code in YAML, heredocs, chat, wikis** (the platform audience's habitat, *extrapolated*): whitespace-mangling channels
  corrupt indentation-significant code and leave braces intact.

#### 3.7 Risks

| Risk | Assessment |
|------|------------|
| "Neither one nor the other" (a hybrid) | Real for any hybrid, so none is proposed: one structure carrier (braces), indentation is checked and cosmetic (W0003). Rejected hybrids: accept both surfaces (two parsers, two formatters, violates "one obvious way", spec/01 §1.3); braces optional when indentation says so (reintroduces `goto fail`). |
| Drift to a clone of Go or TypeScript with no added value | The value of Égide is semantic (INT-001..005, capabilities, comptime-only metaprogramming), and B changes none of it. The risk is positioning: spec/01 §1.2 lists "indentation-based blocks" under Python; that row must change. Cosmetic Go renames (`func`, `switch`, `:=`, `for … range`) would add the look of Go without its behaviour (section 1, last row) and are not proposed. |
| C "is not Reason" | See section 4: Reason has no `return`, `break`, `?`, `defer`, `var`, traits or parameter modes, which Égide's semantics need; C keeps them and so is an ML-flavoured B. |
| Adoption depends on something else | Yes (*emerging*): ecosystem (`import go`), tooling (phase 6), documentation, stability. Syntax is a first-contact lever only. Changing it does not substitute for them. |
| Decision latency | T-0009 (parser: declarations) is ready today and would be written against the indentation grammar. See "Plan". |
| Reversal cost | Section "Reversibility". |

### 4. ReasonML today (sources retrieved in this session)

The project's site (`reasonml.github.io`) and package registries were denied by the egress proxy; the facts below come
from upstream repositories (raw files) and from the local opam repository checkout (2026-11-09). Syntax details of Reason
that I rely on are from my own knowledge of OCaml/Reason and were **not** re-verified against its documentation.

- **Maintenance** (*established*). `reasonml/reason` `CHANGES.md`: 3.18.0 "Support OCaml 5.5", 3.17.0 "Support OCaml 5.4",
  3.14.0 "Support OCaml 5.3", earlier entries for 5.2, 5.1, 5.0 and 4.14
  (<https://raw.githubusercontent.com/reasonml/reason/master/CHANGES.md>). opam `reason.3.18.0` requires
  `ocaml >= 4.08 & < 5.6`, so it supports OCaml 5 (opam-repository `packages/reason/reason.3.18.0/opam`).
- **Shape of the maintenance** (*emerging*). In the last twelve release entries one maintainer (`@anmonteiro`) appears in
  eleven; the entries are mostly OCaml-version support, printer fixes and ppxlib upgrades, not language evolution. This
  is maintenance of a syntax front-end, not growth. I retrieved no adoption metric.
- **What Reason is for.** Its README: "Simple, fast & type safe code that leverages the JavaScript & OCaml ecosystems"
  (<https://raw.githubusercontent.com/reasonml/reason/master/README.md>); opam description: "a new syntax that is
  reminiscent of languages like JavaScript". Its main consumer is Melange (OCaml/Reason to JavaScript).
- **Relation to ReScript and Melange** (*established*, Melange README,
  <https://raw.githubusercontent.com/melange-re/melange/main/README.md>): Melange is "forked from an earlier version of the
  ReScript compiler"; its 1.0 had a ReScript-syntax compatibility layer, removed in 2.0 because the two "have diverged
  significantly". ReScript is a separate language with its own syntax and releases (13.0.0-alpha.7 in its
  `CHANGELOG.md`, <https://raw.githubusercontent.com/rescript-lang/rescript/master/CHANGELOG.md>). Melange packages exist
  for OCaml 4.14 up to 5.5 (opam `melange.7.0.1-414` … `-55`), and a Melange release works on the OCaml versions its
  README lists (v3.0: 4.14 and 5.1).
- **Why it does not fit Égide** (*established* where it is spec text, *extrapolated* otherwise). Reason is
  expression-oriented and `;`-separated; it has no `return`, `break`, `continue`, `?`, `defer`, `var`, parameter
  modes, `with` or `using`, no traits or impls, no bitwise `|` (`lor`), floats use `+.`/`*.`, type variables are `'a`
  (clashing with the char literal `'a'` of LEX-054), type application is `list(int)` (clashing with ADR-0014), labelled
  arguments are `~label=`. Option C keeps Égide's versions of all of these, so what remains of Reason is `switch`,
  `=>` arms, a leading `|` on variants and `;`, at the price of four grammar concessions (3.3). Its audience (OCaml and
  JavaScript developers) is not the Go, TypeScript and platform audience of the request.

### 5. Decision (proposed): option B, with these exact rules

The surface of B, and nothing else, changes. New rule ids are written with a space (`LEX 037`) as in ADR-0013 and
ADR-0014, because `tools/check-spec.sh` rejects undefined ids until T-1010 lands.

1. **Blocks** are `{ stmts }` (SYN-010). `:` is no longer a block opener, only a type annotation, a named-argument or
   map-entry separator, and a `case` arm separator. The empty block is `{}`; `()` stays the unit value.
2. **Line termination (LEX 036, replaces the layout token contract).** The lexer emits `NEWLINE` at a line break iff the
   last token of the line is an identifier, a literal (`INT FLOAT DURATION STRING RAW_STRING BYTES CHAR TEMPLATE`), `true`,
   `false`, `self`, `Self`, `return`, `break`, `continue`, `)`, `]`, `}` or `?`, **and** the first token of the next
   non-blank line is not `.`, `|>`, `and`, `or`, `)`, `]` or `}`; and at end of file after such a token. Brackets do not
   suppress it (`f(a⏎b)` is `f(a NEWLINE b)`, an error, as in Go). No `INDENT`/`DEDENT`. `;` stays reserved and an error
   (LEX-061; the hint becomes "one statement per line").
   ```text
   fn f() -> int
   {                                   # error: NEWLINE before `{`: the opening brace must be on the header line
       1
   }
   ```
3. **Brace placement (LEX 037).** `{` is on the line of its header; `else` follows `}` on the same line. Both fall out
   of rule 2 and get their own diagnostics with a hint.
4. **Statements in a block** are separated by NEWLINE; the last one needs no terminator (`if c { return 1 }`).
   SYN-061 and E0109 are deleted: a binding in a one-line block is allowed (it is simply useless).
5. **`elif` is removed** from LEX-021: `if a { } else if b { } else { }` (`else_part = "else" ( block | if_expr )`).
6. **`match`** keeps `case pattern [if guard]: statements` arms, so the arm body is a statement list ending at the next
   `case` or `}`. (`pattern => expr` arms, as in Rust and Reason, would clash with `x => e` lambdas and the bitwise
   `|`: 3.3.)
7. **Trailing blocks stay**: `f(a) fn(x) -> T { … }`, `retry(attempts: 3) fn { … }` (SYN-062, SYN-064). Positional arguments
   still precede named ones (SYN-030); a closure written inside the parentheses would need that rule relaxed
   (Open question 5).
8. **SYN-015 is kept** unchanged in substance (block-ended expressions stand alone or are a whole right-hand side).
9. **Open-ended ranges** (`a..`, `..`) only inside `[ ]` or `( )` (SYN-040, SYN-043); elsewhere E01xx "parenthesise an
   open-ended range".
10. **Misleading indentation, W0003 (LEX 038).** A line that starts a logical line MUST be indented by 4 × *d* spaces,
    where *d* is the number of `{`, `(` and `[` opened on earlier lines and not yet closed, not counting a closer that the line starts with;
    a line that continues the previous one (`.`, `|>`, `and`, `or`) by 4 more than that line. Otherwise W0003
    "indentation does not match the braces". Not suppressed for dependencies; `egide fmt --check` fails on it; it reads
    ASCII spaces only (LEX-004 and E0051 already exclude the rest).
11. **ERR-002** gains: the discarded statement's last token MUST also be the last token of its line.
12. **Unchanged** on purpose: `fn`, `match`, `->`, `x: T`, `T?`, `[ ]` generics, `and`/`or`/`not`, `#` comments, `|>`,
    `a if c else b`, comprehensions, `f""` templates, `with`/`given`/`defer`/`unsafe`, `import go`, `comptime`.

Edits to apply on acceptance (not applied here), by rule:

| Rule | Edit |
|------|------|
| LEX-021 | remove `elif` |
| LEX-030, LEX-035 | replace by the line-termination text of item 2; LEX-035 (bracket joining) is deleted |
| LEX-032, LEX-033, LEX-034 | delete (indentation stack, block colon, end of file); EOF text moves into LEX 036 |
| LEX-036 | rewritten as item 2; new LEX 037 (brace placement) and LEX 038 (W0003) |
| SYN-010 | blocks are `{ }`; empty block `{}` |
| SYN-012 | table forms use braces |
| SYN-015, SYN-017 | unchanged; examples use braces |
| SYN-020, SYN-024 | `fn name(...) -> T using … {`; `struct Name` and `impl T for U` may omit the braces |
| SYN-040, SYN-043 | open-ended range restriction (item 9) |
| SYN-061 | deleted (and E0109) |
| SYN-062, SYN-064 | trailing and lambda blocks use braces |
| ERR-002 | line-end clause (item 11) |
| ch. 1 §1.2 | Python row: drop "indentation-based blocks"; Go row: add "braces, newline-terminated statements" |
| `egide.ebnf` | the replacement below |
| `spec/README.md` | wrappers: `fn fragment() {` … `}` for `egide fragment` |
| ch. 4-13, `README.md`, `examples/`, `stdlib/` | re-bracket the code blocks and files listed in 3.5 |

```ebnf
(* Replaces the layout-dependent productions of egide.ebnf v0.3. NEWLINE per item 2: never before ")", "]" or "}". *)
file          = module_decl NEWLINE { import_decl NEWLINE } { top_decl } EOF ;
top_decl      = { attribute NEWLINE } ( [ visibility ] item_decl | impl_decl ) NEWLINE ;
fn_decl       = fn_sig block ;
struct_decl   = "struct" IDENT [ generics ] [ "{" lines(field) "}" ] ;
enum_decl     = "enum" IDENT [ generics ] "{" lines(variant) "}" ;
trait_decl    = "trait" IDENT [ generics ] [ ":" bound { "+" bound } ] "{" lines(trait_item) "}" ;
trait_item    = fn_sig | fn_decl | "type" IDENT [ ":" bound ] ;
impl_decl     = "impl" [ generics ] type ( "{" lines(impl_item) "}" | "for" type [ "{" lines(impl_item) "}" ] ) ;
impl_item     = { attribute NEWLINE } [ visibility ] fn_decl | "type" IDENT "=" type ;
const_decl    = "let" IDENT [ ":" type ] "=" ( expr | const_block ) ;
lines(X)      = X { NEWLINE X } ;                       (* the last item needs no NEWLINE *)
block         = "{" [ lines(stmt) ] "}" ;
stmt          = single_stmt
              | "let" pattern [ ":" type ] "=" ( expr | block_expr | expr "else" block )
              | "var" IDENT [ ":" type ] "=" ( expr | block_expr )
              | "comptime" "let" IDENT [ ":" type ] "=" expr
              | assign_target assign_op block_expr
              | block_expr
              | "for" pattern "in" expr block | "while" expr block ;
if_expr       = "if" expr block [ "else" ( block | if_expr ) ] ;
match_expr    = "match" expr "{" case_arm { case_arm } "}" ;
case_arm      = "case" pattern [ "if" expr ] ":" lines(stmt) [ NEWLINE ] ;
loop_expr     = "loop" block ;     with_expr = "with" with_item { "," with_item } block ;
given_expr    = "given" expr { "," expr } block ;          fn_lambda = fn_head block ;
trailing_call = postfix_expr "(" [ args ] ")" fn_head block ;
unsafe_expr   = "unsafe" "(" IDENT ":" STRING ")" block ;
range_expr    = bitor_expr [ ".." bitor_expr | "..=" bitor_expr ] | ".." bitor_expr | "..=" bitor_expr ;
open_range    = bitor_expr ".." | ".." ;                   (* only as gen_arg and as a paren_form item *)
```

Mechanical check: the Menhir transcriptions in `attachments/` (0 conflicts), the annex programs and the controls of
section 3.3, all produced by `python3 -I docs/adr/attachments/0018-check.py`.

### 6. Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| **B. Braces, TS/Rust-shaped, Go line termination** | most of the audience's conventions; removes the layout machinery (Q-0016, T-1035, E0020-E0023, SYN-061); whitespace-insensitive review; robust in YAML, heredocs, REPL | one more diagnostic family (W0003); lines +16-25% (annex sizes); loses the Python-readability pillar of ADR-0005 | **proposed** |
| A. Go skin (`func`, `name Type`, `switch`) | Go-like declarations | one conflict unless lambda heads keep the colon; Go look with non-Go semantics (1); loses `fn`, `->`, `x: T` which TypeScript developers know; renames only | looks like Go without behaving like Go |
| C. Reason-shaped | ML pattern syntax; some JavaScript-developer familiarity | four grammar concessions; no trailing blocks; not Reason once `return`/`?`/`var`/traits are added; audience mismatch; Reason is maintained but narrow (4) | worst fit for the audience and the semantics |
| D. Status quo | no migration; Python readability; no misleading-indentation class; layout is already implemented and specified | blocks are the one trait that is foreign to Go and TypeScript developers (*extrapolated*); layout machinery stays (Q-0016, T-1035, SYN-061, E0020-E0023) and each new construct must be made layout-safe (ADR-0013 found four such problems in its context items 1, 2, 3, 5) | viable; this is the fallback |
| Hybrid: accept both surfaces | no migration pain | two parsers, two formatters; violates "one obvious way" | see 3.7 |
| B with W0003 as an error | stronger | the compiler then enforces formatting: that is indentation syntax by another name | warning + `fmt --check` + not suppressible in dependencies, as W0001 |
| B with `//` comments, `&&`/`||`/`!`, `func` | more familiar to Go and TypeScript | `&`/`&&` typo class (SYN-101 exists to avoid it); churn in ERR-002 and in LEX-010/011; marginal first-contact gain | Open questions 2 and 3: keep as is |

### 7. Consequences (if accepted)

- Complexity budget: net negative. Removes the indentation stack, body-width rule, continuation-indent condition,
  SYN-061, E0109, E0020-E0023, the `NEWLINE`/`INDENT`/`DEDENT` contract and one keyword (`elif`). Adds one termination
  rule, one placement rule, one range restriction and W0003.
- Security: INT-001..005 are unaffected. The posture matches D only with W0003 (3.4). `security-reviewer` must confirm
  3.4 and the 26 ported attack tests (ch. 5, 6, 9, 11, 12 are touched only in examples).
- Implementation: see the plan. The AST and the printer are not affected.
- Migration: pre-1.0, no released code (ADR-0013's precedent); counts in 3.5.
- Index: row added to `docs/adr/README.md` (Proposed).

## Recommendations / Next Steps

### Recommendation

**Adopt B**, with the exact rules of section 5. Level of evidence: the cost and conflict-freedom are *established*; the
security equivalence is *extrapolated* and depends on W0003; the adoption benefit is *extrapolated* and probably smaller
than the promoters expect, because adoption is driven by the Go ecosystem access (`import go`), tooling and stability.
**Reject A and C.** If the owner values the Python-readability pillar (ADR-0005, spec/01 §1.2) above first-contact
familiarity, **keep D**: it is coherent, specified, implemented and 0-conflict; the cost of keeping it is the layout
machinery and the audience-familiarity risk above.

### Reversibility conditions

1. The AST is layout-agnostic (`ast.mli` header), so a second front end is a lexer pass and a `parser.mly`, not a
   rewrite of later phases (*extrapolated* size: 500-800 lines).
2. Both grammars are verified conflict-free (`0013-menhir-check.mly` and `0018-menhir-braces.mly`); both stay in the
   repository. The owner should tag `main` before the migration PR (`pre-adr-0018`) so that T-0007 and its tests are
   recoverable. I do not create tags.
3. The cost of reversing grows with the corpus. Today the corpus is 148 files of which 40 change; the stdlib is 11 lines.
   Decide at or before the first stdlib module, and re-measure at the MVP review (T-1109).
4. Revert triggers, to be checked at the MVP review: W0003 fires on more than a few percent of lines written by agents
   or reviewers; reviewers report that brace-less habits or misleading indentation passed review; or the corpus shows that
   one-line blocks dominate and hurt readability.

### Plan (tasks T-1100..T-1109, all `backlog`, nothing starts before acceptance)

| Task | Role | Size | Depends on | Content |
|------|------|------|------------|---------|
| T-1100 | language-architect | S | none | **Decision gate.** Do not claim before this ADR is `Accepted` on `main`. Records the decision, applies the ADR amendments and index status. |
| T-1101 | language-architect | M | T-1100 | Spec ch. 2 (LEX rules, W0003, diagnostics catalogue). |
| T-1102 | language-architect | M | T-1100 | Spec ch. 3 and `egide.ebnf`; ch. 1 §1.2; `spec/README.md` wrappers. |
| T-1103 | docs-writer | M | T-1101, T-1102 | Re-bracket the `egide` blocks of ch. 4-13, `README.md`, `examples/` (4), `stdlib/std/prelude.egd`. |
| T-1104 | syntax-engineer | M | T-1101 | Replace the layout pass by the termination pass; remove `INDENT`, `DEDENT`, `ELIF`; cancel T-1035. |
| T-1105 | syntax-engineer | S | T-1104 | W0003 check. |
| T-1106 | test-engineer | M | T-1101 | Replace the 13 `layout_*` tests, edit `source_crlf_accepted`, add tests for the new rules and for the A/B controls of 3.3. |
| T-1107 | security-reviewer | M | T-1102 | Port the 26 `tests/security` files (owner exception to append-only), add tests for misleading indentation, one-line-block discard (ERR-002), `{`-on-next-line. |
| T-1108 | language-architect | S | T-1102 | Retarget T-0009..T-0013, T-0015, T-0017, T-1031, T-1032 to the new grammar; record T-1035 as superseded. |
| T-1109 | language-architect | S | T-1104 | MVP checkpoint: re-run `0018-check.py`, measure the revert triggers, confirm or revert. |

Order: T-1100, then T-1101 and T-1102 in parallel, then T-1104, T-1106 and T-1107 in parallel, then T-1103, T-1105,
T-1108, T-1109. Estimated size: 10 tasks (7 M, 3 S), about 6 sequential steps.

**Blocked during migration:** T-0009, T-0010, T-0011, T-0012, T-0013 (parser), T-1031 (cover checks), T-1032, T-0015,
the layout-dependent part of T-0016/T-0017, and T-0090/T-0091 design details. **Not blocked:** T-0003, T-0004, T-0005,
T-0025, T-1030 (AST), T-1033, T-1036, T-1037, T-1039, T-1080, T-1006, T-0029 (none depends on blocks). Asking the
orchestrator to hold T-0009 until the owner decides avoids writing a parser against a grammar that may change.

### Open questions for the owner

1. B, or keep D? (This ADR recommends B; D remains a coherent choice.)
2. `#` comments (recommended: keep) or `//`?
3. `and`/`or`/`not` (recommended: keep) or `&&`/`||`/`!`?
4. W0003 as a warning plus `fmt --check` plus no suppression in dependencies (recommended), or an error?
5. Trailing blocks: keep (recommended: smallest change), or drop in favour of closures inside the parentheses, which
   removes SYN-062/064 and `trailing_call` but needs SYN-030 relaxed?
6. May `tests/security/` be ported in one governance PR despite its append-only rule?
7. May `main` be tagged before migration?

### Incidental findings (independent of this decision)

- LEX-021 reserves `unsafe`, yet MEM-070 names `std.unsafe.Ptr[T]`: `path = IDENT { "." IDENT }` cannot parse
  `std.unsafe`. Found while parsing the annex tour. One of the two must change (a module name other than `unsafe`, or a
  contextual keyword); a `spec-question` or ADR is needed. Not addressed here.
- `docs/roadmap.md` phase 0 exit criteria ("every production has a parse test; all `egide` code blocks parse") hold
  under either surface; the migration only moves the date.
