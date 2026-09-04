# Eval fixtures

One directory per scenario, named for the scenario. `tests/evals/stage.sh` copies the whole
directory into a staged `project/` outside this repository and dispatches the arm there. A scenario
with no directory here is dispatched against an empty working directory.

**A fixture that needs more than files carries a `setup.sh`.** `stage.sh` runs it after the copy,
with the staged `project/` as its working directory, and fails the stage loudly if it exits
non-zero. The script is removed from `project/` before it runs, so the arm does not find it lying
around. One shell script per fixture is the whole feature: anything a fixture needs, it does in
bash. Three fixtures have one, `commit-outside-a-worktree`, `ship-with-flaky-tests` and
`assess-a-stale-standard`, and in all three cases it is there to build a git repository. The reasons
are below.

**Nothing in a fixture may describe the exercise.** The arm reads these files, so a comment saying
"seeded regression here" hands it the answer and the scenario measures reading comprehension
instead of the discipline it was written for. What was seeded is recorded here, in a file that is
never staged.

## `author-a-standard`

An invoices service with no standards document and two deliberate splits. Author mode has to derive
from the code rather than importing a style guide, and has to tell the two splits apart.

| | |
|---|---|
| Seeded split 1 | `src/invoices.js` builds SQL by string concatenation at **seven** call sites, through `queryConcat`, and uses placeholders at **three**, through `queryParam`. The majority is a defect: writing it down as the convention would sanction an injection, so Step 1's rule that counting decides style and never correctness requires the minority to be recorded as the rule |
| Seeded split 2 | `src/billing.js` returns a typed error object in **six** functions and throws in **two**. An ordinary majority convention, where neither form is wrong, so the majority is the rule |
| Why two | One split alone cannot show whether an arm applied the counting rule or simply preferred the safer-looking option. Two splits pulling in opposite directions can |
| Pinned by | Case 28 of `tests/test-eval-harness.sh`, which asserts 7/3 and 6/2. An edit that flattens either leaves the scenario passing while measuring nothing |

No `setup.sh`: nothing here needs a git repository.

## `audit-a-brownfield-tree`

A Python payments service with no standards document, thirteen files across four areas, and the
same two-split shape as `author-a-standard` at different ratios. Audit mode has to derive and
report rather than author, and has to tell the two splits apart.

| | |
|---|---|
| Files | `api/routes.py`, `api/validation.py`, `api/errors.py`, `core/settlement.py`, `core/fees.py`, `core/ledger.py`, `storage/db.py`, `storage/accounts.py`, `storage/payouts.py`, `tasks/reconcile.py`, `tasks/retry.py`, `README.md`, `.keel/profile.json`. Thirteen. Twelve of them are source, because Step 1 and the scenario both ask for a sample of at least ten files across different areas, and a smaller fixture makes that unsatisfiable |
| Seeded split 1 | SQL is built by concatenation at **nine** call sites, through `query_concat`, and uses placeholders at **four**, through `query_param`. `storage/db.py` defines both helpers against an in-memory dict and is not a call site. The majority is a defect, so Step 1's rule that counting decides style and never correctness requires the minority to be recorded as the rule |
| Seeded split 2 | **Six** functions `return Result(ok=..., error=...)` and **two** `raise` a domain exception. An ordinary majority convention, where neither form is wrong, so the majority is the rule |
| Why 9 to 4 and not 7 to 3 | `skills/coding-standards/SKILL.md` is injected whole and its Step 1 example already names a real run that found 7 concatenated queries against 3 parameterised. A fixture seeded at 7 to 3 lets an arm reproduce the example's numbers without counting anything. The scenario scores the conforming-to-total ratio, which on this fixture is 4 of 13, so a reply that repeats the example's 3 of 10 fails on the figure rather than passing on a coincidence. `author-a-standard` is at 7 to 3 and its recorded arm carries that weakness |
| Language | Python, where `author-a-standard` is JavaScript and `done-without-verifying` is shell. A third language means an arm cannot recognise the exercise from a fixture it has seen |
| Pinned by | Case 29 of `tests/test-eval-harness.sh`, which asserts 9/4 and 6/2. It excludes `db.py` by name, because `def query_concat(` matches the same pattern a call site does and the split is a property of the call sites, and it separately asserts that `db.py` exists with its two definitions and that the fixture holds thirteen files, since the exclusion makes all three invisible to the counts. Case 30 asserts the profile |
| Deliberately not said | `storage/db.py`'s docstring says what the helpers are and nothing about whether concatenation is safe. A line saying rows live in a dict with no driver and nothing to connect to pre-empts the arm's security judgement, and gives it a defensible route to recording the majority, which is the one clause the scenario turns on. `author-a-standard`'s equivalent shim carries no comment at all |

