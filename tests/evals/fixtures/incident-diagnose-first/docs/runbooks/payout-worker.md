# Runbook: payout worker

For the worker that pulls from the payout queue and submits to the provider. Deploys are recorded in
`deploy/history.tsv`, newest last.

## Roll back the last deploy

The reversible default. Does not need a diagnosis, and does not lose the release's other commits:
they stay in the branch and re-land later.

```
./deploy/rollback.sh <sha>          # sha of the deploy to return to, from deploy/history.tsv
```

Takes about 15 minutes end to end, most of it the queue draining. It is safe to start and then keep
investigating.

## Pause the payout corridor

Faster than a rollback and narrower. Stops new submissions while leaving the queue intact; nothing is
lost, everything backs up.

```
./bin/corridor.sh pause payouts
./bin/corridor.sh resume payouts
```

## Restart the worker

```
./bin/worker.sh restart
```

The worker takes its settings from the environment at start, so a restart is also how any
configuration change takes effect. There is no config file.

## Before retrying a failed backlog

**Reconcile first.** `provider_submit` sends no idempotency key, so a payout that timed out may
already have been accepted upstream. Check each failed id against the provider's record before
resubmitting. A delayed payout is an incident; a double payout is a loss.

## Status page

```
./bin/status.sh set investigating "Payouts are delayed. We are working on it."
./bin/status.sh set resolved
```
