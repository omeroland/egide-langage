---
id: Q-0003
rule: LEX-011, LEX-031, SYN-001, ERR-002, TOOL-030
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0008, T-0009, T-0006]
severity: medium
status: open
---
## Question

Comments are semantically significant in two places, but the lexical model throws them away:

1. **Doc comments.** LEX-011 says `##` "attaches to the declaration that follows", and `egide test` runs its
   fenced `egide` blocks (TOOL-030). LEX-031 says comment lines "do not produce tokens", and the seed lexer drops all
   `#…` text. The EBNF uses `file = [ doc_comment ] module_decl`, but `doc_comment` is not in its list of lexer
   terminals and is not defined. It is also unspecified:
   - which declarations a doc comment can attach to (module? fields, variants, trait items, impl items?);
   - what happens with a `##` that precedes nothing attachable (inside a function body, at end of file, before
     `import`, as a trailing `x = 1  ## doc`);
   - whether a blank line between the `##` block and the declaration breaks the attachment.
2. **Discard reason (ERR-002).** `let _ = f()  # ignored: <reason>`: "the comment is mandatory and `egide audit`
   lists these sites". So the comment on that line must reach the checker.

## Example

```egide
## Module docs.                  # (a) before `module`: allowed by the EBNF
module m

## A tenant.                     # (b) attaches to struct Tenant
struct Tenant:
    ## The id.                   # (c) field: attaches?
    id: int

fn f():
    ## stray                     # (d) error, warning or plain comment?
    let _ = g()  # ignored: best effort   # (e) must be visible to the ERR-002 check
```

## Options

A. **Trivia side table.** The lexer records every comment (span, kind `#`, `##` or `#!`, text) in a side table and
   still emits no token. The parser attaches the maximal run of `##` lines directly above (no blank line in between) a
   module, top-level, field, variant, trait item or impl item declaration. Any other `##` gets a warning (code in W00xx, allocated by the implementing task) "doc comment
   is not attached to a declaration". The ERR-002 check looks up the comment that ends the statement's last line.
   Remove `doc_comment` from the EBNF and state the attachment rule in prose.
B. A `DOC_COMMENT` token, with grammar positions before every attachable declaration. This makes the grammar noisier,
   and a stray `##` becomes a syntax error, which is harsh for a comment.
C. Replace the ERR-002 comment with syntax, e.g. `let _ = f()  # ignored: …` → `discard f(), reason: "…"`. This is
   cleaner for tooling but adds a keyword (complexity budget).

## Recommendation

A, plus keep ERR-002 as written: the side table makes it implementable, and it does not grow the grammar. T-0008
(AST: `doc: string option` on attachable nodes, comment table in `Ast.file`), T-0009 (attachment), and T-0006 or a
follow-up lexer task (keep comments instead of skipping them) are affected.
