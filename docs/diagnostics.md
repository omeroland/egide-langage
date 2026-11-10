# Diagnostics catalogue

Every diagnostic emitted by `egidec` is listed here (TOOL-040). Adding a diagnostic means adding a row **in the same
pull request**. Codes are never reused.

## Ranges

| Range | Area |
|-------|------|
| E0001–E0099 | lexical (ch. 2) |
| E0100–E0199 | syntax (ch. 3) |
| E0200–E0299 | names, modules, types (ch. 4, 10) |
| E0300–E0399 | values, memory, resources (ch. 5, 8) |
| E0400–E0499 | capabilities and security (ch. 6, 12) |
| E0500–E0599 | concurrency (ch. 7) |
| E0600–E0699 | comptime (ch. 9) |
| E0700–E0799 | packages and Go interop (ch. 10, 11) |
| W0001–W0999 | warnings (same sub-ranges) |
| ICE | internal compiler error (compiler bug) |

## Allocated codes

| Code | Rule | Message template | Status |
|------|------|------------------|--------|
| E0001 | LEX-001 | invalid UTF-8 sequence | allocated |
| E0002 | LEX-001 | byte-order mark is not allowed | allocated |
| E0003 | LEX-002 | lone carriage return | allocated |
| E0004 | LEX-003 | forbidden character U+{cp} ({name}) — risk: hidden or reordered source text (Trojan Source) | allocated |
| E0005 | LEX-004 | tab character outside a string literal; indent with 4 spaces | allocated |
| E0010 | LEX-020 | non-ASCII character in identifier | allocated |
| E0020 | LEX-032 | unexpected indentation (the previous line does not end with `:`) | allocated |
| E0021 | LEX-032 | indentation must increase by exactly 4 spaces | allocated |
| E0022 | LEX-032 | inconsistent dedent: no enclosing block starts at column {n} | allocated |
| E0023 | LEX-033 | expected an indented block after `:` | allocated |
| E0030 | LEX-040 | malformed integer literal | allocated |
| E0031 | LEX-041 | malformed float literal | allocated |
| E0040 | LEX-050 | unterminated string literal | allocated |
| E0041 | LEX-050 | invalid escape sequence `\{c}` | allocated |
| E0050 | LEX-061 | `;` is not used in Égide; statements end at line breaks | allocated |
| E0051 | LEX-060 | unexpected character `{c}` | allocated |
| E0100 | SYN-* | syntax error: {menhir message} | allocated |
| E0101 | SYN-001 | missing `module` declaration | allocated |
| E0102 | SYN-031 | boolean argument must be named: `{param}: {value}` | allocated |
| E0103 | SYN-101 | mixing bitwise and comparison operators requires parentheses | allocated |
| E0301 | MEM-021 | `{place}` is passed as inout and also used by another argument of the same call | allocated |
| E0302 | MEM-023 | use of `{name}` after it was moved by `take` | allocated |
| E0303 | ERR-032 | resource `{name}` may leak: close it with `with` or move it with `take` | allocated |
| E0304 | ERR-002 | unused `Result` — handle it, propagate it with `?`, or discard it explicitly with a reason | allocated |
| E0401 | CAP-031 | no `{Cap}` capability in scope for call to `{fn}`: add `using {name}: {Cap}` or a `given` block | allocated |
| E0402 | CAP-034 | public function `{fn}` uses capabilities but declares no `using` clause | allocated |
| E0410 | SEC-017 | `{Sink}` cannot be built from `str` — risk: {risk}. Use the `{prefix}"…"` template | allocated |
| E0412 | SEC-002 | `Untrusted[{T}]` passed where `{T}` is required — risk: injection. Validate it first | allocated |

## JSON format (`--error-format=json`)

```json
{
  "code": "E0301",
  "severity": "error",
  "rule": "MEM-021",
  "message": "`cart` is passed as inout and also used by another argument of the same call",
  "span": { "file": "src/cart.egd", "start": { "line": 12, "col": 9 }, "end": { "line": 12, "col": 14 } },
  "labels": [ { "span": { "file": "src/cart.egd", "start": { "line": 12, "col": 16 }, "end": { "line": 12, "col": 29 } },
                "message": "used here" } ],
  "notes": [ "an inout argument must be exclusively accessible during the call (MEM-021)" ],
  "fixes": [ { "message": "copy the element first", "edits": [ { "span": { "file": "src/cart.egd", "start": { "line": 12, "col": 5 }, "end": { "line": 12, "col": 5 } },
                                                            "replacement": "let first = cart.lines[0]\n" } ] } ]
}
```

Lines and columns are 1-based; columns count Unicode scalar values; `end` is exclusive (`&cart` above occupies
columns 9–13). Every field is always present (`labels`, `notes` and `fixes` may be empty; `rule` is `null` only for
`ICE`). An edit with an empty span inserts its replacement. The normative schema is
[`diagnostics.schema.json`](diagnostics.schema.json); `compiler/test/diagnostics/test_json.ml` validates the
compiler's output against it.
