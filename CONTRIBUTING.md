# Contributing to Égide

Égide is developed by a team of AI agents supervised by a human owner. Human contributors follow the same rules as agents;
the full operating manual is in [`agents/`](agents/). The short version:

1. **Pick a task** from [`tasks/backlog/`](tasks/backlog/) whose dependencies are all in `tasks/done/`.
   Move it to `tasks/in-progress/` in your first commit (this is the lock). One task = one branch = one pull request.
2. **Read the spec rules the task cites** before writing code. The spec in [`spec/`](spec/) is the source of truth;
   if code and spec disagree, the code is wrong.
3. **Tests first.** Every behaviour change comes with a conformance test in [`tests/conformance/`](tests/conformance/)
   or a unit test next to the code. See [`docs/testing.md`](docs/testing.md).
4. **Run `make ci`** before pushing. CI must be green to merge.
5. **Never edit `spec/` or `docs/adr/` in an implementation PR.** Spec changes go through an ADR
   ([`docs/adr/README.md`](docs/adr/README.md)) approved by the owner.

## Branches and commits

- Branch: `t-XXXX-short-slug` (e.g. `t-0003-layout-algorithm`).
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) with the task id as scope:
  `feat(T-0003): emit INDENT/DEDENT tokens`.
- Rebase on `main`; no merge commits in PR branches.

## Code style

- OCaml: `ocamlformat` (config in `.ocamlformat`), rules in [`agents/style-guide-ocaml.md`](agents/style-guide-ocaml.md).
- Go (runtime): `gofmt`, `go vet`, tests with `-race`.
- Égide sources (`stdlib/`, `examples/`, tests): the formatting rules of `spec/03-syntax.md` until `egide fmt` exists.

## Licence

By contributing you agree that your contribution is licensed under the Apache License 2.0.
