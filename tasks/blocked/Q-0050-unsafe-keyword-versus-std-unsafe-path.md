---
id: Q-0050
rule: LEX-021
raised_by: language-architect/adr-0018
blocking: []
status: open
---
## Executive Summary

LEX-021 reserves `unsafe`, but MEM-070 names `std.unsafe.Ptr[T]`: `path = IDENT { "." IDENT }` cannot derive `std.unsafe`, so the
pointer type of the `unsafe` escape hatch cannot be written as specified. One of the two texts must change.

## Core Analysis

- *Established* (reproduced): while parsing the ADR-0018 annex tour, a program with `std.unsafe.read(xs, 0)` was rejected
  by the transcriptions of `spec/grammar/egide.ebnf` (the token `unsafe` is `UNSAFE`, not `IDENT`); replacing the path
  segment made it accept. Texts: LEX-021 keyword list; MEM-070 "(`std.unsafe.Ptr[T]`)"; `path` in the EBNF.
- The problem is independent of ADR-0018 (indentation or braces).
- Security relevance: `unsafe` blocks must stay visible (SYN-015, SYN-017, MEM-071). A contextual keyword would let
  `unsafe` also be an ordinary path segment, which weakens a grep for the word.

## Options

A. Rename the module: `std.raw.Ptr[T]` (any non-keyword name). `unsafe` stays reserved. Smallest change, keeps the audit word unique to the block form.
B. Make `unsafe` contextual (a keyword only when followed by `(`). Keeps the name, adds a lexer/parser context rule and a grep-ambiguous word.
C. Allow keywords as path segments after `.`. Broadest, affects every keyword (`std.type`, `x.match`), rejected: weakens LEX-021.

## Recommendation

A, because it restricts instead of adding a context rule and keeps `unsafe` a reserved, unforgeable audit marker. Needs a
one-rule spec edit (MEM-070, possibly other chapters naming `std.unsafe`; a grep found only MEM-070) through a small ADR or inside the ADR-0018 spec PR if the owner prefers. Not applied.
