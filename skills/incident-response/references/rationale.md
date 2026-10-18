# Why `incident-response`'s steps are as they are

Reasons for `incident-response`'s steps. The steps themselves are in [`SKILL.md`](../SKILL.md).

## This inverts `debug`, deliberately

`keel:debug` forbids a fix before the root cause is understood, and it is right outside an
incident. Here that rule costs you the outage.

The two are not in conflict, they are sequential. Skipping the handoff at step 5 turns an incident
into a recurring one.

## Step 1: First two minutes, in parallel

Saying something publicly is the cheapest action available, and it stops a share of the inbound.

Get a second person because solo incident response is how an outage becomes two.

Capture evidence before changing anything because a rollback destroys what step 5 needs, and that
loss is the one that is not recoverable.

## Step 2: Open the record now, not afterwards

Write it during, not after: nobody reconstructs an accurate timeline the next day, and the
timestamps are what turn an incident into a finding.

## Step 3: Restore, by the most reversible route available

Read the runbook first because the rollback command lives there, and guessing it during an incident
is how a bad hour becomes a bad day.

Check what the timing implies before assuming the deploy: one minute of thought here is cheaper
than a rollback that changes nothing.

## Step 4: Before any bulk retry, reconcile

A bulk retry is the most expensive mistake available during recovery. A request that errored may
still have taken effect upstream.

A delayed payment is an incident; a double payment is a loss.

## Step 5: Hand off, and close it

Hand the root cause to `keel:debug` once service is restored, now that there is time to be right.

Add what you learned to the runbook because a symptom that has happened once will happen again, and
the next person on call should not start where you did.
