# ADR-0027: Scope of v1.0: Go backend first, native backend and full toolchain parity after

- Status: Proposed
- Date: 2026-11-14
- Deciders: owner
- Decided by: proposed after an external feasibility review of the design (owner request, 2026-11-14); **not accepted**.
- Spec chapters affected: 1 (§1.5, INT-020), 5 (MEM-061..063), 6 (CAP-050), 11 (GO-003), 13; `docs/roadmap.md`,
  `docs/architecture.md` §5
- Amends (if accepted): the milestone table of `docs/roadmap.md`; the schedule of ADR-0019 (Proposed). Does not reverse
  ADR-0006 or ADR-0008: the native backend stays a goal, it stops being a condition of v1.0.

## Executive Summary

The roadmap makes `v1.0.0` wait for phase 7 (C backend, Perceus reference counting, ORC cycle collector, M:N scheduler,
"within 1.5× of Go") and ADR-0019 adds parity with the whole Go toolchain. Both are larger than the language itself and
neither is needed to validate the five structural decisions. This ADR proposes `v1.0.0` = end of phase 6 on the Go
backend with a reduced toolchain, and moves the native backend and the rest of the parity list after 1.0.

## Core Analysis

Labels: *established* = text of this repository; *extrapolated* = the reviewer's inference, not measured.

### 1. What phase 7 requires

*Established* (`docs/roadmap.md`, MEM-061, CON-020, INT-020, GO-003): a C backend with Perceus reference counting; a
trial-deletion cycle collector; an M:N scheduler over all cores; the OS sandbox; observable behaviour identical to the Go
backend on the whole conformance suite; performance within 1.5× of Go; and, for programs that import Go, a `c-archive`
link with two runtimes in one process.

*Extrapolated*: an M:N scheduler in C needs stackful tasks with growable stacks, a network poller per operating system,
hand-off of blocking system calls, timers, and a reference count that is safe across threads (atomic, or a
thread-ownership scheme) interacting with a concurrent cycle collector. That is the runtime of Go, rebuilt. No task of the
board sizes it (T-0100 is an unsplit epic). The 1.5× target compares it against a runtime with fifteen years of tuning.

### 2. What the native backend is not needed for

*Established*: INT-001..005 hold on the Go backend (MEM-064, ADR-0008). ADR-0008 makes the Go backend permanent. The
target domains of §1.1 (services, CLI tools, operators) are the domains of Go binaries.

*Extrapolated*: the only user-visible properties that need the native backend are "no garbage collector" and embedding
without the Go runtime. Neither is in INT-001..005.

### 3. Toolchain parity

*Established*: ADR-0019 (Proposed) and `docs/toolchain-parity.md` create T-1121..T-1153: coverage, benchmarks, CPU and
memory profiles, race detection, fuzzing, vulnerability audit, workspaces, registry publishing, an LSP and a VS Code
extension, among others. The board holds 116 backlog tasks for 40 done, in phase 0.

*Extrapolated*: on the Go backend several of these can delegate to the Go tool on the generated code (`go test -race`,
`pprof`, coverage with `//line` directives, T-1152) at a fraction of the cost of an Égide-level implementation.

### 4. Counter-hypothesis

"A language without its own runtime is a Go dialect and will not be adopted." Possible. It is cheaper to test that
hypothesis with a working v1.0 on the Go backend than to pay for phase 7 first: the value under test is MVS +
capabilities + `comptime`, and none of them depends on the backend.

## Decision

1. `v1.0.0` = exit of phase 6, Go backend only. Phase 7 (native backend) and phase 8 (self-hosting) keep their content
   and move after 1.0; `--backend native` and GO-003's native paragraph are marked "post-1.0" in the spec.
2. INT-020 is reworded to bind the **interpreter and the Go backend** until a second backend exists.
3. CAP-050 (`--sandbox`) moves to phase 5 on the Go backend: it is the only barrier for Go code (GO-013) and does not
   depend on the native backend.
4. Toolchain for 1.0: `check`, `run`, `build`, `test`, `fmt`, `lock`/`vendor`, `audit`, `expand`, `explain`, `lsp`
   (diagnostics, hover, definition, formatting). Everything else in ADR-0019 is post-1.0, or delegates to the Go tool
   where one exists.
5. The performance target of `docs/architecture.md` §5 is kept only as a measured number (T-1162), not as an exit
   criterion, until that measurement exists.

## Alternatives considered

| Option | Pros | Cons | Why not |
|--------|------|------|---------|
| Status quo (1.0 after phase 7) | one story: "no GC" | 1.0 depends on the largest and least specified phase | cost not sized, benefit outside INT-001..005 |
| Drop the native backend (reverse ADR-0006/0008 wording) | smallest scope | closes the embedding and no-GC door | not needed: deferring is enough |
| Native backend first, single-threaded (no M:N) | small runtime | breaks CON-020 and INT-020 | two semantics |
| WebAssembly + WASI as the second backend | capability model maps to WASI | another runtime question (threads) | worth an ADR after 1.0 |

## Consequences

- Complexity budget: removes nothing from the language; removes phase 7 and about two thirds of ADR-0019 from the path to
  1.0.
- Security: INT-001..005 unchanged. CAP-050 arrives earlier.
- Implementation: `docs/roadmap.md` milestone line; T-0100 and T-0110 relabelled post-1.0; ADR-0019 task list split in
  two; MEM-061..063 and GO-046.1's native part marked post-1.0 (text kept).
- Migration: none (pre-alpha).

## Recommendations / Next Steps

1. Owner: accept, reject, or accept items 1-3 only.
2. `release-manager`: roadmap and milestone edit on this branch after acceptance.
3. `tooling-engineer`: split T-1121..T-1153 into "1.0" and "post-1.0", with the delegation to the Go tool noted per task.
4. Not verified: nothing was built or measured for this ADR. The sizing of §1 is an inference from the spec text.
