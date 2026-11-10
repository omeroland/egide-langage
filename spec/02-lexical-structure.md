# 2. Lexical structure

## 2.1 Source text

- **[LEX-001]** A source file is a sequence of Unicode scalar values encoded in UTF-8. Invalid UTF-8 is a compile-time
  error. A byte-order mark is a compile-time error.
- **[LEX-002]** Source files use the extension `.egd`. Line terminators are LF (`U+000A`); CR LF is accepted and
  normalised to LF; a lone CR is a compile-time error.
- **[LEX-003]** The following code points are forbidden **anywhere** in a source file, including comments and string
  literals, to defeat "Trojan Source" attacks (CVE-2021-42574), hidden-text smuggling (TAG characters, variation
  selectors) and invisible-character confusion (E0004):
  1. all characters of general category `Cf` (format): this includes the bidirectional controls `U+061C`, `U+200E`,
     `U+200F`, `U+202A`–`U+202E`, `U+2066`–`U+2069`, the zero-width characters `U+200B`–`U+200D`, `U+2060`, `U+FEFF`,
     `U+00AD`, `U+180E`, `U+2061`–`U+2064`, `U+206A`–`U+206F`, `U+FFF9`–`U+FFFB` and the TAG characters
     `U+E0000`–`U+E007F`;
  2. the variation selectors `U+FE00`–`U+FE0F`, `U+E0100`–`U+E01EF`, `U+180B`–`U+180D`, `U+180F` (category `Mn`),
     the combining grapheme joiner `U+034F` and the Hangul fillers `U+115F`, `U+1160`, `U+3164`, `U+FFA0` (category
     `Lo`), which render as nothing or as blank;
  3. line and paragraph separators `U+2028`, `U+2029`;
  4. all other characters of general category `Cc` except LF and, inside string literals only, HT (`U+0009`).

  Categories are those of Unicode 16.0; a code point that a later Unicode version adds to `Cf` is forbidden from the
  first compiler release that adopts that version. **There is no allowlist**: not even the zero-width joiner or
  non-joiner, nor `U+FE0F` after an emoji. A string literal that needs such a character writes it with an escape
  (`"\u{200D}"`, `"\u{2764}\u{FE0F}"`, LEX-050), which is visible in the source and reviewable. An allowlist can be added
  later without breaking any program; removing one could not.
- **[LEX-004]** The horizontal tab `U+0009` MUST NOT appear outside string literals. Indentation uses spaces only.
- **[LEX-005] Display order of right-to-left text (non-goal, warning only).** Strong right-to-left letters (bidi class
  `R` or `AL`) are not forbidden: they are legitimate text in strings and comments, and identifiers cannot contain
  them (LEX-020). They can still make an editor display the rest of the line in a different order than it is lexed,
  without changing the tokens. The compiler therefore does not reject them, and warns (W0001) when a string literal
  or comment on a line contains such a letter and any token follows it on the same line; the fix is to bind the string
  with `let` on its own line. The warning is a review aid, not a security guarantee (the Trojan Source defence is LEX-003).

## 2.2 Comments

- **[LEX-010]** `#` starts a comment that extends to the end of the line. There are no block comments.
- **[LEX-011]** A comment starting with `##` is a **documentation comment**. A maximal run of consecutive `##` lines
  with no blank line after it documents the module declaration, top-level declaration, field, variant, trait item or
  impl item that follows directly (a run before `module` documents the module). Any other `##` comment (inside a
  function body, after code on the same line, at the end of the file, before `import`, or followed by a blank line) is
  warning W0002 "doc comment is not attached to a declaration". Its content is Markdown; fenced code blocks tagged `egide` inside it are compiled and run as tests by `egide test`
  (doctests, TOOL-030).
- **[LEX-012]** A first line starting with `#!` is a shebang and is ignored.

## 2.3 Identifiers and keywords

- **[LEX-020]** Identifiers match `[A-Za-z_][A-Za-z0-9_]*`. Identifiers are ASCII only (INT-010). An identifier that is a
  single `_` is the wildcard and cannot be read.
- **[LEX-021]** Reserved keywords:

  ```
  and      as       break    case     comptime continue defer    dyn      elif     else
  enum     false    fn       for      given    if       impl     import   in       inout
  let      loop     match    module   new      not      or       pub      return   self
  Self     struct   take     trait    true     type     unsafe   using    var      where
  while    with     yield
  ```

- **[LEX-022]** `go` is a contextual keyword: it is a keyword only immediately after `import`. Elsewhere it is an
  ordinary identifier (the conventional name of the `Go` capability, GO-010).
- **[LEX-023]** Naming conventions are enforced by the compiler as **warnings** and by `egide fmt --check` as errors:
  types, traits and enum variants in `UpperCamelCase`; functions, variables, fields and modules in `snake_case`;
  `comptime` constants in `SCREAMING_SNAKE_CASE`.

## 2.4 Layout (indentation)

