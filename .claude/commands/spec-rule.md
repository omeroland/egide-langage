---
description: Show a spec rule, its context, and the tests and code that reference it
argument-hint: <rule id e.g. LEX-032>
---

1. Find `**[$ARGUMENTS]**` in `spec/` and print the full rule with its section heading and the neighbouring rules.
2. List conformance tests whose `# spec:` header contains `$ARGUMENTS` (`grep -rl "spec:.*$ARGUMENTS" tests/`).
3. List compiler code and unit tests mentioning `$ARGUMENTS` (`grep -rn "$ARGUMENTS" compiler/`).
4. List diagnostics in `docs/diagnostics.md` enforcing it.
5. Say whether the rule has at least one positive and one negative test.
