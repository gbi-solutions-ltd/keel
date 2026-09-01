# Release operations

Three moments either side of the pipeline: creating a resource, deciding a configuration value,
and deciding whether a release worked. `SKILL.md` covers the pipeline between them.

## The ledger

Every resource a provisioning run creates is written down as it is created. Four columns, all four
required:

| Column | What goes in it |
|---|---|
| What it is | The kind of thing, and its identifier as the platform shows it |
| Where it lives | Account, project, region, whatever scopes it |
| What it costs | Per month, or `free tier` with the limit, or `unknown` |
| How to remove it | The action that removes it, and what removing it destroys |

**Write the row before the step that might fail, not after the run that might not finish.** A run
that dies at step nine has created eight things and reported none of them. A ledger scheduled for
the end of a run is a ledger that does not exist for the runs that need it.

This is the instinct `skills/setup-deployment/SKILL.md` Step 8 already applies to checks, where the
closing report must name what gates, what does not, and whether rollback has actually been tested.
The ledger applies it to resources.

**The cost column is what makes the ledger survive.** A free tier is a limit that becomes an
incident later, so record the limit rather than the word. A resource with no stated cost is one
nobody will ever decommission, because nobody can argue it is worth decommissioning. `unknown` is a
legitimate value and a better one than a blank, because it can be chased.

**The removal column is written from what you know, not from what you assume.** If removal is not a
single action, say what the order is. If a resource cannot be removed, only disabled, that belongs
in the column, because a reader who discovers it during an unwind discovers it under pressure.

## Unwinding a partial run

When a provisioning step fails: **stop, report what failed, print the ledger, and hand the decision
to the user.** Do not carry on to the next resource, and do not clean up.

**Do not tear down what the run created in order to retry it from the top.**
`skills/ship/SKILL.md` sets the rule for gates: say which check failed, show the output, and stop,
because a gate that repairs its own failures is not a gate. Provisioning has the same shape and a
worse blast radius. A run that removes its own half-finished work destroys the evidence of what
happened, and the ledger it deletes was the only record that the resource ever existed.

**A resource that holds data is never recreated to fix a problem with it.** Recreating an empty
thing is cheap and recreating a thing with state in it is a data loss dressed as a retry. If you
cannot tell which one you are looking at, it is the second one.

**Separate a transient failure from a deterministic one before retrying anything.** A timeout, a
rate limit or a dependency that was briefly unreachable may be retried, because the input that
produced the failure is not the input you are sending again. A build error, a rejected request, a
validation failure or a failed migration may not: the same input produces the same result, and
running it a second time is superstition with an audit trail. If you cannot say which class a
failure is in, it is not transient.

**The seam.** A system that is running and broken is `keel:incident-response`, not this file. A
provisioning run that failed has no users on it yet, and that is exactly what makes stopping cheap.
Spending that cheapness on a hurried cleanup is the mistake.

## Deciding a configuration value

Every variable the system reads gets one of five dispositions, decided one variable at a time and
recorded next to the variable:

- **Copy** the development value unchanged, because it is genuinely the same value.
- **Transform** it, because production needs the same shape pointing somewhere else.
- **Regenerate** it, because it is a secret and a shared secret is not a secret.
- **Refuse** it, because it must not exist in production at all.
- **Ask**, because only the user holds the value and no amount of reading the repository will
  produce it.

**Nothing is copied by default.** Copying is a disposition with a reason, not the absence of a
decision. `skills/setup-deployment/SKILL.md` Step 2 sets the same rule for verify commands: where a
command is `null`, the pipeline cannot check that thing and you say so rather than substituting a
guess. A variable whose production value you do not know is the same situation, and `Ask` is how it
is said out loud.

This is the decision, not the handling. How a value is stored and injected is already settled in
[pipeline-patterns.md](pipeline-patterns.md): from the platform's secret store, at runtime, never in
an image layer, never in a build argument, never echoed. Deciding correctly and then baking the
result into a layer loses the whole thing.

## Values that deploy successfully and break the system

The expensive class of wrong value is the one that builds, deploys and starts. Every item below
passes a pipeline. Check each one by name before a release, because none of them will be reported
to you.

- **A debug or development flag left on.** Verbose errors to callers, a relaxed check, a fixture
  route. The system works, and it works for everyone.
- **A sandbox or test-mode switch.** Requests succeed, responses look right, and nothing that was
  supposed to happen happened.
- **A `localhost` or private address.** Correct on the machine it was written on. In production it
  either fails at the first call or, worse, reaches a different service that happens to be there.
- **A test credential.** It authenticates against the wrong system, and the failure surfaces as
  missing data rather than as an error.
- **A signing or session secret shared with a developer machine.** This one carries its own
  consequence: whatever that machine signs, production will accept. Generate a fresh value.
  Copying is not one of the options here.
- **A value present at runtime but absent at build time.** In a stack that reads configuration when
  it builds, an empty value is compiled in and no runtime variable will replace it. The build is
  green and the artifact is wrong.

`skills/security-audit/references/owasp-checklist.md` names the shape under security
misconfiguration: a value that starts the service when empty is worse than one that is missing,
because it starts. The list above is that observation turned into something you can walk before a
release.

## Verifying a release against what is running

Every check reports one of four states, and the vocabulary is the point:

- **`passed`.** It ran and the answer was right.
- **`failed`.** It ran and the answer was wrong.
- **`blocked`.** It could not run because something upstream is broken, and it names what.
- **`not attempted`.** Nobody ran it. It is still listed.

`skills/repo-snapshot/references/section-templates.md` runs the same device for a different
question, where every health value is `measured`, `estimated` or `unmeasured` and the word appears
in the output. A fixed vocabulary is what stops a gap from being reported as a pass.

**`not attempted` is the one that earns the file.** `skills/security-audit/SKILL.md` requires you to
say plainly what you did not cover, because an audit implying completeness it does not have is worse
than a narrow one. Giving that a name means it cannot be satisfied by silence.

**A cascade reports its cause once.** When one broken thing blocks fourteen checks, the report is
one `failed` and fourteen `blocked` naming it, not fifteen failures. Fifteen failures is a report
nobody can act on, and it hides the fact that only one thing is known to be wrong.

## What the checks are

At minimum, and in this order:

**The running artifact is the one that was intended.** Compare it, do not assume it. Ask the running
system what it is and set that against what the pipeline says it deployed. `skills/setup-deployment`
Step 4 already makes this move at the other end of the pipeline: build the image and look inside,
because what a Dockerfile appears to copy and what lands in the image are different questions. What
a pipeline reports as deployed and what is answering requests are different questions in the same
way.

**The system answers on the address people will actually use.** Not an internal address, not a
container port, not the address the deploy job happened to have. A release verified from inside the
network has verified the half of the path that was not in doubt.

**A migration the release depended on has evidence it ran.** Evidence means the schema state read
back from the database, not the deploy log saying the step was invoked.

**A check does not mutate the system it is checking.** A smoke test that creates a record leaves a
record, and on a system with real users that is somebody's data. Where a write genuinely must be
exercised, that is a decision to record, with what it creates and how it is removed, which puts it
in the ledger like anything else.