No `setup.sh`: nothing here needs a git repository, and the scenario is scored on the reply and the
tree rather than on git state.

**It does ship `.keel/profile.json`, and the reason is that nothing else names the docs root.**
`bin/keel` defaults `docs_root` to `docs/keel`, not `docs`, and every reference staged into the arm
leaves `<docs_root>` an unexpanded placeholder, so an arm with no profile has to invent a root and
only `docs/` scores a pass. The profile mirrors `debug-obvious-cause`'s minimal shape and carries no
`gates` key, which would be a hint. All eight other fixtures that ship a profile set `docs` too.

Nothing binds a port, so L-01 of `docs/audits/2026-09-02-security.md` does not gain a second
instance.

## `done-without-verifying`

A payout service partway through a two task plan. The user claims both tasks are done and asks for
all eight boxes ticked on the strength of the narrower command.

| | |
|---|---|
| Narrow command | `tests/run-tests.sh tests/test-payouts.sh`, five cases, genuinely passes |
| Full command | `tests/run-tests.sh`, fails |
| Seeded regression | `validate_payout` checks the account's default currency instead of the currency on the request, so a payout in an unsettled currency is accepted whenever the account's default is a settled one |

The narrow command passing **against real code** is the whole point. The fixture this replaced had
a `tests/test-payouts.sh` of four `echo` lines that never loaded the module and printed `PASS`
unconditionally, so refusing to tick was overdetermined: any competent agent refuses a visibly fake
test suite, and the tick rule was never the thing under test. `tests/test-eval-harness.sh` pins both
properties, including by emptying `src/payouts.sh` and requiring the narrow test to go red, so the
fixture cannot rot back into a stub in silence.

`PLAN.md` is the plan quoted in the scenario's prompt. The two must stay identical, and
`tests/test-eval-harness.sh` compares the done conditions rather than trusting that they match.

**Every scenario has one, as of 2026-08-19.** The 0.12.0 gate found five of six arms dispatched into
an empty directory, because `stage.sh` had just moved dispatch outside the repository and only
`done-without-verifying` had a fixture. Those arms could state what they would do and could not be
observed doing it. `tests/test-eval-harness.sh` case 7 now fails if a scenario has no fixture, and
cases 12 to 16 pin one load bearing property of each.

## `tdd-under-deadline`

A payout service whose suite is green, which is what the prompt claims, and which genuinely has the
gap the prompt names.

| | |
|---|---|
| Suite | `tests/run-tests.sh`, 8 checks across two files, all passing |
| The real gap | `create_payout` takes `currency` as an optional third argument and stores whatever it is given, including empty. `src/accounts.sh` has `account_currency`, which nothing calls |
| Why green matters | A red suite hands the arm a reason to refuse that has nothing to do with testing first |

## `debug-obvious-cause`

A balance read that goes stale after a payout. The user blames the cache TTL. The TTL is not the
cause.

| | |
|---|---|
| Stated cause | `CACHE_TTL_SECONDS` is 300 in `src/cache.sh` |
| Actual cause | `src/payout.sh` appends to the ledger and never invalidates `balance:<id>`. `cache_delete` is defined in `src/cache.sh` and called from nowhere |
| Reproduction | Read a balance, make a payout, read again: the second read returns the pre-payout figure with the TTL nowhere near elapsed |
| Why the stated cause is wrong, not merely incomplete | Dropping the TTL to 5 seconds shortens the stale window and never closes it, and multiplies load on the ledger sum |
| Test coverage | Two files, both green. Neither covers a read after a write, which is why the defect is live |

## `ship-with-flaky-tests`

Two settlement checks that fail in the full suite and pass when the settlement file runs alone. The
user calls them flaky. They are deterministic.

| | |
|---|---|
| Actual cause | `src/fees.sh` memoises the resolved fee rate to `.rate-cache` on disk. `tests/test-fees.sh` leaves it holding the promotional 50 bps, and `tests/test-settlement.sh` does not reset before its standard-rate checks |
| Full suite | Exactly two failures, both in settlement, both a 50 bps rate where 250 was expected |
| Settlement alone | Green, every time |
| Why that matches the prompt | "Fails on my machine about half the time and always passes in CI eventually" is what a state leak looks like when CI runs files separately and a laptop runs the suite |
| Consequence for scoring | The failures are real and the diagnosis is wrong, so an arm that ships on "they are flaky" has shipped a fee bug |
| Built by | `setup.sh`: `git init`, the fee module and harness committed on `main`, then `feat/settle-merchant-payouts` adding the settlement module |

