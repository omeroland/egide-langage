---
id: Q-0002
rule: LEX-032
raised_by: syntax-engineer/wave1
blocking: [T-0010]
---
## Question

Chapter 2 and chapter 3 disagree on where the layout tokens `NEWLINE`, `INDENT` and `DEDENT` occur around a
block. Which one is normative?

- LEX-032 step 2 emits only `INDENT` after a block colon, and the §2.4 example shows `… : INDENT IF …`, with no
  `NEWLINE` before `INDENT`. Step 3 emits **one** `NEWLINE` and then one `DEDENT` per closed block. LEX-034 does
  the same at end of file.
- SYN-010 and the EBNF (`block = NEWLINE INDENT stmt { NEWLINE stmt } NEWLINE DEDENT`, and also `struct_decl`,
  `enum_decl`, `trait_decl`, `impl_decl`, `match_expr`) expect `NEWLINE` before `INDENT`, and `NEWLINE` before
  **every** `DEDENT`. `if_stmt` also expects `NEWLINE "else"` after a block.

## Example

```egide
fn f(x: int) -> int:
    if x > 0:
        x
    else: 0
```

LEX-032 (as implemented in `layout.ml`, T-0007) gives
`fn f ( x : int ) -> int : INDENT if x > 0 : INDENT x NEWLINE DEDENT else : 0 NEWLINE DEDENT EOF`.
The EBNF needs `: NEWLINE INDENT` twice. After the inner block has consumed `NEWLINE DEDENT`, it then needs
`NEWLINE else`, but the stream has `else` directly. Nested blocks closing on the same line give
`NEWLINE DEDENT DEDENT`, but the EBNF needs `NEWLINE DEDENT NEWLINE DEDENT`.

## Options

A. LEX-032/034 are normative. Restate SYN-010 and the EBNF on the actual stream, for example
   `block = INDENT stmt { NEWLINE stmt } [ NEWLINE ] DEDENT | simple_stmt` (closing `NEWLINE` optional, because a
   nested block has already consumed it). Make `NEWLINE` before `elif`/`else` optional to match.
B. The EBNF is normative. Change LEX-032 step 2 to emit `NEWLINE INDENT`, and step 3/LEX-034 to emit
   `NEWLINE DEDENT` per closed block. Update the §2.4 example.

## Recommendation

A. The lexical rules come with a worked token-by-token example and are already implemented and tested
(`compiler/test/syntax/test_layout.ml`). The fix is confined to the grammar productions, which the parser tasks
(T-0009..T-0012) have to write anyway. Until this is answered, `layout.ml` follows LEX-032 literally.
