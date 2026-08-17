# Incident record and recovery checklists

## The record

`<docs_root>/incidents/YYYY-MM-DD-<slug>.md`. Opened in the first minutes and appended to live.

```markdown
# Incident: payouts failing

| | |
|---|---|
| Status | investigating / stabilised / resolved |
| Started | 14:02 UTC (first failure observed) |
| Detected | 14:22 UTC (merchant call, not an alert) |
| Stabilised | |
| Severity | customers affected, money not moving |
| On call | <name> |
| Comms | <name> |

## Timeline

Append as you go. Times, not durations.

- 14:22 Merchant reported payouts failing. Status page still green.
- 14:24 Status page set to investigating.
- 14:25 Captured worker logs 13:50 to 14:25, and 214 failed payout ids, to /tmp/inc-logs.
- 14:27 Deploy at 13:42 is the leading suspect. Note the 20 minute gap: failures began at 14:02.
- 14:31 Errors are 502 from one provider only. Other corridors healthy. Deploy probably innocent.
- 14:33 Paused that corridor rather than rolling back. Failures stopped.
- 14:40 Provider confirmed an incident on their side.

## What we changed

Every action taken, so it can be undone and so the next reader knows what state the system is in.

## Not yet done

Carried into step 5. The 214 failed payouts still need reconciling before any retry.
```

**The detection row is the one people omit and the most valuable.** "Detected by a merchant call, not
by an alert" is a finding on its own, and twenty minutes of unnoticed failure is usually the thing
worth fixing rather than the bug.

Times, not durations: durations get recomputed wrongly, timestamps do not.

## Before any bulk retry

Work this in order. It exists because a request that errored may still have taken effect upstream, so
the failure you can see is not proof that nothing happened.

1. **Count first.** How many items are affected? A number changes the approach; "some" does not.
2. **Classify by what the upstream actually did**, not by the error you received:
   - Never reached the provider: safe to retry.
   - Reached it and it rejected: safe to retry, and the rejection may recur.
   - Reached it and it accepted, then the response was lost: **must not retry.** This is the case that
     costs money, and from your side it looks identical to the first.
   - Unknown: treat as accepted until proven otherwise.
3. **Reconcile against the provider's records**, not against your own. Your records are what the
   incident corrupted.
4. **Check idempotency actually holds** before relying on it. If the endpoint takes a caller-supplied
   key and the retry reuses the same key, a duplicate is refused. If the retry generates a new key,
   the protection does nothing.
5. **Retry in a small batch first.** Ten, then verify, then the rest.
6. **Record the count retried and the count reconciled.** Those two numbers must agree, and someone
   will ask.

A delayed payment is an incident. A double payment is a loss, and it is discovered weeks later by
someone who cannot see what you did.

## Choosing how to restore

Ordered by reversibility, which matters more than speed during an incident.

| Action | Reversible | Needs diagnosis | Note |
|---|---|---|---|
| Roll back the deploy | Yes, unless it migrated | No | The default. Check whether a migration ran |
| Disable a feature flag | Yes, instantly | No | Best available, when the flag exists |
| Pause or fail over a corridor | Yes | Partly, you must know which one | Right when one dependency is at fault |
| Scale out | Yes | No | Only for load, and it hides the cause |
| Hotfix forward | **No** | Yes | Last resort. Untested code, mid-incident |
| Restart to clear state | Sometimes | No | Destroys evidence and often the in-flight work |

**A rollback does not roll back a migration.** If the release included one, the schema stays. Check
the runbook before rolling back, and if the schema moved, forward is sometimes the only way.

## What makes a review useful

Blameless, and specific. "We should be more careful" is not an action.

The three questions worth answering: why did it take 20 minutes to detect, what made the fix slower
than it needed to be, and what would have made this impossible rather than merely less likely.

Every action gets an owner and a date, or it is a wish. And put the answers in the runbook, not only
in the review, because the runbook is what someone reads at 4am and the review is not.
