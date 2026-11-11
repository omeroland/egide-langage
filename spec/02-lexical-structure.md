# 2. Lexical structure

## 2.1 Source text

- **[LEX-001]** A source file is a sequence of Unicode scalar values encoded in UTF-8. Invalid UTF-8 is a compile-time
  error. A byte-order mark is a compile-time error.
- **[LEX-002]** Source files use the extension `.egd`. Line terminators are LF (`U+000A`); CR LF is accepted and
  normalised to LF; a lone CR is a compile-time error.
- **[LEX-003]** The following code points are forbidden **anywhere** in a source file, including comments and string
  literals, to defeat "Trojan Source" attacks (CVE-2021-42574), hidden-text smuggling (TAG characters, variation
  selectors) and invisible-character confusion (E0004). The set is defined **by property**, not by enumeration:

  > Cf ∪ Default_Ignorable_Code_Point ∪ Variation_Selector ∪ Noncharacter_Code_Point ∪ { U+2028, U+2029 } ∪
  > Cc ∖ { LF } (and ∖ { HT } inside string literals only)

  where Cf is the general category *Format*, Default_Ignorable_Code_Point (DICP) and Variation_Selector are the Unicode
  properties of those names (assigned **or unassigned** code points: DICP reserves its ranges), and the noncharacters
  are `U+FDD0`–`U+FDEF` and `U+xFFFE`, `U+xFFFF` for every plane. Unassigned code points that have none of these
  properties are not forbidden (forbidding all of `Cn` would make a program's validity depend on the compiler's
  Unicode version). Non-normative, the set includes: the bidirectional controls `U+061C`, `U+200E`, `U+200F`,
  `U+202A`–`U+202E`, `U+2066`–`U+2069`; the zero-width characters `U+200B`–`U+200D`, `U+2060`, `U+FEFF`; `U+00AD`,
  `U+034F`, `U+17B4`, `U+17B5`, `U+180B`–`U+180F`, `U+2061`–`U+2064`, `U+2065`, `U+206A`–`U+206F`, `U+115F`, `U+1160`,
  `U+3164`, `U+FFA0`, `U+FE00`–`U+FE0F`, `U+FFF0`–`U+FFF8`, `U+FFF9`–`U+FFFB`, `U+E0000`–`U+E0FFF` (TAG characters,
  variation selectors and every reserved code point between them).

  **Unicode version and table.** The property data is Unicode **16.0.0** (`DerivedCoreProperties.txt`,
  `UnicodeData.txt`, `PropList.txt`). The compiler embeds a generated table; it MUST NOT consult the host's libc, ICU
  or runtime Unicode data, so that two machines agree. `tools/gen/unicode_forbidden.py` (task T-1033) regenerates the
  table from the three files, whose SHA-256 digests are recorded in the generated file's header, and
  `tools/check-generated.sh` fails when the table is stale. Adopting a newer Unicode version is a specification change
  (an ADR that names the version), never an implicit compiler upgrade.

  **No allowlist**, not even the zero-width joiner or non-joiner, nor `U+FE0F` after an emoji. A string literal that
  needs such a character writes it with an escape (`"\u{200D}"`, `"\u{2764}\u{FE0F}"`, LEX-050), visible in the source.
  An allowlist can be added later without breaking any program; removing one could not. Spaces of category `Zs` other
  than `U+0020` (for example the no-break space) are allowed in comments and string literals only; outside them they
  are E0051, so they never separate tokens or indent (LEX-004).
- **[LEX-004]** The horizontal tab `U+0009` MUST NOT appear outside string literals. Indentation uses spaces only.
- **[LEX-005] Display order of right-to-left text (non-goal, warning only).** Strong right-to-left letters (bidi class
  `R` or `AL`) are not forbidden: they are legitimate text, and identifiers cannot contain them (LEX-020). They can
  still make an editor display the rest of the line in a different order than it is lexed, without changing the
  tokens. The compiler therefore does not reject them, and warns (W0001) when a string literal of any form (plain, raw,
  triple-quoted, the literal parts of a template), a character literal or a comment contains such a letter and any
  token follows it on the same line, or when the first strong character of a line is right-to-left. The fix is to bind
  the string with `let` on its own line. W0001 is not suppressed for dependencies and `egide fmt --check` fails on it.
  It is a review aid, not a security guarantee (the Trojan Source defence is LEX-003).
