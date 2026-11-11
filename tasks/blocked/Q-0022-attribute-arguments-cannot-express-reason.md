---
id: Q-0022
rule: SYN-023, SYN-018, GO-032
raised_by: syntax-engineer/session_01NLgEFTLJgCm5Sfk4YuTzRp (T-1030)
blocking: []
severity: medium
status: open
---
## Question

**Executive summary.** The EBNF cannot parse the one attribute argument form that the SYN-023 table requires,
`@go_threadsafe(reason: "…")`; the AST (`attribute.args`) has no place for a label either.

## Core analysis (established from the text of the grammar and the table)

`attribute = "@" IDENT [ "(" [ expr_list ] ")" ]` and `expr_list = expr { "," expr }`. The SYN-023 table lists the
argument of `@go_threadsafe` as `reason: "…" (SYN-018), mandatory`. `reason: "x"` is not an `expr` (it is a
`map_entry` shape, which is only valid inside `{ … }`), so no derivation of `attribute` produces it. `unsafe` solved
the same problem by using `IDENT ":" STRING` in its own production. `@template("p")`, `@derive(Eq, Show)` are
plain expressions and are fine.

## Example

```egide
@go_threadsafe(reason: "client-go clients are documented as goroutine-safe")
type Clientset = kube.Clientset
```

## Options

A. `attribute = "@" IDENT [ "(" [ attr_args ] ")" ]` with `attr_args = attr_arg { "," attr_arg } [ "," ]` and
   `attr_arg = [ IDENT ":" ] expr`. AST: `attribute.args : attr_arg list option` (label option and expr). The target
   check (SYN-023 table) then also checks the labels (E0117).
B. Reuse `args` (the call argument list, minus `&` and `using`). Same AST as a call: `arg list option`. One
   production fewer, but `&x` and `using` need a post-parse rejection.
C. Make the reason positional: `@go_threadsafe("reason")`. No grammar change; loses the self-documenting label.

## Recommendation

A (labelled arguments only where the table needs them; the closed attribute set keeps the surface small). The AST
change is local (`attribute.args`). Until decided, `attribute.args` stays `expr list option`. Only `@go_threadsafe` is blocked (T-0009 carves that test
out; its Log says so). Option A does not change the E0107 attribute PoC
(`tests/security/syntax/cover_annotation_in_attribute_argument.egd`, `@derive((a: int))`): a parenthesised item is still
an `expr`, so the cover check applies unchanged.
