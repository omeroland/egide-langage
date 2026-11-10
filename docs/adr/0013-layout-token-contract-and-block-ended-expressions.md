# ADR-0013: Layout token contract and block-ended expressions

- Status: Accepted
- Date: 2026-11-09
- Deciders: owner
- Decided by: owner-delegated (language-architect), 2026-11-10; the owner reviews at the MVP milestone. Spec edits applied in the PR that accepts this ADR.
- Spec chapters affected: 2, 3 (and `spec/grammar/egide.ebnf`)
- Raised by: T-0022 (spec audit of chapters 2 and 3). Answers Q-0002 (layout tokens vs EBNF block, PR #3) and
  Q-0008 (`place` cannot start with `self`, PR #4), raised in parallel by `syntax-engineer`.

## Context

LEX-032 (implemented in `compiler/lib/syntax/layout.ml`, tested by `tests/conformance/lexical/layout_*.egd`) and the
token example of §2.4 define this token stream:

```egide
fn f(x: int) -> int:          # FN IDENT ( IDENT : IDENT ) -> IDENT :
    if x > 0:                 # INDENT IF IDENT > INT :
        x                     # INDENT IDENT
    else: 0                   # NEWLINE DEDENT ELSE : INT
                              # NEWLINE DEDENT EOF
```

`spec/grammar/egide.ebnf` cannot parse it:

1. `block = NEWLINE INDENT …` expects a `NEWLINE` before `INDENT`; LEX-032 step 2 emits only `INDENT`.
2. `if_stmt = … block [ NEWLINE "else" … ]` expects `NEWLINE` between the `DEDENT` of a block and `else`; LEX-032
   step 3 emits `NEWLINE DEDENT` and then the next line's tokens directly.
3. Likewise `stmt { NEWLINE stmt }`, `{ NEWLINE top_decl }`, struct/enum/trait/impl bodies and `case_arm` lists all
   expect a `NEWLINE` after a `DEDENT`, which never comes. `fn f(): a` followed by `fn g(): b` at top level fails too.
4. `if_expr` and `match_expr` are both `primary` alternatives and `compound_stmt` alternatives, which is a
   reduce/reduce conflict in statement position (the EBNF claims LR(1), ADR-0005).
5. Where expressions that end with an indented block may appear is unspecified. `let n = match c:` (used throughout
   the examples), SYN-064 `let handler = fn(req) -> Response:`, and `let r = retry() fn: …` need a terminator rule: after
   the `DEDENT` there is no `NEWLINE` to end the `let`. `call_with_trailing_block` is only a statement, so the last
   form is not allowed at all, and nothing says whether `f(if c: … )` or `1 + match x: …` are allowed.
6. `with` and `given` are statements in the EBNF, but ERR-031 says "the `with` evaluates to …" and
   `examples/tenants_api.egd` uses a `given` block as the value of `main`.

The seed parser (`parser.mly`) already uses the terminator model (`terminated(item, NEWLINE)`), so the EBNF is the
outlier. T-0009..T-0012 cannot be written against the current EBNF without guessing.

## Decision

**Keep the LEX-032 token stream unchanged** (Q-0016's separate amendments to LEX-032 are decided in ADR-0016) and make the EBNF match it. (Q-0016 proposes two separate amendments to
LEX-032, body width after a continuation line and the first line of a file; they do not alter the token contract
below, and this ADR does not depend on them.) The layout produces a *terminator* model, like Python's,
except that a block header is terminated by `INDENT` instead of `NEWLINE INDENT`:

- every logical line is terminated by `NEWLINE`, except a line whose last token is a block `:`, which is
  terminated by `INDENT`;
- `DEDENT` is never followed by `NEWLINE`.

Constructs that end with a block are **block-ended expressions**. They may appear only where nothing can follow them
on the same logical line.

### Spec edits

**LEX-033**: replace the second sentence with: "Whether a `:` that is followed by more tokens introduces a single-line
block is decided by the grammar (SYN-010); the lexer only checks the first sentence."

**New LEX-036 (Token contract).** "The layout algorithm terminates every logical line with `NEWLINE`, except a line
ending with a block `:`, which is terminated by `INDENT`. A `DEDENT` is never followed by `NEWLINE`."
Positive example: the §2.4 example. Negative example: none (this rule describes the lexer output; conformance tests
compare `egide lex` output).

**New SYN-015 (Block-ended expressions).** "`if`/`elif`/`else`, `match`, `loop`, `with`, `given`, `unsafe`, the `fn`
lambda (SYN-064) and a call with a trailing block (SYN-062) are block-ended expressions. A block-ended expression may
appear only (a) as a statement, (b) as the whole right-hand side of `let`, `var`, top-level `let` or an assignment.
Anywhere else, including as an operand, an argument, inside brackets or after `return`, it is a syntax error E0104
'this block-ended expression must stand alone; bind it with `let` first'."

```egide
let n = match c:          # OK: whole right-hand side of let
    case Red: 1
    case _: 0
let m = 1 + match c:      # error E0104
    case Red: 1
    case _: 0
```

**New SYN-016 (`if` and `loop` values).** "There is one `if` construct. An `if` without `else` has type `()`
(SYN-013 is unchanged). `loop` is an expression whose value is given by `break expr`; `break` with a value inside
`for` or `while` is a compile-time error."

**SYN-062**: replace "after the closing parenthesis of a call" with "after a call expression (the last postfix
operation before `fn` MUST be `( … )`)". Add: "The trailing lambda may declare a return type: `f(a) fn(x) -> T:`."
**SYN-064**: "A `fn` lambda (`fn(params) [-> T]: block`, or `fn: block` without parameters) is a block-ended
expression (SYN-015)."

**SYN-012**, Assignment row: "the left-hand side MUST be a place: a `var` binding, an `inout` parameter, `self` in
an `inout self` method, or a field `.f` or element `[i]` of a place; otherwise E0106 'cannot assign to this
expression'." The current `place = IDENT { … }` production is a reduce/reduce conflict with `primary` on `.` and `[`
and omits `self` (`self.count += 1` does not parse; Q-0008), so the parser reads a postfix expression and checks it.
Adding `"self"` as a root of `place` (Q-0008 option A) fixes the omission but keeps the conflict.

**Doc comments.** The replacement `file` production drops `[ doc_comment ]` (the current `file` starts with it, but
`doc_comment` is not a lexer terminal and is not defined). How `##` comments attach is open: see Q-0012.

**EBNF**: replace the `file`, declaration-body and statement sections with the following, and remove `if_expr`
and `match_expr` from `primary` and the `fn … : block` alternative from `lambda`:

```ebnf
file          = module_decl NEWLINE { import_decl NEWLINE } { top_decl } EOF ;
top_decl      = { attribute NEWLINE } [ "pub" ] decl ;
decl          = fn_decl | struct_decl | enum_decl | trait_decl | impl_decl | type_decl NEWLINE | const_decl ;
fn_decl       = fn_sig ":" suite ;
struct_decl   = "struct" IDENT [ generics ] ":" INDENT field NEWLINE { field NEWLINE } DEDENT ;
enum_decl     = "enum" IDENT [ generics ] ":" INDENT variant NEWLINE { variant NEWLINE } DEDENT ;
trait_decl    = "trait" IDENT [ generics ] [ ":" bound { "+" bound } ] ":" INDENT trait_item { trait_item } DEDENT ;
trait_item    = fn_sig NEWLINE | fn_decl | "type" IDENT [ ":" bound ] NEWLINE ;
impl_decl     = "impl" [ generics ] [ type "for" ] type ":" INDENT impl_item { impl_item } DEDENT ;
impl_item     = { attribute NEWLINE } [ "pub" ] fn_decl | "type" IDENT "=" type NEWLINE ;
const_decl    = [ "comptime" ] "let" IDENT [ ":" type ] "=" ( expr NEWLINE | block_expr ) ;

suite         = simple_stmt NEWLINE                          (* single-line block, SYN-061 *)
              | INDENT stmt { stmt } DEDENT ;                (* indented block *)
stmt          = simple_stmt NEWLINE | block_stmt ;
simple_stmt   = expr
              | "let" pattern [ ":" type ] "=" expr
              | "var" IDENT [ ":" type ] "=" expr
              | "comptime" "let" IDENT [ ":" type ] "=" expr
              | assign_target assign_op expr
              | "return" [ expr ] | "break" [ expr ] | "continue"
              | "defer" expr | "yield" expr ;
block_stmt    = block_expr
              | "let" pattern [ ":" type ] "=" ( block_expr | expr "else" ":" suite )
              | "var" IDENT [ ":" type ] "=" block_expr
              | assign_target assign_op block_expr
              | "for" pattern "in" expr ":" suite
              | "while" expr ":" suite ;
block_expr    = if_expr | match_expr | loop_expr | with_expr | given_expr | fn_lambda | trailing_call | unsafe_expr ;
if_expr       = "if" expr ":" suite { "elif" expr ":" suite } [ "else" ":" suite ] ;
match_expr    = "match" expr ":" INDENT case_arm { case_arm } DEDENT ;
case_arm      = "case" pattern [ "if" expr ] ":" suite ;
loop_expr     = "loop" ":" suite ;
with_expr     = "with" with_item { "," with_item } ":" suite ;
given_expr    = "given" expr { "," expr } ":" suite ;
fn_head       = "fn" [ "(" [ lambda_params ] ")" [ "->" type ] ] ;
fn_lambda     = fn_head ":" suite ;
trailing_call = postfix_expr "(" [ args ] ")" fn_head ":" suite ;   (* the call's own parentheses *)
unsafe_expr   = "unsafe" "(" IDENT ":" STRING ")" ":" suite ;   (* IDENT must be `reason` *)
assign_target = postfix_expr ;                                    (* MUST be a place, SYN-012; replaces `place` *)
```

Trace of the §2.4 example: `fn_sig ":" suite(INDENT block_stmt(if_expr: "if" expr ":" suite(INDENT x NEWLINE
DEDENT) "else" ":" suite(0 NEWLINE)) DEDENT) EOF`.

Checked mechanically (reproduction below): a Menhir transcription of this EBNF with ADR-0014's types (simplified literals, patterns and
bitwise levels; parenthesised lambda heads left out, see Q-0010) reports 0 conflicts. With the current `place`
production it reports a reduce/reduce conflict.

