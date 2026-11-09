---
id: Q-0014
rule: LEX-055, LEX-050, LEX-003, CT-040, CT-041
raised_by: language-architect/wave1 (T-0022)
blocking: [T-0005, T-0055]
severity: high
status: open
---
## Question

LEX-055 leaves out what the lexer needs to know to tokenise a template:

1. **Braces in the literal text.** `examples/tenants_api.egd` has `re"^[a-z][a-z0-9-]{2,62}$"`. Under LEX-055,
   `{2,62}` is an interpolation of the expression `2,62`, so the example is invalid and needs `{{2,62}}`. Regex
   quantifiers, CSS/JS in `html"…"` and JSON in `sql"…"` hit this constantly.
2. **Escapes.** It is not said whether LEX-050 escapes apply to template literal parts. If they do, `re"\d+"` is an
   error (`\d` is not a LEX-050 escape) and users must write `re"\\d+"`. If they do not, `f"a\nb"` contains a
   backslash and an `n`.
3. **Format specifiers.** CT-041 says `f` checks "format specifiers" at compile time, but there is no syntax for them.
   If `f"{x:>8}"` is meant, the lexer must know that `:>8` ends the expression, otherwise it tokenises `: > 8`.
4. **Where an interpolation ends.** The text says "recursively" but not how `}` inside the expression is handled
   (`f"{ {1, 2} }"`, `f"{m["k"]}"` with nested quotes), or whether newlines are allowed inside `{…}` of a `"""`
   template.
5. **Prefixes that are keywords.** `return"x"`, `in"x"`, `not"x"` and `and"x"` are lower_snake identifiers that are
   immediately followed by `"`. As written they form TEMPLATE tokens.
6. **Raw and triple-quoted templates.** Are `f"""…"""` templates dedented like LEX-051? Is there a raw template form?

## Options and recommendation

Recommended spec text for LEX-055 (each point can be decided separately):

- (a) The lexer does not process escapes in template literal parts. It passes them **raw**, together with their
  spans, to the template function (CT-040). `{{` and `}}` are the only lexer-level escapes. The `f` template applies
  LEX-050 escapes. `re` passes backslashes to the regex compiler. LEX-003 still applies to the source text. This
  fixes items 1 and 2 for `re` (`\d` works). Item 1 is fixed by writing `{{2,62}}` in the example.
- (b) An interpolation is `{` expr [ `:` spec ] `}`. The expression ends at the first `:` or `}` at bracket depth 0
  (brackets and nested string/template literals are tracked). `spec` is raw text without `{`, `}`, `"` or a line
  break, and the template function interprets it (`f`: CT-041). A line break inside `{…}` is allowed only in `"""`
  templates.
- (c) A keyword is never a template prefix (`return"x"` is `return` followed by a string).
- (d) `p"""…"""` templates are dedented as in LEX-051 before the literal parts are split. There is no raw template
  form: with (a), all templates are already raw.

Alternative to (a): process LEX-050 escapes in every template and require `\\d` in regexes. It is simpler for the
lexer, but every regex becomes harder to read and the example still breaks on `{2,62}`.

Security note for `security-reviewer`: with (a), the `sql`, `html`, `cmd`, `url` and `path` template functions
(ch. 12) receive exactly the source text, which keeps their escaping decisions in one place.