Égide blocks are delimited by indentation. The lexer converts indentation into `NEWLINE`, `INDENT` and `DEDENT` tokens,
so the grammar (ch. 3) is context-free.

- **[LEX-030] Logical lines.** A logical line is one or more physical lines. Physical lines are joined into one logical
  line when (a) the line break occurs inside an open `(`, `[` or `{` (implicit joining, as in Python), or
  (b) the next non-blank physical line is indented **more** than the first physical line of the current logical line
  **and** its first token is one of `|>`, `.`, `and`, `or` (continuation lines for pipelines, method chains and long
  conditions). There is no backslash continuation. A line that directly follows a line ending with a block `:` is never a
  continuation line (LEX-033 wins). A line break inside a token (a `"""` string or template) does not end a physical
  line for layout; only the first token of each physical line is measured.
- **[LEX-031] Blank lines and comments.** Physical lines containing only spaces and/or a comment do not produce tokens
  and do not affect indentation. Comments never produce tokens, but the lexer records every comment (kind `#`, `##` or
  `#!`, span, text) in a side table of trivia that the parser (LEX-011), `egide fmt` and the discard check (ERR-002)
  read.
- **[LEX-032] Indentation stack.** The lexer keeps a stack of indentation widths, initially `[0]`. At the start of each
  logical line, with width *w* (number of leading spaces) and top of stack *t*:
  1. if *w* = *t*: emit `NEWLINE` (except before the first logical line of the file);
  2. if *w* > *t*: the last token of the previous logical line MUST be `:` (otherwise compile-time error
     "unexpected indentation"), *w* MUST equal *b* + 4, where *b* is the indentation of the last physical line of the
     previous logical line if that line is a continuation line (LEX-030 b) and *b* = *t* otherwise (otherwise
     "indentation must be 4 spaces"); push *w*; emit `INDENT`;
  The first logical line of a file MUST have width 0 (E0020). A dedent to a width that is not on the stack, for
  example to *b* after a block opened below a continuation line, is "inconsistent dedent".
  3. if *w* < *t*: emit `NEWLINE`, then pop and emit one `DEDENT` per popped width until the top equals *w*;
     if no stack entry equals *w*, compile-time error "inconsistent dedent".
- **[LEX-033] Block colon.** A `:` that is the last token of a logical line MUST be followed by an `INDENT`
  (otherwise compile-time error "expected an indented block"). A `:` followed by more tokens on the same logical line
  introduces a **single-line block** containing exactly one simple statement (SYN-061); no `INDENT` is emitted. The lexer
  does not decide whether a `:` followed by more tokens opens a block (the same token is also a type annotation, a named
  argument and a map entry separator); the grammar does (SYN-010).
- **[LEX-034] End of file.** At end of file the lexer emits `NEWLINE` (if the last logical line was not empty), then
  one `DEDENT` per stack entry above `0`, then `EOF`.
- **[LEX-035]** Inside brackets (LEX-030 a), indentation is not significant and no layout tokens are produced.
- **[LEX-036] Token contract.** The layout algorithm terminates every logical line with `NEWLINE`, except a line that
  ends with a block `:`, which is terminated by `INDENT`. A `DEDENT` is never followed by `NEWLINE`. The grammar
  (ch. 3) is written against exactly this stream: a block ends with `DEDENT`, a single-line block with the `NEWLINE`
  of its line. Conformance tests compare `egide lex` output with the §2.4 example.

Example (tokens on the right):

```egide decls
fn f(x: int) -> int:          # FN IDENT ( IDENT : IDENT ) -> IDENT :
    if x > 0:                 # INDENT IF IDENT > INT :
        x                     # INDENT IDENT
    else: 0                   # NEWLINE DEDENT ELSE : INT
                              # NEWLINE DEDENT EOF
```

## 2.5 Numeric literals

- **[LEX-040]** Integer literals: decimal `123`, hexadecimal `0x7F`, octal `0o755`, binary `0b1010`. `_` may separate
  digits (`1_000_000`) but not start or end a literal, follow a prefix, or be doubled (`1__0`). Prefixes are lowercase
  only (`0X1F` is an error); hexadecimal digits may be either case. A decimal literal with a leading `0` followed by a
  digit or `_` (`0755`) is an error with the hint "write 0o755 for octal". A numeric literal immediately followed by an
  identifier character (`5ms`, `0X1F`, `12abc`) is an error. All of these are E0030. A literal whose value does not
  fit its inferred type is a compile-time error.
- **[LEX-041]** Float literals: `1.5`, `1e9`, `2.5e-3`, `1e+9`, `1_000.25`. A dot MUST be followed by a digit for the
  literal to be a float (`5.s` is not a float, see LEX-042), and a float has digits before the dot (`.5` lexes as `.`
  and `5`, a syntax error). The exponent letter is lowercase `e` (`1E9` is E0031). `_` may separate digits of the
  fraction and the exponent with the restrictions of LEX-040. Tuples have no `t.0` element access (SYN-038), so a digit
  after `.` never needs special lexing.