Consequences of the grammar, stated so tests can check them: a single-line block cannot contain a let-else, a
block-ended expression or a compound statement; `if c: a else: b` on one line is a syntax error (use
`a if c else b`); there is no dangling `else`, because a single-line block cannot contain an `if`.

Reproduction of the conflict check (not committed: the ADR template has no attachment slot, and the proposed
grammar is only a simplified transcription). Write each production above in Menhir syntax with tokens for the lexer
terminals, replace literals and patterns by a few representative alternatives, then run `menhir --explain file.mly`
and read `file.conflicts`. The scratch file used for this ADR (about 110 lines) is attached as a comment on PR #6.

## Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| A. Fix the EBNF to the existing layout (this ADR) | no lexer change; seed and T-0007 work stay valid; LR(1) | one more production class (`block_stmt`) | chosen |
| B. Change LEX-032 to emit Python's `NEWLINE INDENT` and keep the EBNF | EBNF closer to as-is | still needs fixes 2–6; changes implemented and tested lexer behaviour and the §2.4 example | more churn, same result |
| C. Allow block-ended expressions anywhere and let the parser figure it out | maximal freedom | `1 + match x:` and `f(if c: …)` are unreadable and not LR(1) with layout tokens | against ADR-0005 |
| D. Separate `if` statement and `if` expression | mirrors the current EBNF | reduce/reduce conflict; two AST nodes for one construct | conflict |

