---
id: Q-0043
rule: PKG-031
raised_by: tooling-engineer/T-1120
blocking: [T-1145]
status: open
---
## Question

Workspaces and local overrides. Go workspaces and `replace` redirect a dependency to local code. In Égide a redirect changes what is audited, and PKG-031 makes breaches visible at every level.

## Example

```toml
[workspace]
members = ["packages/*"]
[patch]
"egide.http" = { path = "../http" }
```

## Options

A. No workspaces; use `egide vendor` and path dependencies of one package. B. `[workspace]` members only, no patching of published packages. C. Members and `[patch]`, patches recorded in the lockfile, listed by `egide audit`, ignored when the package is a dependency of another (like GO-044 overrides).

## Recommendation

C, with `egide publish` refusing an archive that contains a patch. B if the owner wants the smaller surface. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).
