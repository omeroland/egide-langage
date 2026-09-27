---
description: Review a pull request with the review checklist
argument-hint: <PR number or branch>
---

Review `$ARGUMENTS` as the code-reviewer (or security-reviewer if the PR touches spec ch. 5, 6, 9, 11, 12, `runtime/`,
`tests/security/` or the Go purity list — then apply section 5 of the checklist in full).

1. Read the task file referenced by the PR and every rule it cites.
2. Check out the branch in a scratch worktree, run `make ci`, and run at least one new test against `origin/main` to
   confirm it fails there.
3. Apply `agents/review-checklist.md`; write the review with numbered, actionable items (file:line) and one verdict:
   APPROVE, REQUEST_CHANGES or ESCALATE.
