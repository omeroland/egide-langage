# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Added

- AST: `[@@deriving show, eq]` (ppx_deriving) replaces the hand-written `Ast.equal_*`; every node type now has `equal_*`, `pp_*`, `show_*`; `Print.pp_*` is renamed `Print.pp_sexp_*` and stays the S-expression formatter (T-0029).
- Lexer: integer, float and `DURATION` literals (LEX-040..042) with diagnostics E0030 and E0031 (T-0003).
- Language specification v0.2 (`spec/`), design documents and ADR-0001 to ADR-0012.
- Agent operating manual (`AGENTS.md`, `CLAUDE.md`, `agents/`, `.claude/`) and initial task backlog.
- Compiler skeleton (`compiler/`): lexer with layout algorithm, minimal parser, diagnostics, `egide lex|parse` commands.
- Go runtime skeleton (`runtime/go/`): structured `Scope`, capability roots, `Result`.
- Conformance test layout and runner.
- Diagnostics: secondary labels, suggested fixes, source excerpts with carets, and `--error-format=json` output with
  every field, validated against `docs/diagnostics.schema.json` (T-0002).
