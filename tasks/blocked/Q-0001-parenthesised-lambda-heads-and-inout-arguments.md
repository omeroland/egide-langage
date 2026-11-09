---
id: Q-0001
rule: SYN-060, SYN-033, MEM-022, SYN-100
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0011, T-0008]
severity: high
status: open
---
## Question

The EBNF says it is LR(1) (header, ADR-0005), but two expression productions are not:

1. **Parenthesised lambda heads.** `lambda_head = IDENT | "(" [ lambda_params ] ")"` competes with
   `"(" expr ")"` and tuples `"(" expr "," … ")"`. The parser cannot know whether `(a, b` starts a tuple or the
   parameters of `(a, b) => a + b` until it sees `=>`. Typed and moded parameters (`(x: int) => x`,
   `(inout acc, x) => …`) are not expressions at all. A Menhir transcription reports 2 shift/reduce conflicts for this
   production alone (T-0022 log).
2. **`&` arguments.** `arg = [ IDENT ":" ] [ "&" ] expr` accepts `&f(x)`, `&(a + b)` and `&xs[i] + 1`. SYN-033 says
   `&place`, and MEM-022 checks exclusivity "using only the syntax of the arguments", so a non-place after `&` must be
   rejected somewhere. No rule or diagnostic says where.

## Example

```egide
let add = (a, b) => a + b            # lambda
let pair = (a, b)                    # tuple: same prefix
let f = (x: int) => x * 2            # `x: int` is not an expression
add_line(&cart.lines[0], item)       # place: OK
add_line(&make_cart(), item)         # not a place: which error, from which pass?
```

## Options

A. **Cover grammar** (what JavaScript and TypeScript parsers do). The parser reads `( item, … )` where
   `item = [ "inout" | "take" ] expr [ ":" type ]`. If `=>` follows, every item MUST be a lambda parameter
   (`[mode] IDENT [: type]`); otherwise every item MUST be an expression with no mode and no annotation. Violations:
   syntax error E0107 "invalid lambda parameter" / "type annotation outside a lambda parameter list".
   `arg = [ IDENT ":" ] ( expr | "&" postfix_expr )`, and the postfix expression MUST be a place (the same check as
   the assignment target in ADR-0013, diagnostic E0106).
B. Mark multi-parameter short lambdas with a keyword, e.g. `fn(a, b) => a + b`. This is LR(1) without a cover grammar,
   but ADR-0014 uses `fn(…)` for function types inside `[ … ]`, so the conflict moves there. It also changes SYN-060.
C. Only single-parameter short lambdas (`x => e`); several parameters need a trailing block. This is too restrictive
   for `reduce`, `sort_by` and similar.

## Recommendation

A. Spec edits: add to the ch. 3 introduction "The EBNF is normative for the accepted language. `parser.mly` may parse a
larger *cover* language and reject the excess in post-parse checks, each with a diagnostic". Write `lambda_head` and
`arg` as above in the EBNF, with a comment that marks the cover. Affects the T-0008 AST (`Arg.Inout of expr`, checked
place) and T-0011.
