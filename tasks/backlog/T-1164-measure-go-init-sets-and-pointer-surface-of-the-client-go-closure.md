---
id: T-1164
title: Measure init sets and pointer surface of the client-go closure
kind: task
phase: 0
role: go-interop-engineer
depends_on: []
spec: [GO-045, GO-032, GO-021]
paths: [tools/, docs/phase-reports/]
estimate: S
labels: [spike]
status: backlog
claimed_by:
claimed_at:
---

## Goal

Evidence for ADR-0028 §2 and §3, which are extrapolations: how many packages and modules of a real operator's Go closure
have a non-trivial init set under GO-045 item 2, and how much of the API surface is pointers.

## Context

ADR-0025, ADR-0026, ADR-0028 (all Proposed). `examples/k8s_namespaces.egd` imports `k8s.io/client-go/kubernetes`,
`k8s.io/client-go/rest` and `k8s.io/apimachinery/pkg/apis/meta/v1`.

## Acceptance criteria

- [ ] A Go program under `tools/` (standard library only: `go/parser`, `go/ast`, `go list -deps -json` output as input)
      that applies the syntactic test of GO-045 item 2 to every non-standard package of a closure, for one build tuple
- [ ] A report in `docs/phase-reports/` for client-go v0.31.0, `linux/amd64`: packages and modules in the closure;
      non-trivial packages and modules, by cause (`init` function, initialiser with a call, `unsafe`, assembly, `embed`);
      number of `go_init` entries a build would need
- [ ] In the same report: for the exported functions of the three imported packages, the share whose signature contains a
      pointer (hence `GoRef`, GO-032) or a slice or map (hence a copy, GO-021)
- [ ] The report labels every number *established* and says which Go version and module versions produced it

## Out of scope

Any change to `spec/` or to the ADRs; the call-graph analysis (T-0083).

## Log

## Outcome
