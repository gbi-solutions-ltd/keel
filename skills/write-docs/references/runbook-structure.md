# Runbook structure

A runbook is read by someone tired, under pressure, who did not write the system. Write for that
person.

## The order

1. **What this covers, and what it does not.** One line each.
2. **The actions, most likely first.** Deploy, roll back, restart, check health.
3. **Symptoms table:** what you are seeing, what it probably is, what to do.
4. **What not to do**, with reasons. The destructive options someone reaches for at 3am.
5. **Escalation:** who, how, and what to tell them.

## Actions

Each action is a numbered list of exact commands, with the expected output after each. Not "deploy
the service" but the command, and what success looks like.

```markdown
### Roll back to the previous release

1. Find the previous digest:
   `gcloud run revisions list --service payouts --limit 5`
2. Route traffic to it:
   `gcloud run services update-traffic payouts --to-revisions=payouts-00042-abc=100`
3. Confirm: `curl -sf https://payouts.example.com/health` returns 200 within 30 seconds.

**This does not roll back the database.** A migration applied by the newer release stays applied.
If the release included a migration, check <docs_root>/runbooks/schema-rollback.md first.
```

That last paragraph is the kind of thing a runbook exists for. It is known by whoever built it and
nobody else, and it is exactly what someone gets wrong at 3am.

## Symptoms table

```markdown
| Symptom | Likely cause | Action |
|---|---|---|
| Health check 200, no transactions processing | Queue consumer stopped | Restart the worker, then check Redis connectivity |
| 401 on every request | Empty API key in the environment | Check the variable is set and non-empty, then redeploy |
| Transactions stuck pending | Partner callback not arriving | Check the partner's status page, then the callback sweep job |
```

Build this from real incidents. A speculative symptoms table is a guess with the authority of a
runbook, which is worse than a short one.

## What not to do

```markdown
## Do not

- **Do not restart the database to clear a lock.** In-flight settlements will be left in an
  unknown state and reconciliation cannot distinguish them from drift.
- **Do not re-run a failed migration by hand.** It may be partially applied. Use the rollback
  path.
```

Reasons matter. "Do not restart the database" without a reason gets ignored by someone who is
certain it will help.

## Test it

Execute the recovery path once, on a real environment, before the runbook is finished. Record that
you did and when.

A runbook whose rollback has never been run is a hope written in the imperative mood. Every
untested step is a coin flip at the worst possible moment.
