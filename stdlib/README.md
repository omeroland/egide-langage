# The Égide standard library

Written in Égide. Layout: `std/<module>.egd` or `std/<package>/…`. Rules for contributors are in
`.claude/agents/stdlib-engineer.md`; the non-negotiable one is CAP-020: no I/O without a capability.

Planned modules (phase in parentheses): `prelude` (1), `fmt`, `str`, `list`, `map`, `set`, `iter` (1–2),
`error`, `derive`, `meta`, `testing` (2), `arena` (3), `cap`, `security`, `crypto`, `time`, `rand` (4),
`task`, `par`, `chan` (5), `http`, `json`, `toml`, `yaml`, `cli`, `log` (4–6).
