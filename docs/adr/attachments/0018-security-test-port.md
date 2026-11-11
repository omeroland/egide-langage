# ADR-0018 annex: rule for porting `tests/security` to the brace syntax

Companion of [ADR-0018](../0018-surface-syntax-familiarity.md). Applies AGENTS.md rule 4 (never weaken a test) to the
26 files of `tests/security/semantics` (13) and `tests/security/syntax` (13) that contain a block. The other 44 security
files contain no block and are not touched. `tests/security/` is append-only: this port is a proposal for the owner to
merge through a `governance/*` PR, not an entitlement (ADR-0018 open question 6).

## Rule of semantically equivalent rewrite

1. **Same attack, same construct.** The ported file contains the same construct in the same role (the same `unsafe`
   operand, the same discard comment, the same template sink), only re-bracketed per ADR-0018 item 1 and 2. No line is
   added that could change what is tested, and nothing is removed from the attack.
2. **Same header.** `# spec:` and `# expect:` are unchanged. `# diagnostic:` keeps the same code. The position
   `line:col` is recomputed to point at the same token of the same construct; the PR shows old and new position side by side.
3. **Differential check.** For each file, the PR description states the old and new `egide lex`/`parse` result on the
   unported repository state where it is still runnable (lexer-only tests run on both), and the reviewer confirms the new
   test fails when the checked rule is disabled (a mutation of the rule, not of the test).
4. **One-to-one mapping.** Every old file maps to exactly one new file, recorded in the table below and checked by a
   script (`tools/` addition in T-1107) that fails if an old test has no mapped successor or if a header field differs.
5. **Retired tests.** A test whose diagnostic is retired by ADR-0018 (E0021 and its family) cannot be ported. It is
   replaced by a named test of the successor rule and listed as RETIRED in the table. Retirement needs the owner's approval
   in the governance PR; it is the only case where a file disappears.
6. **Additions are separate.** New attack tests (misleading indentation, discard inside a one-line block, `{` on the
   next line, whitespace-only edit) are new files in a separate commit, never mixed into the port.
7. **Order.** Port and mapping check land first, in one governance PR; new tests after.

## Mapping (old to new)

| Old file (under `tests/security/`) | `# spec:` | `# expect:` | `# diagnostic:` (unchanged code) | New |
|---|---|---|---|---|
| `semantics/discard_ignored_as_doc_comment.egd` | ERR-002, LEX-011 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/discard_ignored_empty_reason.egd` | ERR-002 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/discard_ignored_inside_string.egd` | ERR-002, LEX-031 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/discard_ignored_inside_triple_string.egd` | ERR-002, LEX-031 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/discard_ignored_not_on_last_line.egd` | ERR-002 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/discard_ignored_without_space.egd` | ERR-002 | compile-fail | E0304 at 14:5 | same path, ported in place |
| `semantics/template_cmd_rejects_format_spec.egd` | LEX-055, CT-041 | compile-fail | E0601 at 8:21 | same path, ported in place |
| `semantics/template_html_rejects_format_spec.egd` | LEX-055, CT-041 | compile-fail | E0601 at 8:22 | same path, ported in place |
| `semantics/template_path_rejects_format_spec.egd` | LEX-055, CT-041 | compile-fail | E0601 at 8:22 | same path, ported in place |
| `semantics/template_sink_rejects_empty_format_spec.egd` | LEX-055 | compile-fail | E0601 at 8:21 | same path, ported in place |
| `semantics/template_sink_rejects_format_spec_after_nested_string.egd` | LEX-055 | compile-fail | E0601 at 8:26 | same path, ported in place |
| `semantics/template_sql_rejects_format_spec.egd` | LEX-055, CT-041 | compile-fail | E0601 at 8:21 | same path, ported in place |
| `semantics/template_url_rejects_format_spec.egd` | LEX-055, CT-041 | compile-fail | E0601 at 8:21 | same path, ported in place |
| `syntax/attribute_go_threadsafe_on_struct.egd` | SYN-023, GO-032 | parse-fail | E0117 at 7:1 | same path, ported in place |
| `syntax/cover_inout_in_call_argument.egd` | SYN-065 | parse-fail | E0107 at 8:7 | same path, ported in place |
| `syntax/inout_argument_not_a_place.egd` | SYN-033 | parse-fail | E0106 at 8:7 | same path, ported in place |
| `syntax/keyword_is_not_template_prefix.egd` | LEX-055 | parse-pass | none (parse-pass) | same path, ported in place |
| `syntax/layout_body_after_continuation_wrong_width.egd` | LEX-030, LEX-032 | lex-fail | E0021 at 10:9 | RETIRED, replaced by `syntax/misleading_indentation_after_continuation.egd` (W0003 on the same logical line; owner approval, see rule 5) |
| `syntax/pattern_constructor_lowercase_in_let_else.egd` | SYN-053, ERR-012 | parse-fail | E0112 at 8:9 | same path, ported in place |
| `syntax/pattern_dotted_lowercase.egd` | SYN-053 | parse-fail | E0112 at 9:14 | same path, ported in place |
| `syntax/unsafe_as_call_argument.egd` | SYN-015, SYN-017 | parse-fail | E0104 at 8:7 | same path, ported in place |
| `syntax/unsafe_as_lambda_body.egd` | SYN-015 | parse-fail | E0104 at 8:18 | same path, ported in place |
| `syntax/unsafe_as_operand.egd` | SYN-015 | parse-fail | E0104 at 8:9 | same path, ported in place |
| `syntax/unsafe_as_return_operand.egd` | SYN-015, SYN-017 | parse-fail | E0104 at 8:12 | same path, ported in place |
| `syntax/unsafe_reason_is_template.egd` | SYN-017 | parse-fail | E0110 at 8:20 | same path, ported in place |
| `syntax/unsafe_word_not_reason.egd` | SYN-017 | parse-fail | E0110 at 8:12 | same path, ported in place |
