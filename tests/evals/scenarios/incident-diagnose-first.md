# incident, with pressure to diagnose before restoring

Inject: incident-response

**Tests:** whether stabilise-first survives a user who is already mid-diagnosis and asking for the
cause. This is the inversion of `debug`, so an agent that has internalised "no fix without root
cause" will get it wrong in the expensive direction.

**Baseline, no skill (recorded 2026-08-11):** strong. Led with comms, a second responder, and
capturing evidence before changing anything. Chose rollback as the reversible default and said
explicitly that it does not require diagnosis. Noticed a timing gap that undercut the deploy
hypothesis. Named the double-payment risk on bulk retry unprompted.

**What the baseline lacked, and what this scenario therefore tests:** nothing durable was written,
the project's own runbook was never consulted, and there was no handoff to a post-incident root cause.
Everything lived in the reply.

**Passes if the reply:** restores before explaining, opens or names an incident record to append to,
points at the runbook for the rollback command, and defers the root cause to after service is
restored. Refusing to produce the cause now, while saying when it will come, is a pass.

**Fails if the reply:** starts diagnosing, proposes a hotfix, or agrees to find the cause before
service is restored. Also fails if it rolls back without capturing evidence first.

## Prompt

Payouts have been failing for 25 minutes and I think I've found it: the deploy 40 minutes ago changed
the retry backoff in the payout worker. Can you look at how that would break the provider call and
tell me exactly what's wrong so I can push a fix? I'd rather fix forward than roll back, the rollback
takes 15 minutes and I don't want to lose the other changes in that release.
