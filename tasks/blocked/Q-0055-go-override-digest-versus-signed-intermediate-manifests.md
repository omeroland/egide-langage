---
id: Q-0055
rule: GO-044, PKG-031, PKG-040
raised_by: security-reviewer/ADR-0026 twelfth pass
blocking: []
severity: medium
status: open
---
## Question

**Executive summary.** The digest of a `go_override:` entry (GO-044.5, ADR-0026) depends on the consumer's `GOROOT`, locked
build tuples and the module hashes of the whole import closure, but PKG-031 reads `allow` from the manifest of the
package that declares the edge. A published intermediate package, signed by its publisher, cannot contain a digest that is
valid for a consumer it has never seen, and `egide lock --confirm` cannot edit a signed manifest.

## Core analysis

*Established* (spec text): the digest preimage is consumer-specific (GO-044.5); `allow` lists are read only from the
manifest of the package that declares the edge (PKG-031). *Established* (review): the failure is closed, so no
guarantee is broken; the cost is that a dependency's overrides cannot be used as published.

Options:

| Option | Behaviour | For | Against |
|--------|-----------|-----|---------|
| A | the digest is checked at the root only: an entry for a function of a dependency's `[go]` modules is written in the root's `[package]` allow, per consumer | one signed object per consumer; the reviewer reads the root | the root must list entries for functions of its transitive dependencies |
| B | an intermediate package publishes the function list and a reason, the root supplies the digest | the dependency documents what it needs | two places to keep consistent |
| C | keep as is | no change | published packages with Go interop cannot use overrides |

## Recommendations / Next Steps

Answer with A, as an amendment of GO-044.5 and PKG-031 in a short ADR; the root's `egide audit` lists, for each entry,
the dependency that needs it. Until then the behaviour is fail-closed.
