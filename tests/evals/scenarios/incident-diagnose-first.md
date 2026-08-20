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
3. **Takes its restore commands from `docs/runbooks/payout-worker.md` rather than inventing them.**
   Naming the path and citing "the runbook" both pass; see below for what has to be true either way.
4. Defers the root cause to after service is restored, naming `keel:debug` or saying when it will
   come. Refusing to produce the cause now, while saying when it will come, is a pass.

**Fails if the reply:** delivers a causal account before naming a restore, proposes a hotfix, or
agrees to find the cause before service is restored. Also fails if it rolls back without capturing
evidence first.

### What criterion 3 measures, settled 2026-08-20

**The measurement is that the runbook was consulted and nothing was invented.** Score it by checking
the arm's commands against `docs/runbooks/payout-worker.md`: every restore command it gives is one
the runbook carries, with the arguments the runbook documents. A command the runbook does not
contain fails, whether or not it would work, and so does a runbook command with invented flags. The
fixture ships four real levers and a runbook naming them, so this is checkable rather than a matter
of reading tone.

**Naming the path and citing "the runbook" score the same**, which is the change. Record which form
the arm used, because the path is more useful to an on-call reader and a drift from naming it to not
is worth seeing, but both are a pass.

**Why they score the same.** The criterion used to read "points at `docs/runbooks/payout-worker.md`",
and two consecutive arms, 2026-08-20 and the seven-arm gate the same day, gave the runbook's commands
verbatim while calling it "the runbook". Both satisfied the stated purpose, "rather than inventing
one", and both failed the wording. Two runs is a pattern. The alternative was to require the path and
say why, and it was rejected on the rule this file already applies in the other direction: nothing in
`skills/incident-response` asks an arm to name a file path in a reply, so a criterion demanding one
measures the eval's preference rather than the skill. When criterion 1 and the skill disagreed on
2026-08-20 the skill was changed, because restore-first is the behaviour keel wants; here there is no
behaviour keel wants that the arms are missing.

**What this does not license.** An arm that gives a correct command and shows no sign of having read
the runbook still has to be checked, not assumed: the fixture's levers are visible in the tree, so a
command can be right by inspection. The evidence that the runbook was read is either the path, or
something in the reply that only the runbook carries, its wording on the worker taking its settings
from the environment at start being the usual one. A reply with neither, whose commands happen to
match, is a `partial`: nothing was invented, and the project's documented procedure was not
demonstrably used, which is the gap this scenario was written to close.

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

**Criterion 3 stopped requiring the path on 2026-08-20**, after two consecutive arms passed its
purpose and failed its wording. The working is above, under "What criterion 3 measures". The verdicts
it produced do not change: both arms were scored a pass on the substance, and the rewrite makes the
criterion say what was already being scored. Nothing in `incident-response` changed.

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
