# ADR-0011: Rule-tagged specification, conformance-first development

- Status: Accepted
- Date: 2026-09-26

## Decision

Every normative statement has a stable id (`LEX-032`). Tests, diagnostics, tasks and PRs cite rule ids. A behaviour is
implemented only after a conformance test for its rule exists. Rule coverage is measured by `tools/check-spec.sh
--coverage` and gates phase exits.

## Consequences

Parallel agents share an unambiguous vocabulary; reviews can check "does the code do what rule X says" mechanically.
