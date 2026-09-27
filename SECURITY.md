# Security policy

Égide's value proposition is security. A bug that lets a program obtain authority it was not given is treated as a
**critical vulnerability**, even in pre-alpha.

## What counts as a vulnerability

- A program performs I/O (file, network, process, environment, clock, randomness) without holding the corresponding
  capability (spec/06-capabilities.md).
- A capability is forged or amplified (for example a `Dir[Read]` used to write).
- Memory unsafety or a data race in code without `unsafe` (spec/05, spec/07).
- `comptime` code or a package build performs I/O (spec/09).
- A value of a sink type (`Sql`, `Html`, `Cmd`, `Url`, `Path`) is built from `Untrusted` data without validation or escaping.
- A `Secret[T]` is rendered in clear by any standard formatting, logging or serialisation path.
- The Go purity analysis classifies an impure Go function as pure (spec/11-go-interop.md).
- Supply-chain bypasses: lockfile hash or signature not verified, reproducibility broken.

## Reporting

Do **not** open a public issue. Use GitHub private vulnerability reporting on this repository
("Security" tab → "Report a vulnerability"). Include a minimal `.egd` program and the command used.

AI agents that discover such an issue stop their current task, write the report in `tasks/security/` on a private branch
and escalate to the owner as described in [`agents/escalation.md`](agents/escalation.md).

## Supported versions

None yet. Security fixes apply to `main` until the first release.
