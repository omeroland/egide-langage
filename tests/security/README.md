# Security tests (append-only)

Each file is an attack on one of Égide's guarantees (INT-001..005) and MUST be rejected or neutralised.
Files are never edited or deleted except through an accepted ADR (a hook enforces it). Successful, unfixed attacks
are **not** committed here: they are reported privately (SECURITY.md) and added once fixed.
