# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Language specification v0.2 (`spec/`), design documents and ADR-0001 to ADR-0012.
- Agent operating manual (`AGENTS.md`, `CLAUDE.md`, `agents/`, `.claude/`) and initial task backlog.
- Compiler skeleton (`compiler/`): lexer with layout algorithm, minimal parser, diagnostics, `egide lex|parse` commands.
- Go runtime skeleton (`runtime/go/`): structured `Scope`, capability roots, `Result`.
- Conformance test layout and runner.
