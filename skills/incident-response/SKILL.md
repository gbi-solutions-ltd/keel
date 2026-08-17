---
name: incident-response
description: Use when production is currently broken, an outage is in progress, customers are affected right now, or the user says they are on call and do not know where to start.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Incident Response

## Overview

Stop the bleeding, then find the cause. Write it down as you go.

**Core principle:** during an incident, restoring service outranks understanding it. You do not need
to know why to roll back.

## This inverts `debug`, deliberately

`keel:debug` forbids a fix before the root cause is understood, and it is right outside an
incident. Here that rule costs you the outage.

| | Incident | `debug` |
|---|---|---|
| First move | Restore service | Reproduce and explain |
| Acceptable fix | Reversible, not understood | Understood, at the root cause |
| Speed versus certainty | Speed, until customers are served | Certainty |

The two are not in conflict, they are sequential. **Use this skill until service is restored, then
`debug` for the cause.** The handoff is step 5, and skipping it turns an incident into a recurring one.

## Step 1: First two minutes, in parallel

1. **Say something publicly.** Set the status page to investigating. Cheapest action available, and
   it stops a share of the inbound.
2. **Get a second person.** One on comms, one on the technical thread. Solo incident response is how
   an outage becomes two.
3. **Capture evidence before changing anything.** Logs for the window, the failing identifiers, queue
   depths, the deployed version. **A rollback destroys what step 5 needs**, and that loss is the one
   that is not recoverable.

## Step 2: Open the record now, not afterwards

Create `<docs_root>/incidents/YYYY-MM-DD-<slug>.md` and append as you go. Follow
[references/incident-record.md](references/incident-record.md).

Write it during, not after. Nobody reconstructs an accurate timeline the next day, and the timestamps
are what turn an incident into a finding.

## Step 3: Restore, by the most reversible route available

Read the project's runbook first: `<docs_root>/runbooks/`. The rollback command lives there, and
guessing it during an incident is how a bad hour becomes a bad day.

Prefer, in order: roll back the recent deploy, disable the feature flag, fail over or pause the
affected corridor, scale out. Each is reversible and none needs a diagnosis.

**Resist fixing forward.** A hotfix is untested code shipped mid-incident, and it is how the second
outage starts. Two answers to the usual objections: the comparison is not fifteen minutes against
zero, because a hotfix costs write, review, build, deploy, and then discovering whether it worked. And
a rollback does not lose the release's other changes; the commits still exist and you re-land them in
an hour.

**Check what the timing actually implies before assuming the deploy.** If failures began well after
the deploy, a scheduled job, a token or certificate expiry, or an upstream provider is as likely.
One minute of thought here is cheaper than a rollback that changes nothing.

## Step 4: Before any bulk retry, reconcile

The most expensive mistake available during recovery. A request that errored may still have taken
effect upstream.

For anything that moves money, reconcile each failed item against the provider's state before
retrying. **A delayed payment is an incident; a double payment is a loss.** See
[references/incident-record.md](references/incident-record.md) for the recovery checklist.

## Step 5: Hand off, and close it

Service restored is not resolved. In order:

1. Update the status page and tell whoever is waiting.
2. **REQUIRED SUB-SKILL:** `keel:debug` for the root cause, now that there is time to be right.
3. `keel:tdd` for the fix, with a test that reproduces it.
4. If the design allowed it, `keel:design-architecture` for an ADR.
5. Add what you learned to the runbook. A symptom that has happened once will happen again, and the
   next person on call should not start where you did.

## Common mistakes

| Mistake | Instead |
|---|---|
| Diagnosing while customers are down | Restore first. `debug` afterwards |
| Rolling back before capturing logs | The evidence is gone and unrecoverable |
| A hotfix at minute 25 | Untested code, mid-incident. Restore, then think |
| Mass retry once healthy | Reconcile first, or a delay becomes a double payment |
| Writing the timeline afterwards | Nobody reconstructs it accurately. Append as you go |
| Stopping at service restored | That is stabilised, not resolved. Step 5 |
