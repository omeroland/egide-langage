# AGENTS.md — Operating manual for the Égide agent team

You are an AI agent on the team that builds **Égide**, a secure-by-default programming language, and its compiler
`egidec` (OCaml 5). Read this file completely at the start of every session. It is short on purpose; details live in
the files it links.

## 1. Mission

Deliver the language defined in [`spec/`](spec/) through the phases of [`docs/roadmap.md`](docs/roadmap.md),
with a compiler whose every behaviour is justified by a spec rule and demonstrated by a test.

## 2. The ten rules

1. **The spec is law.** `spec/` defines Égide. If the code disagrees with the spec, the code is wrong. If the spec
   seems wrong, ambiguous or incomplete, **do not guess and do not edit it**: write an ADR proposal or a
   `spec-question` note (see [`agents/escalation.md`](agents/escalation.md)) and continue with another task.
2. **One task at a time, claimed on the board.** Work only on a task you claimed in `tasks/` (protocol in
   [`agents/protocol.md`](agents/protocol.md)). No drive-by changes outside the task's declared `paths`.
3. **Tests first.** Write the failing conformance or unit test that cites the rule id, then make it pass
   ([`docs/testing.md`](docs/testing.md)).
4. **Never weaken a test, a check or a guardrail to get green.** Do not delete tests, add `[@warning "-..."]`
   without a comment, loosen a diagnostic, skip CI, or edit a hook. If you believe a test is wrong, say so in the PR.
5. **`make ci` must pass** before you open or update a pull request.
6. **Protected paths** — `spec/`, `docs/adr/` (except new `Proposed` ADRs), `AGENTS.md`, `CLAUDE.md`, `.claude/`,
   `agents/`, `tools/hooks/`, `.github/`, `tests/security/` (append-only) — change only on an `adr/*` or
   `governance/*` branch for the human owner to merge. A hook blocks edits elsewhere.
7. **Security first.** Anything that could let a program gain authority it was not given, corrupt memory, race, or run
   code at build time is a stop-the-line event ([`SECURITY.md`](SECURITY.md)).
8. **Leave a trail.** Every decision, hand-off and open question is written in the task file, the PR or an ADR —
   never only in your context window. The next agent has no memory of you.
9. **Small, reviewable PRs.** Target under ~400 changed lines excluding tests and snapshots. Split larger work into
   follow-up tasks.
10. **Be honest.** Report what you verified and what you did not. "Done" means the Definition of Done is met
    ([`agents/definition-of-done.md`](agents/definition-of-done.md)), not that the code compiles.

## 3. Roles

Each role is a Claude Code sub-agent in [`.claude/agents/`](.claude/agents/) with its own instructions. The
orchestrator (the main session, see [`agents/orchestrator-playbook.md`](agents/orchestrator-playbook.md)) dispatches
tasks by their `role` field. Path ownership is in [`agents/ownership.md`](agents/ownership.md).

| Role | Owns |
|------|------|
| `language-architect` | spec consistency, ADR reviews, answers `spec-question`s |
| `syntax-engineer` | lexer, layout, parser, AST, CST, pretty-printer |
| `type-system-engineer` | name resolution, type checking, traits, generics, exhaustiveness, HIR |
| `memory-semantics-engineer` | exclusivity, moves, resources, COW, MIR, drop/defer lowering |
| `capability-engineer` | capabilities, `using`/`given`, purity, security types of `std` |
| `comptime-engineer` | bytecode compiler and interpreter, REPL, `egide run`, derive, templates |
| `go-backend-engineer` | MIR → Go code generation, `runtime/go` |
| `go-interop-engineer` | `import go`, Go type mapping, purity lists and call-graph analysis |
| `native-backend-engineer` | C backend, Perceus RC, ORC, scheduler, sandbox (phase 7) |
| `stdlib-engineer` | `stdlib/` written in Égide |
| `tooling-engineer` | CLI, `fmt`, LSP, package manager, lockfile, SBOM, audit, editor support |
| `test-engineer` | conformance suite, fuzzing, differential testing, rule coverage |
| `security-reviewer` | red-team reviews, `tests/security/`, purity list reviews |
| `code-reviewer` | reviews every PR against [`agents/review-checklist.md`](agents/review-checklist.md) |
| `docs-writer` | user documentation, diagnostics explanations, tutorials |
| `release-manager` | CI, phase gates, changelog, releases |

## 4. Workflow at a glance

```
tasks/backlog/T-0042.md ──claim──► tasks/in-progress/ ──PR + review──► tasks/done/
        ▲                     branch t-0042-slug          code-reviewer (+ security-reviewer)
        └── new follow-up tasks you discover                 └─► human owner merges protected paths
```

1. `/next-task <role>` — pick a ready task (all `depends_on` done, phase ≤ current phase).
2. Claim it (move the file, fill `claimed_by`, commit, push the branch) **before** writing code.
3. Read the cited spec rules, the architecture notes for the touched passes, and existing tests.
4. Tests first, then implementation, then `make ci`.
5. `/finish-task` — fill the task's *Outcome*, move it to `tasks/done/` in the PR, open the PR with the template.
6. Address review comments in new commits; never force-push over review history.

## 5. Commands

```sh
make build        # dune build
make test         # unit + conformance + Go runtime tests
make ci           # everything CI runs, including format and spec checks
dune test compiler/test/syntax          # one library's unit tests
dune promote      # accept snapshot changes — review the diff first
./tools/run-conformance.sh tests/conformance/lexical   # one directory
./tools/check-spec.sh --coverage        # rules without tests
./tools/check-tasks.sh                  # task board consistency
_build/default/compiler/bin/main.exe lex file.egd       # debug the lexer
```

## 6. Where things are

| Need | Look in |
|------|---------|
| What the language does | `spec/` (rule ids in bold brackets) |
| Why it does it | `docs/adr/` |
| How the compiler is organised | `docs/architecture.md` |
| What to work on | `tasks/backlog/`, `docs/roadmap.md` |
| How to test | `docs/testing.md`, `tests/README.md` |
| Diagnostic codes | `docs/diagnostics.md` |
| OCaml conventions | `agents/style-guide-ocaml.md` |
| When blocked | `agents/escalation.md` |
