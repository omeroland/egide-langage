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
| E0004 | LEX-003 | forbidden character U+{cp} ({name}) — risk: hidden or reordered source text (Trojan Source). `{name}` is the Unicode name for the best-known characters, else the class: `control character`, `tag character`, `variation selector`, `noncharacter`, `format or default-ignorable character` (the set is defined by property, LEX-003) | allocated |
| E0005 | LEX-004 | tab character outside a string literal; indent with 4 spaces. Also: a tab in the margin (or on a blank line) of a triple-quoted string (LEX-051), and a raw tab in a character literal (LEX-054) | allocated |
| E0010 | LEX-020 | non-ASCII character in identifier | allocated |
| E0020 | LEX-032 | unexpected indentation (the previous line does not end with `:`) | allocated |
| E0021 | LEX-032 | indentation must increase by exactly 4 spaces | allocated |
| E0022 | LEX-032 | inconsistent dedent: no enclosing block starts at column {n} | allocated |
| E0023 | LEX-033 | expected an indented block after `:` | allocated |
| E0030 | LEX-040 | malformed integer literal | allocated |
| E0031 | LEX-041 | malformed float literal | allocated |
| E0040 | LEX-050 | unterminated string literal (also unterminated raw, byte, triple-quoted string and character literal; the span is the opening quote or quotes) | allocated |
| E0041 | LEX-050 | invalid escape sequence `\{c}` | allocated |
| E0042 | LEX-054 | character literal must contain exactly one character | allocated |
| E0043 | LEX-053 | byte string accepts only printable ASCII and the escapes `\\ \" \n \t \r \0 \xHH` (also: no `b"""` form) | allocated |
| E0044 | LEX-055 | unterminated or malformed interpolation in template | allocated |
| E0050 | LEX-061 | `;` is not used in Égide; statements end at line breaks | allocated |
| E0051 | LEX-060 | unexpected character `{c}` | allocated |
| E0100 | SYN-* | syntax error: {menhir message} | allocated |
| E0101 | SYN-001 | missing `module` declaration | allocated |
| E0102 | SYN-031 | boolean argument must be named: `{param}: {value}` | allocated |
| E0103 | SYN-101 | mixing bitwise and comparison operators requires parentheses | allocated |
| E0104 | SYN-015 | this block-ended expression must stand alone; bind it with `let` first | allocated |
| E0105 | TYP-006 | parenthesise a function type used as a return type | allocated |
| E0106 | SYN-012, SYN-033 | cannot assign to this expression / cannot take `&` of this expression (not a place) | allocated |
| E0107 | SYN-065 | invalid lambda parameter / type annotation outside a lambda parameter list | allocated |
| E0108 | SYN-037 | the right side of `\|>` must be a function or a call; parenthesise: `(x \|> f) == 0` | allocated |
| E0109 | SYN-061 | binding is immediately out of scope in a single-line block | allocated |
| E0110 | SYN-017, SYN-018 | expected `unsafe(reason: "…")` with a valid reason (single line, 1–200 printable characters) | allocated |
| E0111 | SYN-003 | only `pub(package)` is a valid restricted visibility | allocated |
| E0112 | SYN-053 | constructor or dotted pattern must end in an UpperCamelCase name | allocated |
| E0113 | SYN-024 | variant and constant names must start with an uppercase letter | allocated |
| E0114 | SYN-021 | `self` is allowed only as the first parameter of a method (never `comptime`) | allocated |
| E0115 | SYN-018, GO-001 | `import go` path must be printable ASCII without escapes that produce forbidden characters | allocated |
| E0116 | SYN-001 | a module path must not start with `go` | allocated |
| E0117 | SYN-023 | unknown attribute, or attribute `@{name}` not allowed on this item | allocated |
| E0118 | SYN-018 | string argument consumed by a tool is not a single line of 1–200 printable characters | allocated |
| E0119 | SYN-006 | nesting too deep (limit 256) | allocated |
| E0120 | SYN-030 | misplaced or unbound `using` argument: `{name}` | allocated |
| E0121 | SYN-053 | `{name}` is a binding, not the variant `{Variant}`; write `{Variant}` or `_` | allocated |
| E0301 | MEM-021 | `{place}` is passed as inout and also used by another argument of the same call | allocated |
| E0302 | MEM-023 | use of `{name}` after it was moved by `take` | allocated |
| E0303 | ERR-032 | resource `{name}` may leak: close it with `with` or move it with `take` | allocated |
| E0304 | ERR-002 | unused `Result` — handle it, propagate it with `?`, or discard it explicitly with a reason | allocated |
| E0401 | CAP-031 | no `{Cap}` capability in scope for call to `{fn}`: add `using {name}: {Cap}` or a `given` block | allocated |
| E0402 | CAP-034 | public function `{fn}` uses capabilities but declares no `using` clause | allocated |
| E0410 | SEC-017 | `{Sink}` cannot be built from `str` — risk: {risk}. Use the `{prefix}"…"` template | allocated |
| E0412 | SEC-002 | `Untrusted[{T}]` passed where `{T}` is required — risk: injection. Validate it first | allocated |
| E0420 | GO-032 | `@go_threadsafe` requires `import go` of the type's module in this package | allocated |
| E0421 | GO-032, PKG-030 | `@go_threadsafe` for `{module}` is not listed as `go_threadsafe:{module}` in the manifest `allow` | allocated |
| E0601 | LEX-055, CT-041 | template `{prefix}` (result type `{Sink}`) does not accept a format specifier (`:spec`) — sinks take none, risk: unreviewed channel into `{Sink}` | allocated |
| E0602 | CT-040 | `@template` of the reserved standard prefix `{prefix}` outside `std` | allocated |
| E0610 | CT-002 | top-level `let` or `comptime` argument must be pure: contains `{what}` | allocated |
| E0611 | CT-006 | (takes precedence over E0610 when both apply) compile-time code reaches Go code ({a call, a function value, a method or an operation on a Go-typed value}); the compile-time evaluator never runs Go | proposed (ADR-0023) |