- **[LEX-006] Output hygiene.** Every output of the toolchain that includes source text or the value of a string
  literal passes it through one escaping function: diagnostics and their excerpts, `egide audit`, the SBOM, the
  lockfile, LSP messages and hover text, test and panic output printed by the toolchain. The function renders every
  code point of the LEX-003 set, every `Zs` other than `U+0020`, every bidi control, DEL, `\` and line breaks as `\u{H…}`
  (or `\\`, `\n`), so a terminal escape sequence, an invisible character or a right-to-left override in a value can
  never reach a terminal or a viewer. Machine formats (JSON, CycloneDX) use the format's own escape syntax such that
  no raw code point of that set appears in the output bytes. Positive: `error[E0004]: forbidden character U+001B`.
  Negative: an audit line that prints a `reason` containing `\u{1B}[2K` verbatim.

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
  fraction and the exponent with the restrictions of LEX-040. The integer part of a float follows the leading-zero
  rule of LEX-040: `00.5`, `007.25` and `01e3` are E0031 (no octal hint). A trailing dot is not a lexical error: `1.`
  lexes as `INT` `.` (LEX-042 needs this for `1.max(2)`) and the parser rejects it (E0100); `_1` is an identifier
  (LEX-020). Tuples have no `t.0` element access (SYN-038), so a digit
  after `.` never needs special lexing.
- **[LEX-042] Duration literals.** A **decimal** integer literal immediately followed by `.` and one of the unit names
  `ns`, `us`, `ms`, `s`, `min`, `h`, where the unit is not followed by an identifier character, forms a single
  `DURATION` token of type `std.time.Duration`: `500.ms`, `5.s`, `30.min`. No whitespace is allowed inside the token.
  Otherwise the lexer produces `INT`, `.`, `IDENT`: `5.msg` is a field or method access on `5`, `5.s2` likewise, and
  `0x10.s` is `INT . IDENT`.

## 2.6 String and character literals

- **[LEX-050]** String literals are delimited by `"`. Escapes: `\\`, `\"`, `\n`, `\t`, `\r`, `\0`, `\{`, `\}`,
  `\u{H…}` (1–6 hex digits, any Unicode scalar value: surrogates and values above `10FFFF` are errors; characters
  forbidden by LEX-003 are allowed here, because the escape makes them visible in the source; the value is then
  subject to LEX-006 in every tool output and to SYN-018 where a tool consumes it). Any other escape is an error (E0041).
  A raw LF inside `"…"` is an error (E0040). A `\` directly before a line break is E0041, and the line break
  then ends the literal (E0040). `\xHH` is not an escape of strings or characters (E0041).
- **[LEX-051]** Triple-quoted strings `"""…"""` span lines. The opening `"""` MUST be followed immediately by a line
  break (E0045): no character, not even a space, may stand between them, so `"""abc"""` and `""""""` are E0045. The common leading indentation of their content lines
  is removed, as with Python's `textwrap.dedent`, but on the **raw source lines before escape processing**; whitespace-only
  lines are ignored for the margin and become empty; the line break after the opening `"""` is dropped and the
  line break before the closing `"""` is kept. A tab in the margin, or on a blank line, is E0005 (LEX-004). After the
  run of U+0020 at the start of a content line, the next character MUST NOT be a `Zs` character other than U+0020
  (E0046; write `\u{A0}` if it is wanted). The literal ends at the first closing `"""`; a fourth quote opens a new literal
  (`"""a""""` is E0040), so a value ending in `"` is written `\"`. **Re-indentation invariance:** adding or removing the
  same number of leading U+0020 on every content line and on the line of the closing `"""` does not change the value.
- **[LEX-052]** Raw strings `r"…"` and `r"""…"""` process no escapes; `r"""…"""` is dedented like any triple-quoted string
  (LEX-051). A raw string ends at the first `"` (`r"C:\dir\"` is valid). There are no `#`-fenced raw strings: an
  identifier token `r`, `b`, `rb` or `br` immediately followed by `#"` or `##` is E0047, because `#` would otherwise
  silently start a comment.
- **[LEX-053]** Byte strings `b"…"` have type `Bytes` and accept printable ASCII (`U+0020`–`U+007E`) and the escapes
  `\\ \" \n \t \r \0 \xHH`; no `\u{…}` (E0043) and no other character (E0043); an escape that exists
  elsewhere but not here (`\{`, `\}`) is E0043, an escape that exists nowhere (`\q`, `\'`) or a malformed `\xHH` is E0041.
  There is no `b"""…"""` (E0043 on the three quotes) and no raw byte string: `rb"…"` and `br"…"` are E0043, so that the
  two names stay reserved (LEX-055).
- **[LEX-054]** Character literals `'a'`, `'\n'`, `'\u{E9}'` have type `char` (a Unicode scalar value). Escapes are those
  of LEX-050 except `\{` and `\}`, plus `\'`. The literal holds exactly one scalar value (`''` and `'ab'` are E0042),
  and a raw tab is E0005: write `'\t'`. A literal with a bad escape or no closing quote has one diagnostic.
- **[LEX-055] Prefixed templates.** An identifier in `lower_snake_case`, other than `r`, `b`, `rb` and `br` and not a keyword
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
    templates. Inside `{…}` a `#` is E0044 (there are no comments there, so a comment can never hide a `}`).
    Character literals, plain and triple-quoted strings and templates inside an interpolation are tokenised by the same
    recursive lexer, so `f"{c == '"'}"` and `f"{m["k"]}"` end where they read. An empty spec (`{x:}`) is a spec.
    Unterminated or malformed interpolations are E0044.
  - Reading is left to right: a backslash consumes the next character first, then `{{` and `}}` are collapsed, and a lone
    `}` in literal text is E0044. So `\{{x}}` is a protected `{`, the interpolation `{x}`, then a stray `}`: E0044.
    Templates nest at most 8 levels deep (E0044); SYN-006 bounds everything else.
  - A `"""` template is dedented as in LEX-051 before it is split. There is no raw template form; all are raw.

  The literal parts handed to the template function are the text with each `{{` and `}}` collapsed to one brace
  (sinks never re-scan for `{{`). The meaning of the prefix, including how literal parts are unescaped, is given by a
  `comptime` template function (CT-040): `f` applies the escapes of LEX-050 to literal parts, `re` passes backslashes to the regex compiler. Only
  `f`, and prefixes that declare a spec grammar in their `@template` registration, accept a `:spec`; a template whose result type is a
  sink type (the std `sql`, `html`, `cmd`, `url`, `path`, and any other prefix returning a sink type, ch. 12) MUST reject
  it (E0601), so that a spec string is never an
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