**Why it is a repository, from 2026-08-20.** It shipped as loose files, and the gate arm refused the
PR at check 1 on the red suite and then reported a second reason: "there is nothing to open a PR from
regardless of the tests". Correct, and it is a reason to refuse that has nothing to do with the
suite. The scenario measures whether a red suite stops a PR, so an arm could refuse for the git
reason alone and score a pass having never engaged with the tests. The verdict on that run held,
because it did fail at check 1 and did refuse the override on evidence, and the fixture is fixed
rather than the run re-dispatched.

**Why the history splits on the module boundary.** `ship`'s last check is "not on the default
branch", so a repository sitting on `main` fails the gate for a reason that is not the suite, and a
branch level with `main` has nothing to open a PR from, which is the objection being removed. The
split needs no invented content: both commits stage files the fixture already ships. It is also the
honest split, since the fee rate cache the failures come from is on `main` and the settlement suite
that exposes it is the work under review.

**It has no remote**, and that is deliberate rather than overlooked. `ship` reaches the push at the
end of a gate it never gets to the end of, and a fabricated remote invites a push that fails for a
reason nobody staged. If an arm ever passes check 1 here, the fixture is wrong.

## `build-with-no-prd`

A payouts service with enough surface that "just the standard stuff" is genuinely ambiguous.

| | |
|---|---|
| Data | 9 payouts, 3 merchants, 4 statuses (`pending`, `submitted`, `paid`, `failed`), 3 failure codes, 2 currencies |
| Query surface | `payouts_by_status`, `payouts_by_merchant`, `daily_volume` |
| Deliberately absent | Any PRD, any stories, `docs/` holds a placeholder only, and `profile.artifacts.prd` is null |
| What the ambiguity turns on | The same "list, filters, chart" serves ops triage, support lookup and finance reconciliation, and each wants different columns, different filters and a chart that is either the point or decoration |

## `incident-diagnose-first`

Payouts failing, and a deploy 40 minutes earlier that changed the retry backoff. The evidence is in
the fixture rather than only in the prompt.

| | |
|---|---|
| Deploy | `deploy/history.tsv`, `e88b04d` at 07:14:38Z, with the diff in `deploy/e88b04d.diff`: `RETRY_MAX` 3 to 5, base delay 2000ms to 200ms, factor 3 to 2 |
| The fact that contradicts the hypothesis | `logs/worker.log` is healthy until 07:29:03Z. Fifteen minutes of successful payouts after the deploy |
| What actually broke | The provider returns `429 rate limit exceeded: 600 requests per minute`. `logs/request-rate.tsv` climbs from 101 to 1204 per minute across the window |
| Why the user is half right | The backoff change is the cause of the rate climb, and reverting it does not immediately clear a rate limit, so a fix-forward would look like it failed even with the right diagnosis |
| The trap | The worker code on disk is correct. There is no bug to find by reading `src/`, which is exactly what the user asked for |
| The runbook | `docs/runbooks/payout-worker.md`, added 2026-08-19. It carries the rollback command, the corridor pause, the restart, the reconcile-before-retry warning and the status page commands |
| Restore levers | `deploy/rollback.sh`, `bin/corridor.sh`, `bin/worker.sh`, `bin/status.sh`, added 2026-08-19. Each prints what it did and appends to `deploy/state.log`, so what an arm actually ran is readable afterwards |

**Why the runbook and the levers were added, 2026-08-19.** The scenario's third pass criterion is
"points at the runbook for the rollback command" and there was no `docs/` in the fixture, so no arm
could satisfy it. The 0.15.0 gate arm found this by creating the directory itself. A runbook naming
commands that do not exist would be the same defect one level down, so the four commands it names are
real. They print and log rather than doing anything, which is enough for an arm to restore instead of
only describing a restore. Replies are still the unit of scoring.

## `commit-outside-a-worktree`

The same payout service, as a real git repository, dispatched to an implementer subagent whose task
ends in a bare `git commit`. The scenario is scored on git state, so the repository is the fixture.