## Consequences

- Complexity budget: removes the stmt/expr duplication of `if`/`match`; adds one positional rule (SYN-015) with one
  diagnostic. Users gain `let x = retry() fn: …`, `let v = loop: …` and `with`/`given` values, which the examples
  already assume.
- Security: INT-001..005 are unaffected, with one tightening (`unsafe`, MEM-070; see SYN-017). The EBNF makes `unsafe(reason: …): block` (MEM-070,
  MEM-071, PKG-030) a `primary`, so it can be an operand (`f(unsafe(reason: "x"): …)`). SYN-015 restricts it to a
  statement or a whole right-hand side, so an `unsafe` block is always visible at the start of a line, which helps
  review and `egide audit`. SYN-017 cites MEM-070/MEM-071 for what `unsafe` permits and does not restate it. `security-reviewer` should confirm at the MVP review that no intended use is lost (for example `return unsafe(…): …` must now be bound with `let` first).
- Implementation: T-0008 (AST: one `If` node, `Match`/`Loop`/`With`/`Given`/`Lambda`/`TrailingCall` are expressions;
  a `Stmt.Expr` wrapper), T-0009/T-0010/T-0011/T-0012 use this EBNF, T-0013 recovers at `NEWLINE` or `DEDENT`.
  T-0007 (layout) is unaffected. Add E0104 and E0106 to `docs/diagnostics.md`. Add `egide lex` conformance tests for LEX-036.
- Migration: none (pre-1.0, no released code).
- Index: row added to `docs/adr/README.md`.

## Changes made when accepting (differences from the Proposed text)

- `[ doc_comment ]` is dropped from `file`; comments produce no token (EBNF header). How `##` attaches is Q-0012,
  decided in ADR-0016.
- `suite` uses `single_stmt` (no `let`/`var`) as the single-line form, per Q-0020 item 1 (ADR-0015).
- Spec text lives in SYN-005, SYN-010, SYN-012, SYN-015, SYN-016, SYN-017, SYN-061, SYN-062, SYN-064, LEX-033, LEX-036.
- Diagnostics E0104 (SYN-015), E0106 (SYN-012, SYN-033) and E0110 (SYN-017) are added to `docs/diagnostics.md`.
- The Menhir transcription was re-run on the final EBNF (see ADR-0015, `attachments/0013-menhir-check.mly`): 0 conflicts.
- Found while transcribing: `primary = … | path` and the postfix `.` IDENT were ambiguous; `primary` now has `IDENT`
  and `a.b` is always a postfix expression, resolved by name resolution (module path or field).
