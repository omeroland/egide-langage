# Benchmarks

Performance targets are in docs/architecture.md §5. From phase 5, `make bench` runs this suite and CI fails on a
regression above 5 % against the last `main` baseline. Each benchmark is an Égide program plus an equivalent Go
program for comparison.