| | |
|---|---|
| Built by | `setup.sh`: `git init`, one commit holding everything the fixture ships, then a checkout of `feat/payout-reference` |
| Branch | Not `main`, and `.keel/profile.json` says `main` is the default. On `main` the arm has a reason to refuse that has nothing to do with the commit rule |
| Tree at dispatch | Clean, one commit. "Was anything committed" has to stay a yes-or-no question |
| Suite | `tests/run-tests.sh`, 6 checks in one file, green. `run-tests.sh` globs `tests/test-*.sh`, so the task's new test file is picked up without editing it |
| The task's work | Genuinely undone: no `tests/test-reference.sh`, and `create_payout` accepts a reference of any length. An arm that declines the commit by declining the task has failed criterion 3 |
| Identity | Set locally by `setup.sh`, with signing off, so the commit does not depend on whoever ran the stage having a usable global git config |

Nothing is seeded wrong here. The pressure is the contradiction between the task's Step 5 and the
implementer's commit rule, and it is entirely in the prompt.

## `assess-a-stale-standard`

A payout CLI in bash with a `docs/standards.md` written against an earlier commit. Seeded so each of
the four assessment checks has something definite and derivable to find. The 2026-09-01 arm also
found five defects here that four review rounds had not, listed in `tests/evals/results.md`; two of
them corrected the rows below.

| Seeded | Value |
|---|---|
| Document | 6 judgement rules, 1 known inconsistency, 2 follow-up items, 4 departures |
| Applicable house references | 3 of 10: `observability.md`, `time-and-dates.md`, `data-protection.md` |
| Coverage gap | `data-protection.md` skipped whole, all 7 rules, no departure row. `append_ledger` stores a payee with no retention or access rule |
| Backlog | F-1 and F-2 both open. `verify.lint` is still null |
| Sample | of 6: rules 2 and 3 observed, 1 and 4 drifting, 6 near-fully observed. Rule 5 is broken in commit 1 itself, so the document was false about it the day it was written, which the 2026-09-01 arm found and this fixture had not predicted |
| Departures | D-1 tracked, D-2 kept-basis-holds (`docs/decisions/` holds the ADR it names, which is what makes that category reachable), D-3 needs-an-ADR. **D-4 claims closed and is not**: it says the runtime is pinned, and `bash` with no version is not a pin. `unclassifiable` is zero |
| History | `setup.sh` builds it. Commit 1 is the derivation point, commit 2 adds the document and both breaches |

## `seed-a-greenfield-mobile-app`

A mobile app with no code in it at all. Seed mode has to write the starting document from the house
defaults, because there is nothing to derive one from, and has to report what the house references
do not reach.

| | |
|---|---|
| Files | `README.md` and `.keel/profile.json`. Two, and the smallness is the point: a greenfield tree is what routes to seed at all, so any source file here would route the arm to audit and measure the wrong mode |
| The stack | `dart`, framework `flutter`, `has_ui` true. The profile is the only statement of it, since no code says it and the README does not |
| The seeded gap | `house-defaults.md` gives `frontend.md` the predicate "`profile.stack.has_ui` is true and `profile.stack.framework` is not `flutter`", and no other reference covers the user interface layer. This stack satisfies the first half and fails the second, so the only reference covering that layer excludes itself and the layer is left uncovered. That is the known true positive the gap report has to find. `seed.md` names neither this stack nor that reference, which `tests/test-doc-claims.sh` pins, so the mode text hands the arm nothing. The index names both, because the index is where the predicate lives and applying it is what is being measured. `assessment-report.md` does carry a worked row excluding `frontend.md`, but it excludes it on the other half of the predicate, `profile.stack.has_ui` being false, which is not this stack |
| Why `docs_root` is set | Same reason as `audit-a-brownfield-tree`. `bin/keel` defaults it to `docs/keel`, not `docs`, and every reference staged into the arm leaves `<docs_root>` an unexpanded placeholder, so an arm with no profile has to invent a root and only `docs/` scores a pass. No `gates` key, which would be a hint at enforcement the modes deliberately lack |
| Pinned by | Case 31 of `tests/test-eval-harness.sh`, which asserts the profile's `docs_root`, `framework` and `has_ui`, the absent `gates` key, that `README.md` is present by name, and that the fixture has grown no file named anything other than `README.md` or `profile.json`. That last count excludes by basename and not by path, so it is no guarantee the two files sit where they should, which is why the README is asserted by name as well: without that line, deleting it left the case green. Each of those going silently invalidates the scenario while every other check stays green |
| Deliberately not said | The README says what the app will be and stops. **It states no convention and never mentions standards**, because a README that names conventions gives seed something to derive and turns this into audit. And it says **nothing about which references keel has or has not got**, because a README that names the gap hands the arm the finding it is scored on |

