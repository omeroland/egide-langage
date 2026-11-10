# 2. Lexical structure

## 2.1 Source text

- **[LEX-001]** A source file is a sequence of Unicode scalar values encoded in UTF-8. Invalid UTF-8 is a compile-time
  error. A byte-order mark is a compile-time error.
- **[LEX-002]** Source files use the extension `.egd`. Line terminators are LF (`U+000A`); CR LF is accepted and
  normalised to LF; a lone CR is a compile-time error.
- **[LEX-003]** The following code points are forbidden **anywhere** in a source file, including comments and string
  literals, to defeat "Trojan Source" attacks (CVE-2021-42574) and invisible-character confusion:
  bidirectional controls `U+061C`, `U+200E`, `U+200F`, `U+202A`–`U+202E`, `U+2066`–`U+2069`;
  zero-width and invisible characters `U+200B`–`U+200D`, `U+2060`, `U+FEFF`;
  line and paragraph separators `U+2028`, `U+2029`; all other characters of general category `Cc` except LF and, inside
  string literals only, HT (`U+0009`). String literals that need such characters use escapes (§2.6).
- **[LEX-004]** The horizontal tab `U+0009` MUST NOT appear outside string literals. Indentation uses spaces only.

## 2.2 Comments

- **[LEX-010]** `#` starts a comment that extends to the end of the line. There are no block comments.
- **[LEX-011]** A comment starting with `##` is a **documentation comment**. It attaches to the declaration that follows.
  Its content is Markdown; fenced code blocks tagged `egide` inside it are compiled and run as tests by `egide test`
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
  conditions). There is no backslash continuation.
- **[LEX-031] Blank lines.** Physical lines containing only spaces and/or a comment do not produce tokens and do not
  affect indentation.
- **[LEX-032] Indentation stack.** The lexer keeps a stack of indentation widths, initially `[0]`. At the start of each
  logical line, with width *w* (number of leading spaces) and top of stack *t*:
  1. if *w* = *t*: emit `NEWLINE` (except before the first logical line of the file);
  2. if *w* > *t*: the last token of the previous logical line MUST be `:` (otherwise compile-time error
     "unexpected indentation"), *w* MUST equal *t* + 4 (otherwise "indentation must be 4 spaces"); push *w*;
     emit `INDENT`;
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

```egide
fn f(x: int) -> int:          # FN IDENT ( IDENT : IDENT ) -> IDENT :
    if x > 0:                 # INDENT IF IDENT > INT :
        x                     # INDENT IDENT
    else: 0                   # NEWLINE DEDENT ELSE : INT
                              # NEWLINE DEDENT EOF
```

## 2.5 Numeric literals

- **[LEX-040]** Integer literals: decimal `123`, hexadecimal `0x7F`, octal `0o755`, binary `0b1010`. `_` may separate
  digits (`1_000_000`) but not start or end a literal or follow a prefix. A literal whose value does not fit its
  inferred type is a compile-time error.
- **[LEX-041]** Float literals: `1.5`, `1e9`, `2.5e-3`, `1_000.25`. A dot MUST be followed by a digit for the literal to
  be a float (`5.s` is not a float, see LEX-042).
- **[LEX-042] Duration literals.** An integer literal immediately followed by `.` and one of the unit names
  `ns`, `us`, `ms`, `s`, `min`, `h` forms a single `DURATION` token of type `std.time.Duration`: `500.ms`, `5.s`,
  `30.min`. No whitespace is allowed inside the token.

## 2.6 String and character literals

- **[LEX-050]** String literals are delimited by `"`. Escapes: `\\`, `\"`, `\n`, `\t`, `\r`, `\0`, `\{`, `\}`,
  `\u{H…}` (1–6 hex digits, a Unicode scalar value that is not forbidden by LEX-003). Any other escape is an error.
  A raw LF inside `"…"` is an error.
- **[LEX-051]** Triple-quoted strings `"""…"""` may span lines. The common leading indentation of their content lines
  is removed, as with Python's `textwrap.dedent`; the first line break after the opening `"""` is dropped.
- **[LEX-052]** Raw strings `r"…"` and `r"""…"""` process no escapes.
- **[LEX-053]** Byte strings `b"…"` have type `Bytes` and accept only ASCII characters and `\xHH` escapes.
- **[LEX-054]** Character literals `'a'`, `'\n'`, `'\u{E9}'` have type `char` (a Unicode scalar value).
- **[LEX-055] Prefixed templates.** An identifier in `lower_snake_case`, other than `r` and `b`, immediately followed by
  `"` or `"""` forms a `TEMPLATE` token: `f"…"`, `sql"…"`, `html"…"`, `cmd"…"`, `url"…"`, `path"…"`, `re"…"`.
  Inside a template, `{expr}` is an interpolation; `{{` and `}}` are literal braces. The lexer tokenises interpolated
  expressions recursively; nesting of templates inside interpolations is allowed. The meaning of the prefix is given by
  a `comptime` template function (CT-040).

## 2.7 Operators and punctuation

```
+   -   *   /   %   **  ==  !=  <   <=  >   >=  =   +=  -=  *=  /=  %=
&   |   ^   ~   <<  >>  &=  |=  ^=  <<= >>=
->  =>  |>  ?   .   ..  ..= ,   :   ;   @   (   )   [   ]   {   }
```

- **[LEX-060]** Tokens are formed by maximal munch (`a..==b` lexes as `a`, `..=`, `=` and is a syntax error).
- **[LEX-061]** `;` is reserved and currently a compile-time error with the hint "statements end at line breaks".
- **[LEX-062]** `**` is exponentiation on numeric types; it is right-associative (SYN-100).