- **[LEX-042] Duration literals.** A **decimal** integer literal immediately followed by `.` and one of the unit names
  `ns`, `us`, `ms`, `s`, `min`, `h`, where the unit is not followed by an identifier character, forms a single
  `DURATION` token of type `std.time.Duration`: `500.ms`, `5.s`, `30.min`. No whitespace is allowed inside the token.
  Otherwise the lexer produces `INT`, `.`, `IDENT`: `5.msg` is a field or method access on `5`, `5.s2` likewise, and
  `0x10.s` is `INT . IDENT`.

## 2.6 String and character literals

- **[LEX-050]** String literals are delimited by `"`. Escapes: `\\`, `\"`, `\n`, `\t`, `\r`, `\0`, `\{`, `\}`,
  `\u{H…}` (1–6 hex digits, any Unicode scalar value: surrogates and values above `10FFFF` are errors; characters
  forbidden by LEX-003 are allowed here, because the escape makes them visible). Any other escape is an error (E0041).
  A raw LF inside `"…"` is an error.
- **[LEX-051]** Triple-quoted strings `"""…"""` may span lines. The common leading indentation of their content lines
  is removed, as with Python's `textwrap.dedent`, but on the **raw source lines before escape processing**; whitespace-only
  lines are ignored for the margin and become empty; the first line break after the opening `"""` is dropped and the
  line break before the closing `"""` is kept. A tab in the margin is E0005 (LEX-004).
- **[LEX-052]** Raw strings `r"…"` and `r"""…"""` process no escapes.
- **[LEX-053]** Byte strings `b"…"` have type `Bytes` and accept printable ASCII (`U+0020`–`U+007E`) and the escapes
  `\\ \" \n \t \r \0 \xHH`; no `\u{…}` and no other character (E0043). There is no `rb"…"`.
- **[LEX-054]** Character literals `'a'`, `'\n'`, `'\u{E9}'` have type `char` (a Unicode scalar value). Escapes are those
  of LEX-050 except `\{` and `\}`, plus `\'`. The literal holds exactly one scalar value (`''` and `'ab'` are E0042),
  and a raw tab is not allowed: write `'\t'`.
- **[LEX-055] Prefixed templates.** An identifier in `lower_snake_case`, other than `r` and `b` and not a keyword
  (`return"x"` is `return` followed by a string), immediately followed by `"` or `"""` forms a `TEMPLATE` token:
  `f"…"`, `sql"…"`, `html"…"`, `cmd"…"`, `url"…"`, `path"…"`, `re"…"`. The lexer splits the literal into **literal
  parts** and **interpolations**:
  - Literal parts are **raw**: the lexer processes no escape. A backslash only protects the next character from
    ending the literal or opening an interpolation (`\"` does not end it); both characters are kept. `{{` and `}}`
    are the only lexer-level escapes and stand for one brace. Regex quantifiers therefore need doubled braces:
    `re"^[a-z][a-z0-9-]{{2,62}}$"`. LEX-003 applies to the source text.
  - An interpolation is `{` expr [ `:` spec ] `}`. The expression ends at the first `:` or `}` outside any bracket
    pair (`()`, `[]`, `{}`; nested string and template literals are tracked, so `f"{m["k"]}"` and `f"{ {1, 2} }"` work).
    `spec` is raw text without `{`, `}`, `"` or a line break. A line break inside `{…}` is allowed only in `"""`
    templates. Unterminated or malformed interpolations are E0044.
  - A `"""` template is dedented as in LEX-051 before it is split. There is no raw template form; all are raw.

  The meaning of the prefix, including how literal parts are unescaped, is given by a `comptime` template function
  (CT-040): `f` applies the escapes of LEX-050 to literal parts, `re` passes backslashes to the regex compiler. Only
  `f`, and prefixes that declare a spec grammar in their `@template` registration, accept a `:spec`; the sink
  templates (`sql`, `html`, `cmd`, `url`, `path`, ch. 12) MUST reject it (E0601), so that a spec string is never an
  unreviewed channel into a sink. Interpolated expressions are tokenised recursively; templates may nest.

## 2.7 Operators and punctuation

```
+   -   *   /   %   **  ==  !=  <   <=  >   >=  =   +=  -=  *=  /=  %=
&   |   ^   ~   <<  >>  &=  |=  ^=  <<= >>=
->  =>  |>  ?   .   ..  ..= ,   :   ;   @   (   )   [   ]   {   }
```

- **[LEX-060]** Tokens are formed by maximal munch (`a..==b` lexes as `a`, `..=`, `=` and is a syntax error).
- **[LEX-061]** `;` is reserved and currently a compile-time error with the hint "statements end at line breaks".
- **[LEX-062]** `**` is exponentiation on numeric types; it is right-associative (SYN-100).