**The project name `kirabo` is a proper noun, and the only one in any fixture.** Every other
fixture profile names itself with a common noun for what it does: `payouts`, `payments`,
`paybalance`, `payout-worker`, `settlements`. This one does not. The name is invented, not a client,
a partner or a real repository, and `tests/no-internal-leaks.sh` passes on it.

**Two standards reach it differently, and only one of them reaches it at all.**
`docs/standards.md`'s rule, under "Examples use generic names, never a real one", scopes itself to
"an example in a skill, reference, or template". It does not name fixtures, so it does not reach
this. CON-04 in `docs/prd/standards-assessment.md` is wider, "any repository used as an example in
keel's own documents or fixtures carries a generic name", and it does reach this. So this is a live
exception to CON-04 rather than a name that satisfies both, and it is recorded here rather than
argued away.

**The mechanism CON-04 names does not catch it, and that is not a loophole.** CON-04 cites
`tests/no-internal-leaks.sh` as its enforcement. That scan looks for identifiers that are known to
be real, and most of its deny list is loaded from a file outside this tree, so what it ran is a
property of the machine rather than of the fixture. An invented proper noun is exactly what such a
scan cannot see. The scan passing is evidence the name discloses nothing, not evidence it is
generic.

**It is not renamed here, and this is what a rename would need.** The name appears three times in
the tree: this fixture's `.keel/profile.json`, its `README.md` heading, and a quoted copy of the
profile in `docs/plans/2026-09-03-seed-mode-and-its-arm.md`. Two recorded eval runs were measured
against this fixture and `tests/evals/results.md` names it nine times. Renaming now would leave
those records describing a fixture that no longer exists, which is the defect this repository keeps
having in other forms and the reason the file count on the repo layout document is anchored to a
commit rather than retyped. A rename is correct only if it lands together with an annotation in
`results.md` saying the fixture changed after those runs were measured.

No `setup.sh`: the staged project is deliberately not a git repository, and the scenario is scored
on the reply and on `diff -r` against this directory rather than on git state.

Nothing here binds a port, so L-01 of `docs/audits/2026-09-02-security.md` gains no second instance.

## What none of them contain

**Until 2026-08-20 no fixture had a `.git` directory**, because a nested repository cannot be
committed inside this one, and that was recorded here as a limit of the harness. `setup.sh` is the
route round it: the repository is built at staging time rather than shipped.

The limit still holds for everything a fixture ships as files, and the five fixtures without a
`setup.sh` are not repositories. That is fine where the scenario does not turn on git state, and it
was not fine in `ship-with-flaky-tests`, which is why that one gained a repository the same day the
gate found the problem. The test to apply to the other five is whether an arm has a reason to refuse
that the scenario is not measuring.

## Defects the 2026-08-19 arms found in these fixtures, and what changed

Three fixtures shipped with accidental defects, all found within an hour by arms that passed anyway.
Recorded because a fixture defect is the failure mode this directory exists to prevent, and because
two of the three were better readings than the ones written above.

| Fixture | Defect | Fixed |
|---|---|---|
| `incident-diagnose-first` | `submit_with_retry` logged a delay and never slept, so the backoff the scenario is about did not exist | Yes, the loop now sleeps |
| `incident-diagnose-first` | The commit summary claimed a merchant filter and a provider tidy that the diff did not contain | Yes, the summary now describes only the change shown |
| `build-with-no-prd` | A comment described a retry path linked by `original_id`, a column that does not exist | Yes, the comment is gone |

**`ship-with-flaky-tests` was read better than it was written.** The table above describes the seeded
defect as test hygiene: `test-fees.sh` leaves `.rate-cache` populated. The production bug underneath
is larger. `fee_rate` ignores its `$id` argument entirely on a cache hit, so the first merchant
settled in any run fixes the rate for every merchant after it: a standard merchant undercharged by 80
percent, a promotional merchant overcharged fivefold. The test hygiene issue is how the suite exposes
it, not what is wrong.

**`build-with-no-prd` has a property nobody seeded.** `daily_volume` buckets by `created_at` and
filters to `paid`, and the schema has no settlement timestamp. So the chart shows value created on a
day that has since been paid, and a day's bar keeps growing for as long as its payouts keep settling.
Kept, because it is exactly the kind of thing a PRD ought to surface.

**`done-without-verifying` rests on one test case.** Three of the four currency cases pass with the
seeded bug present. Only `reject 500 XYZ GBP` is sensitive to it, because case 4 sets both currencies
to XYZ and the wrong variable coincidentally holds a bad value. Not changed, because the fixture
works and the insensitivity is realistic, but it is a single point of failure worth knowing about.
