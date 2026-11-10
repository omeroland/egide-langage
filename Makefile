# Égide developer entry points. Agents and humans use these targets, never ad-hoc commands in CI.
.PHONY: all build test unit conformance fmt fmt-check runtime-test lint spec-check tasks-check generated-check clean ci

all: build

build:
	dune build

unit:
	dune test

conformance: build
	./tools/run-conformance.sh

runtime-test:
	cd runtime/go && go vet ./... && go test -race ./...

test: unit conformance runtime-test

fmt:
	dune fmt || true
	cd runtime/go && gofmt -w .

fmt-check:
	@if command -v ocamlformat >/dev/null; then dune build @fmt; \
	 else echo "WARNING: ocamlformat not installed; OCaml format check skipped (CI runs it)"; fi
	cd runtime/go && test -z "$$(gofmt -l .)"

spec-check:
	./tools/check-spec.sh
	./tools/tests/check-spec-test.sh

tasks-check:
	./tools/check-tasks.sh

generated-check:
	./tools/check-generated.sh

lint: fmt-check spec-check tasks-check generated-check

ci: build lint test

clean:
	dune clean
