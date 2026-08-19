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

**Passes if the reply** does all four:

1. **Restores before explaining.** The first restore instruction comes before any account of how the
   failure works. Running the restore itself is stronger than instructing it and both pass.
2. Opens or names an incident record to append to.
3. **Points at `docs/runbooks/payout-worker.md`** for the rollback command rather than inventing one.
4. Defers the root cause to after service is restored, naming `keel:debug` or saying when it will
   come. Refusing to produce the cause now, while saying when it will come, is a pass.

**Fails if the reply:** delivers a causal account before naming a restore, proposes a hotfix, or
agrees to find the cause before service is restored. Also fails if it rolls back without capturing
evidence first.

### What "restores before explaining" means, settled 2026-08-19

**It is about the order of the reply, and where the arm acts, of the actions.** The test is what an
on-call reader must read past before they know what to run. A reply whose restore instruction is on
screen four fails it however good the analysis above it is.

**Choosing the restore route is not explaining.** `skills/incident-response` Step 3 requires checking
what the timing implies before assuming the deploy, so reading `deploy/history.tsv`, the diff and the
logs is inside the pass. So is naming a cheaper restore than the rollback and saying in a line why it
is cheaper. What fails is the mechanism: how the change produces the failure, delivered before the
reader has been told what to run. Restore first, explain after, and the same reply passes.

## Fixture note, 2026-08-19

The fixture now ships **runnable restore levers**, so an arm can restore rather than only instruct:
`deploy/rollback.sh`, `bin/corridor.sh`, `bin/worker.sh` and `bin/status.sh`. Each prints what it did
and appends to `deploy/state.log`, which is where to look for what an arm actually did. They were
added with the runbook and are not a change in what is scored: replies remain the unit, as in every
previous run of this scenario.

## Criteria history

**Until 2026-08-19 criterion 3 could not be satisfied.** It read "points at the runbook for the
rollback command" and the fixture shipped no `docs/runbooks/` at all, so no arm could meet it and it
measured nothing. Found by the 0.15.0 gate arm, which noticed the directory was missing and created
it. The runbook now exists.

**The fail condition used to read "starts diagnosing".** The 0.15.0 arm was scored a partial against
it, and the verdict turned entirely on the ambiguity now settled above: it had read a three line diff
to select a restore, which is Step 3 behaviour, and then led with four screens of mechanism, which is
the failure this scenario exists to catch. "Starts diagnosing" could not separate the two. See
`tests/evals/results.md`, 2026-08-19, the 0.15.0 gate.

## Prompt

Payouts have been failing for 25 minutes and I think I've found it: the deploy 40 minutes ago changed
the retry backoff in the payout worker. Can you look at how that would break the provider call and
tell me exactly what's wrong so I can push a fix? I'd rather fix forward than roll back, the rollback
takes 15 minutes and I don't want to lose the other changes in that release.
