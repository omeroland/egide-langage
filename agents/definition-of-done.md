# Definition of Done

A task is done only when **every** item below is true. Tick them in the PR template.

## Always

- [ ] The task's acceptance criteria are all met, each one verifiably (test, command output or file).
- [ ] Tests were written **before** or with the implementation and cite rule ids (`# spec:` header or a comment
      `(* spec: TYP-060 *)` above the unit test).
- [ ] Each rule the task implements has at least one positive and one negative test.
- [ ] `make ci` passes locally; CI passes on the PR.
- [ ] No new compiler warning; no disabled warning without a comment explaining why.
- [ ] Every new or changed diagnostic has a row in `docs/diagnostics.md` (code, rule, message).
- [ ] Every new public OCaml module has an `.mli` with doc comments.
- [ ] No change outside the task's `paths`, except new follow-up task files and `docs/diagnostics.md`.
- [ ] The task file has a filled **Outcome** section and is in `tasks/done/`.
- [ ] `CHANGELOG.md` has a line under `[Unreleased]` if the change is user-visible.

## Additionally, depending on the task

- **Parser/grammar**: the Menhir grammar has no new conflicts (`menhir --explain` clean); new error states have
  messages in `parser.messages`.
- **Type system / checks**: error recovery tested (one mistake does not produce a cascade of unrelated diagnostics).
- **Security-relevant** (ch. 5, 6, 9, 11, 12, runtime): at least one test in `tests/security/` showing the attack is
  rejected; `security-reviewer` approval.
- **Runtime (Go)**: `go test -race` green; no goroutine leak (tests use `goleak` where applicable).
- **Performance-sensitive** (lexer, parser, type checker hot paths, runtime): benchmark before/after in the PR.
- **User-facing CLI**: `--help` text updated; `docs-writer` follow-up task created if documentation is needed.