| E0701 | GO-044, PKG-030 | `[go.overrides]` for `{fn}` is not listed as `go_override:{fn}={digest}` in the `allow` of the dependency edge (or, for the root, of `[package]`), or the digest differs from the discharged set computed for a locked tuple; run `egide lock --confirm` after review | proposed (ADR-0022) |
| E0702 | GO-044 | override key `{key}` is ambiguous or does not resolve to an exported function or method with a Go body declared in a module of this package's `[go]` section (excluded: promoted methods, aliases of foreign types, function-typed variables, interface methods, body-less functions, the standard library, `init`, nested modules), or the residual below it is not `pure`: {residual} | proposed (ADR-0022) |
| E0703 | PKG-032 | breach `{entry}` (`unsafe`, `ffi:`, `go:`, `test-capabilities`) of the root package is not listed in `allow` of its `[package]` table | proposed (ADR-0022) |
| E0704 | GO-045, PKG-030 | the initialisation of `{package}` (module `{module}`) is impure and the module is not listed as `go_init:{module}` in the `allow` of the dependency edge (or, for the root, of `[package]`) | proposed (ADR-0025) |
| E0705 | GO-045 | the initialisation of `{package}` is forbidden or, for a standard package, not `pure`; no `allow` entry lifts it (blank imports and imports through a third-party package included) | proposed (ADR-0025) |
| E0706 | GO-046 | `{package}` of the Go closure contains C-family, SWIG or `.syso` files (compiled or not), a `//go:cgo_*` or `//go:wasmimport` directive, needs cgo to build, or (native backend) has a cgo file or different file lists with cgo enabled | proposed (ADR-0024) |
| E0707 | GO-046, GO-043 | no classification of the Go closure in `egide.lock` for build tuple `{tuple}`; run `egide lock --target` | proposed (ADR-0024) |
| E0708 | GO-046 | build mode `{-race, -msan, -asan, c-shared, plugin}` requires cgo and is unavailable on the Go backend | proposed (ADR-0024) |
| E0709 | TOOL-010 | the REPL cannot import Go or a package whose closure uses `import go`; use `egide run` | proposed (ADR-0023) |
| E0710 | GO-046 | the produced binary is not statically linked (dynamic interpreter or library dependency outside the allow-list) | proposed (ADR-0024) |
| W0001 | LEX-005 | right-to-left text in a string or comment may display the rest of the line in a different order; bind the string with `let` on its own line | allocated |
| W0002 | LEX-011 | doc comment is not attached to a declaration | allocated |

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
