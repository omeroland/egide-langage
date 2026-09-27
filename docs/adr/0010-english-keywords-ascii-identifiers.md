# ADR-0010: English keywords, ASCII identifiers

- Status: Accepted
- Date: 2026-09-26
- Spec chapters affected: 2

## Decision

Keywords and the standard library use English. Identifiers are ASCII; Unicode is allowed in strings and comments;
bidirectional and invisible characters are forbidden everywhere.

## Consequences

Universal readability and tooling; immunity to homoglyph and Trojan Source attacks. French (or any language) remains
available in strings, comments and documentation.
