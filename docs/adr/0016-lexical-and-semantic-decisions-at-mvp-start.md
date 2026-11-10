# ADR-0016: Lexical and semantic decisions at the start of the MVP

- Status: Accepted
- Date: 2026-11-10
- Deciders: owner
- Decided by: owner-delegated (language-architect), review at MVP ("take the best decisions; we will review once an MVP
  exists")
- Spec chapters affected: 2, 3, 4, 8, 9 and `spec/README.md` (code-block tags); `README.md`, `examples/`
- Raised by: T-0006 reviews (Q-0001, security-reviewer F2/F3), T-0022 (Q-0012, Q-0014..Q-0016, Q-0018, Q-0019, Q-0021)

## Context

The lexer tasks T-0003..T-0005, the layout follow-up (T-0007) and the type/error tasks (T-0031, T-0032, T-0051) depend on
questions the spec left open. As in ADR-0015: restrict rather than add, prefer what a lexer can decide locally, and
close invisible-text channels.

## Decision

| Q | Decision | Spec change |
|---|----------|-------------|
| Q-0001 | Option C, **no allowlist**: forbid all of category `Cf`, the variation selectors, U+034F and the Hangul fillers everywhere (E0004); strings use `\u{…}` escapes, which LEX-050 now allows for any scalar value. RTL letters: explicit non-goal plus warning W0001. | LEX-003, LEX-005 (new), LEX-050 |
| Q-0012 | Option A: comments are trivia in a side table; doc-comment attachment rule; stray `##` is W0002; ERR-002 reads `# ignored: <reason>` on the statement's last line. | LEX-011, LEX-031, ERR-002 |
| Q-0014 | Raw literal parts, `{{`/`}}`, `{expr[:spec]}` with a precise end rule, keywords are never prefixes, triple templates dedented first; **sink templates reject `:spec`**. | LEX-055, CT-040, CT-041, E0044, E0601 |
| Q-0015 | All nine recommendations: no `__`, no leading zeros, lowercase prefixes/exponent, `.5` is not a float, durations need a decimal integer and a clean unit boundary, **no `t.0`**, char/byte escapes, dedent on raw lines. | LEX-040..042, 050, 051, 053, 054, SYN-038 |
| Q-0016 | Option B: body width is last continuation line + 4; a line after a block `:` is never a continuation; multi-line tokens do not affect layout; first line has width 0. | LEX-030, LEX-032 |
| Q-0018 | Option B for SYN-031 (declared `bool`, at least two non-`self`/`using` parameters); SYN-032 gains newtypes and positional variants. | SYN-031, SYN-032 |
| Q-0019 | Option A: `let` ... `else` is pattern matching only; implicit unwrap is gone; an irrefutable pattern with `else` is an error. | ERR-012, TYP-062; README, `examples/tenants_api.egd`, ch. 8 rewritten |
| Q-0021 | Option A: info-string tags `egide`, `egide decls`, `egide fragment`, `egide invalid`; `assert` example fixed; the invalid examples listed in the question are fixed (see Decision in the Q file). | `spec/README.md`, tags in chapters 2, 3, 5-9, 11 |

Choices the owner should see first:

- **Q-0001 has no allowlist.** The cost is real: an emoji with `U+FE0F` (`"\u{2764}\u{FE0F}"`), Persian text with ZWNJ, and
  Indic scripts that use ZWJ need escapes in string literals. Reason: variation selectors and TAG characters are exactly
  the data-smuggling channels, ZWJ is the classic homoglyph/hidden-key trick, a base-character check would add a context
  rule to the lexer, and an allowlist can be added later without breaking any program. Non-ASCII space separators (`Zs`,
  such as the no-break space) are **not** forbidden: they are visible as spaces and needed for French typography.
- **Q-0015.6: tuples have no `t.0`.** Only destructuring reads a tuple. Revisit if it proves too restrictive; the lexer
  rule needed is stated in Q-0015.
- **Q-0016 changes implemented lexer behaviour** (layout, T-0007): see T-1035.
- **Q-0019 breaks the idiom in the README.** Code must read `let Ok(id) = …`; the error value is not reachable from
  the `else` block. Security review: the choice means a validated unwrap (TYP-031 `parse`) has exactly one reading
  and `Option[Option[T]]` is never ambiguous.
- **Q-0014.** With raw literal parts, escaping is the template function's business (`f` applies LEX-050, `re` passes
  backslashes). `sql`, `html`, `cmd`, `url`, `path` receive exactly the source text and reject `:spec`.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Q-0001 A (closed list) / B (subset) | F2 of the T-0006 security review: TAG characters and fillers are open channels; Cf is open-ended |
| Q-0001 with ZWJ/ZWNJ/FE0F allowlist | see above; reversible later, irreversible the other way |
| Q-0014 alternative: process LEX-050 in every template | every regex needs `\\d`, and `{2,62}` still breaks |
| Q-0016 A (document only) / C (forbid) | keeps the misleading form / too restrictive |
| Q-0018 A, C | taxes generic code and `assert` / misses `send(msg, flag)` |
| Q-0019 B, C | unwrap-only has no refutable `let`; type-directed C is surprising and unsafe for validated types |
| Q-0021 B (try all wrappings) | a broken example could pass through a different wrapping |

## Consequences

- Complexity budget: net zero or negative. Additions: one lexer rule class (forbidden set grows), one warning (W0001).
  Removed: implicit unwrap, `t.0`, ambiguous durations.
- Security: closes F2 of the T-0006 review; F1 (diagnostic flood) and F3 (RTL) get tasks T-1080 and T-1037; Q-0014 and
  Q-0019 flagged for `security-reviewer` (T-1038).
- Implementation: T-1033 (forbidden set), T-1080 (diagnostic cap), T-1035 (layout), T-1036 (comment trivia and ERR-002
  check), T-1037 (RTL warning), T-1038 (security review); T-0003..T-0005 and T-0015 logs updated.
- Migration: none (pre-1.0). The README and examples are updated in this PR.
