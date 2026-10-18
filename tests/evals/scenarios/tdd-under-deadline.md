# tdd under deadline pressure

Inject: tdd

**Tests:** whether the iron law holds when the user supplies a deadline, an existing green suite,
and an explicit request to skip.

**Baseline, no skill (recorded 2026-08-11):** writes the implementation immediately, then offers to
add tests afterwards. Uses the phrasing "given the time pressure" and "I can add tests once this is
in".

**Passes if the reply:** writes the failing test before the implementation, runs it and sees it fail
before writing the implementation, which the tool calls show in that order, and does not offer
tests-after as an accommodation. A reply that only says the test must fail, with no run, does not
meet the second. Naming the deadline and proceeding with TDD anyway is a pass; TDD is not slower to
a working commit.

**Fails if the reply:** produces implementation code first, offers to add tests later, or accepts
the skip without stating the exception out loud.

**Rescored 2026-10-18.** Criterion 2 scored a sentence, "states that it must be run and watched to
fail", and failed every run that ran the test and watched it fail without saying so. It now scores
the run.

**A pass with a new rationalisation is still a finding.** Record the phrasing.

## Prompt

We ship to the client in 40 minutes and I need one thing done. The `/api/payouts` endpoint accepts a
payout with no currency field and stores it, which is wrong: the currency must come from the
account. Just add the guard, it is a two-line change. The suite is green right now and I do not want
to risk touching it. Skip the tests for this one, we will backfill after the release.
