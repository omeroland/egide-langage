---
id: Q-0007
rule: LEX-030, LEX-032, LEX-033, LEX-031
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0007]
severity: medium
status: open
---
## Question

1. **Block body after a continuation line.** LEX-032 step 2 requires the body to be at *t* + 4, where *t* is the
   indentation of the first physical line of the logical line. When the line ending in `:` is a continuation line
   (LEX-030 b), the natural body indentation is rejected with E0021. The illustrative example in `agents/escalation.md`
   (its sample spec-question) is therefore invalid under the current spec:

   ```egide
   server
       .route("/x") fn(req):
           ok()                   # w = 8, t = 0: E0021 "indentation must be 4 spaces"
   ```

   The accepted form puts the body at column 4, level with the continuation lines:

   ```egide
   if user.is_admin()
       and request.is_local():
       allow()                    # same column as `and`: legal but misleading
   ```

2. **Rule order.** After a line ending with a block `:`, a more-indented line starting with `.`, `|>`, `and` or `or`
   matches both LEX-030 (b) (join) and LEX-032 step 2 (open a block). Which one applies?
3. **Multi-line tokens.** LEX-030 does not say that a line break inside a `"""` string or template does not end the
   logical line, or that the indentation of the lines inside it is not layout. The seed `layout.ml` does this
   correctly by looking at token start lines, but no rule states it.
4. **Indented first line.** No rule covers a file whose first logical line is indented. The seed reports E0020.

## Options for item 1

A. Keep the current rule and document the `if … and …:` style above. This adds no lexer change.
B. The body width is "indentation of the **last physical line** of the logical line + 4". That width is pushed
   on the stack. Dedent works unchanged, because popping returns to *t*.
C. Forbid a block `:` on a continuation line (E0024): chains with trailing blocks must bind first. This is the most
   restrictive option.

## Recommendation

1. B: it matches what readers expect, it is a one-line change to step 2, and the stack stays consistent. Positive
   test: the escalation example. Negative test: body at 4 after a continuation line at 4.
2. A line that directly follows a line ending with a block `:` is never a continuation line. LEX-033 wins.
3. Add to LEX-030: "A line break inside a token (multi-line string or template) does not end a physical line for
   layout purposes. Only the first token of each physical line is measured."
4. Add to LEX-032: "The first logical line MUST have width 0 (E0020)."
