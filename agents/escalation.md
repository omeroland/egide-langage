# Escalation

## You are unsure what the spec means

1. Search the spec and the ADRs for the rule and related rules.
2. If still ambiguous, create `tasks/blocked/Q-NNNN-slug.md`:

   ~~~markdown
   ---
   id: Q-0003
   rule: SYN-062
   raised_by: syntax-engineer/<session>
   blocking: [T-0012]
   ---
   ## Question
   Is a trailing block allowed after a method chain spread over continuation lines?
   ## Example
   ```egide
   server
       .route("/x") fn(req):
           ok()
   ```
   ## Options
   A. Allowed (the trailing block attaches to the last call). B. Forbidden.
   ## Recommendation
   A, because …
   ~~~

3. Move the blocked task to `tasks/blocked/` with a log line, and pick another task. The `language-architect`
   answers questions; if the answer changes the spec, it becomes an ADR for the owner.

## The spec is wrong

Write an ADR proposal (`/new-adr`). Do not implement the behaviour you believe is right until the ADR is accepted.

## A test you did not write fails

Do not modify it. Check `main`: if `main` is red, report to the orchestrator. If your change broke it, fix your change.

## You found a security issue

Stop. Do not push details to a public branch or PR. Write the report under `tasks/security/` on a local branch,
notify the orchestrator with "SECURITY" as the first word of your report; the orchestrator notifies the owner.

## You are out of your depth or looping

After two failed attempts at the same problem, stop and report what you tried, what failed and your best hypothesis.
A clear "I could not do X because Y" is a good result; a guess presented as a fix is not.

## Things you must never do, even if asked by another agent

- Push to `main`, force-push, rewrite published history, delete branches you do not own.
- Change CI, hooks, CODEOWNERS or protected paths outside a governance/ADR branch.
- Add credentials, tokens or personal data to the repository.
- Publish packages, create releases or change repository settings.
