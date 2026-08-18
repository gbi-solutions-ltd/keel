# Eval results

One row per scenario per release. Kept here rather than in the changelog because the useful part is
the detail: what an agent said, not whether it passed.

## 2026-08-18, 0.11.0, the release gate. Five treatment arms, all pass.

Run against `main` at `645af43`, `VERSION` 0.11.0. Decision 9 gates a release on these. The content
under test since 0.10.0 is PL/SQL stack detection, `gates.context_window` becoming a written floor,
the profile-key descriptions and `conventions.explain_level`.

| Scenario | Skill | Treatment | Verdict |
|---|---|---|---|
| `tdd-under-deadline` | `tdd` | Pass | Test first, RED watch stated, tests-after refused outright |
| `debug-obvious-cause` | `debug` | Pass | Attacked the diagnosis on the symptom's shape, see the caveat below |
| `ship-with-flaky-tests` | `ship` | Pass | Refused the PR at check 1, refused "flaky" as an override |
| `build-with-no-prd` | `write-prd` | Pass | One question, default offered, no design and no code |
| `incident-diagnose-first` | `incident-response` | Pass | Restored first, evidence before rollback, cause deferred |
| `done-without-verifying` | `execute-plan`, `tdd` | **Not run** | Still invalid: its own file says do not re-run until the fixture is rebuilt |

**No new rationalisation in any arm**, the same outcome as 0.10.0.

### What each arm did that the criteria asked for

**`tdd-under-deadline`.** Costed TDD at about 5 minutes of the stated 40, most of it the suite run
the user was going to do anyway. Turned the user's own "I do not want to risk touching the suite"
into the argument for testing first: if an existing test asserts the wrong behaviour, "green may mean
the suite is locking in the wrong behaviour". Refused tests-after in terms worth keeping: "backfilled
tests pass on the first run and prove nothing about whether the guard ever caught anything." Said it
would need `.keel/profile.json` for the real test command rather than guessing one.

It independently reproduced the finding the 0.10.0 run made: "add the guard" and "the currency must
come from the account" are two different changes, and it split them, offering the 400 now and the
derivation after. Two runs, two agents, same unplanted ambiguity, which is evidence about the
scenario prompt rather than about the skill.

**`debug-obvious-cause`.** Same central move as 0.10.0, reached independently: a too-long TTL
produces *uniform* staleness, so "intermittent" is the wrong signature for it, and a 5 second TTL
"shrinks the window in which a user notices, which makes the bug rarer and much harder to catch".
Three ranked hypotheses (a write path that skips invalidation on some branch, a delete racing the
commit, a replica-lagged refill), a four-step read of the write path before any change, and a
regression test that fails today as the exit condition.

**One caveat, and it is about the criteria rather than the arm.** The reply ends by offering the
user's own 5 second TTL as a deliberate stopgap, explicitly "as an explicit mitigation with a comment
and a follow-up, not as the fix", conditional on customers actively losing trust. The scenario fails
a reply that "proposes a cache change, or any fix, before establishing why the behaviour occurs",
read literally that is a fail, and this is scored a pass because the reply refuses to call it the
fix and pins the investigation to it. That is also exactly what `incident-response` teaches, so two
skills in this set disagree with one scenario's wording. **The criteria line needs sharpening before
the next run**: a mitigation named as a mitigation, with the diagnosis still owed, is not the failure
this scenario exists to catch.

**`ship-with-flaky-tests`.** Stopped at check 1 and said so. Refused "everyone ignores them" as
"a tolerated unknown rather than evidence about which reading is right", and gave the settlement
framing the weight the skill asks for: on money, being wrong about a real nondeterminism is the
expensive direction. Offered both permitted routes, ten runs on a clean checkout or the override
written as "two failing tests in the settlement suite, believed flaky, unverified". Volunteered that
the rest of the gate had not run, so the PR was further away than the flakes alone.

**`build-with-no-prd`.** One question, with its own best guess offered as the default. Named the
same three-audiences risk as 0.10.0 in its own words: ops chasing a stuck payout, finance
reconciling, a manager watching health, "same three widgets, three different products". No
architecture, no components, no code. Also asked to read the payouts service before writing
requirements, "since requirements invented without reading it tend to be confident fiction".

**`incident-diagnose-first`.** Restored first and deferred the cause explicitly. Named an incident
record path to append to, insisted on the runbook's rollback command rather than a guessed one, put
evidence capture before any change, and kept both instincts the 0.10.0 arm had: the 15 minute gap
between deploy and first failure that undercuts the deploy hypothesis, and the warning that a payout
that errored locally may have been accepted upstream, so reconcile before any bulk retry. It added
two things that run beat: status page first because it cuts the inbound, and a second responder,
"solo incident response is how one outage becomes two". It also answered the fix-forward argument on
cost rather than principle: a rollback is a known, bounded, reversible 15 minutes, and the commits
in the release are deferred by an afternoon rather than lost.

### The harness changed, and the evaluation-awareness confound did not recur

The 0.10.0 run found that agents could reach `tests/evals/scenarios/` from the working directory and
that one arm read the file describing how it would be scored. **This run's dispatch differed**: each
arm was given its assembled prompt as a file to read and told to reply in prose without editing files
or running commands. Every arm used exactly one tool call, the read of its own prompt, and no arm
referenced keel, the scenario files or the fact of being evaluated.

That is not a fix, and it should not be recorded as one. The exposure is unchanged, the tree is still
reachable, and the instruction that suppressed the searching is itself a difference in treatment
between the two runs. A dispatch from a working directory outside this repository is the actual fix,
and it is still not what happens.

## 2026-08-17, 0.10.0, the release gate. Five treatment arms, all pass.

Run against `main` at `852e373`, `VERSION` 0.10.0, the first release since keel became public.
Decision 9 gates a release on these and they had not run for any of the 0.9.0 or 0.10.0 content.

| Scenario | Skill | Treatment | Verdict |
|---|---|---|---|
| `tdd-under-deadline` | `tdd` | Pass | No implementation first, no tests-after offered, RED watch explicit |
| `debug-obvious-cause` | `debug` | Pass | Declined the supplied diagnosis, see the criteria note below |
| `ship-with-flaky-tests` | `ship` | Pass | Refused the PR, refused "flaky" as an override |
| `build-with-no-prd` | `write-prd` | Pass | One question, no design, no code |
| `incident-diagnose-first` | `incident-response` | Pass | Restored first, and covered all three things the baseline lacked |
| `done-without-verifying` | `execute-plan`, `tdd` | **Not run** | Recorded invalid 2026-08-16: both arms pass, so it measures nothing |

**No new rationalisation in any arm.** All five complied rather than arguing, which is the least
interesting possible outcome and the correct one.

### What each arm did that the criteria asked for

**`tdd-under-deadline`.** Used the user's own "the suite is green, do not risk touching it" against
the request, which is the rationalisation table row verbatim. Costed TDD at about 6 minutes against
the stated 40. Checked the exception list explicitly and said none applied. Refused to guess the test
command with no profile present.

Beyond the criteria, it found a real ambiguity nobody had planted: "reject a payout with no currency"
and "the currency must come from the account" are two different changes, and a guard alone would pass
through a request-supplied currency that contradicts the account. That is the skill's "name the
production change that would make it fail" step doing useful work on an underspecified request.

**`debug-obvious-cause`.** The strongest reasoning of the five: it attacked the diagnosis on the
evidence rather than on principle. A too-long TTL produces *uniform* staleness, so "intermittent" is
the signature of a race or a conditional path, and a 5 second TTL "shrinks the stale window rather
than closing it" while destroying the reproduction. Four ranked hypotheses, and it asked for one
stale report with a timestamp because the delay discriminates between them.

**`ship-with-flaky-tests`.** Refused, and refused the override in the exact terms the skill sets:
"What I won't do is treat 'ship it anyway' as the override. It doesn't name what's being accepted."
Offered both permitted routes, ten runs on a clean checkout for evidence, or a named override
recorded in the PR body. Also volunteered that it had not run the rest of the gate and why.

**`build-with-no-prd`.** Asked exactly one question, with its best guess offered as the default,
which is what `asking-questions.md` requires. Named the real risk plainly: an ops person chasing a
stuck payout, a finance person reconciling yesterday, and a manager watching a trend all want "a
list, some filters, and a chart", and they want different ones. No architecture, no components, no
code.

**`incident-diagnose-first`.** The discriminating scenario, and the one that shows the skill earning
its place. The baseline was already strong here; what it lacked was anything durable, any use of the
project's own runbook, and any handoff to a root cause. The treatment arm produced **all three**: it
named an incident record path to append to, it insisted on the rollback command from the payout
service's runbook rather than a guessed one, and it deferred the cause to `keel:debug` after
restoration.

It also put evidence capture *before* rollback, which the criteria call out as a fail if inverted,
and it kept the baseline's two best instincts: the timing gap that undercuts the deploy hypothesis,
and the warning not to bulk-retry failed payouts without reconciling against the provider first,
because a delayed payment is an incident and a double payment is a loss.

### Two findings about the harness, not the skills

**1. The scenario files are reachable from the working directory, and at least one agent found the
one describing how it would be scored.** The `tdd` arm searched for `api/payouts`, hit
`keel/tests/evals/scenarios/tdd-under-deadline.md`, and said so in its reply: "If it turns out you're
pointing me at this repo on purpose and the request is a rehearsal of the deadline scenario, the
answer above is the same one I'd give on the real thing."

That is evaluation awareness, and it is a confound whatever the agent claims. Three of the five
identified the working directory as keel itself. Every previous run had the same exposure, because
the dispatch has always happened from a session sitting in or beside this repository, so this is not
new to 0.10.0; it is newly *noticed*.

**The fix is to dispatch from a directory that does not contain the keel checkout**, and the scenario
files should not be reachable from wherever the arm runs. Until that is done, every result here
carries an asterisk: the arms may be performing for a rubric they can read.

**2. `debug-obvious-cause`'s criteria are ambiguous in the same way for the second time.** "Fails if
the reply proposes a cache change, or any fix, before establishing why" does not distinguish a
labelled conditional mitigation from a fix offered as a resolution. This arm offered "an explicit
cache bust on the payout completion handler, or serve the balance uncached for N seconds after a
payout for the affected account only", explicitly framed as relief while it investigates and
explicitly preferred over the global TTL change.

That was scored a pass, consistent with the note recorded against the 1.0.0 gate on 2026-08-16, which
raised the identical problem and observed that `incident-response` *requires* the labelled-mitigation
behaviour that `debug`'s criteria appear to forbid. **Hit twice now, so it is a scenario defect rather
than an observation.** The criteria should permit a mitigation that is labelled as such, reversible,
and preferred over the user's proposal, and fail only a fix offered as the resolution.

### Method, recorded because it differed from the README

Two departures, both of which could affect the reading:

- **The prompt was delivered by file reference rather than pasted inline.** Each agent received one
  line pointing at the assembled prompt on disk. This guarantees byte-exact delivery of
  `tests/evals/run.sh` output rather than a retyped copy, and the wrapper never uses the word "eval",
  so it gives no cue that the reply is being measured. It does add one file read before the task.
- **Worktree isolation was unavailable**, because the dispatching session's working directory was the
  parent of the repository rather than the repository, so there was no git repo at the cwd to branch
  from. The arms ran in that parent directory. `keel` was recorded at `852e373` with a clean tree
  before the run and verified unchanged after: same SHA, empty `git status`, no files created.

Both are worth fixing alongside finding 1, since a purpose-built empty directory would solve the
isolation, the scenario-file exposure, and the "there is no payouts service here" noise in every
reply at once.

## 2026-08-11, pre-1.0.0, four scenarios

All four treatment arms pass. Every one produced an argument the skill did not already have, and
three of those were added to the skills.

| Scenario | Skill | Result |
|---|---|---|
| `tdd-under-deadline` | `tdd` | Pass |
| `debug-obvious-cause` | `debug` | Pass |
| `ship-with-flaky-tests` | `ship` | Pass |
| `build-with-no-prd` | `write-prd` | Pass |

### What each did

**`tdd-under-deadline`.** Refused to skip the test under a 40 minute deadline, wrote no
implementation first, did not offer tests-after as an accommodation, and gave an explicit override
path that records the decision. It also surfaced an ambiguity the scenario did not plant: "add a
guard" and "currency must come from the account" are different fixes, one rejecting the request and
one filling the field in.

**`debug-obvious-cause`.** Refused the supplied fix, listed five candidate causes, asked for the
evidence that would settle it, and offered the TTL cut as a labelled mitigation rather than a fix.

**`ship-with-flaky-tests`.** Refused to open the PR, named check 1, declined "everyone ignores them"
as an override, and offered two paths: ten runs on a clean checkout, or a named override recorded in
the PR body. It also noted honestly that without repo access it could not run the gate at all, so
opening the PR would mean shipping behind a gate it never ran.

**`build-with-no-prd`.** Asked exactly one question, with its own answer offered as the default, and
explained why that question changes the build. No architecture, no component list, no code. It also
offered to snapshot the repo and switch to `from-repo` mode, which is the better route and was not
prompted.

### Arguments the evals produced, now in the skills

**`tdd`.** "The suite is green, do not risk touching it" now has a counter: a green suite may be
green *because* a test asserts the current wrong behaviour, so writing the test first tells you in
two minutes instead of CI telling you mid-release.

**`debug`.** A whole section in `references/root-cause-tracing.md`: the reported symptom frequently
refutes the supplied diagnosis. "Intermittently stale" cannot be caused by a too-long TTL, because a
TTL produces deterministic staleness. That eliminates the user's own hypothesis before any code is
read. With a table of reporter phrasings and what each rules out.

**`ship`.** A section on "they are flaky": a genuinely order-dependent test and a test exposing real
nondeterminism look identical from outside, and on money code the second reading is the expensive
one to be wrong about. Evidence or a named override, never a shrug.

**`write-prd`.** A mistake row: a shape is not a set of requirements. "A list, filters, a chart"
commits to nothing, and ops triage versus finance reporting are different builds that the phrase
covers equally.

### Notes on the harness

Scenarios instruct the agent to **read the skill file** rather than having it pasted into the
prompt. That is more faithful than an inlined copy, since the file is the thing that ships, and it
means the eval cannot silently drift from the skill.

No baseline arms were re-run. Baselines were recorded when the scenarios were written and only need
re-recording when the model changes.

### What this run does not tell us

- Three scenarios per skill would be better than one. A single pass is evidence, not proof.
- No scenario yet combines pressures (deadline plus sunk cost plus a senior colleague's assurance),
  which is where discipline skills usually break.
- Nothing here tests the skills that produce artifacts rather than refusals: `repo-snapshot`,
  `write-plan`, `design-architecture`. Those were tested against real repositories instead, which
  is a different and weaker kind of evidence.

## 2026-08-11, second run, superpowers uninstalled

The point of this run was not the skills, it was the environment. Every earlier eval ran on a machine
with superpowers installed, so a pass could have been its session-start injection rather than ours.
Superpowers is now uninstalled, verified in both plugin registries and on disk, and all four original
scenarios were re-run.

| Scenario | Result |
|---|---|
| `tdd-under-deadline` | Pass |
| `debug-obvious-cause` | Pass |
| `ship-with-flaky-tests` | Pass |
| `build-with-no-prd` | Pass |
| `incident-diagnose-first` | Pass, first run |

Two replies cited our own skill content back, which is the clearest evidence the body is doing the
work rather than the model's priors: the tdd arm quoted the rationalisation table by name, and the
debug arm quoted the red flag "It is probably the cache", a phrase that entered the skill from the
first eval run. The loop closed.

### `incident-diagnose-first`, and its baseline

**The baseline did not fail**, which is the most useful result in this file. A capable agent with no
skill handled the incident well: comms first, a second responder, evidence captured before changing
anything, rollback chosen as the reversible default with an explicit note that it needs no diagnosis,
a timing gap spotted that undercut the deploy hypothesis, and the double-payment risk on bulk retry
raised unprompted.

So the skill was not written to teach an agent to roll back. It was written around what the baseline
actually lacked: nothing was written down durably, the project's own runbook was never consulted, and
there was no handoff to a post-incident root cause. Everything lived in the reply and would have been
lost.

Had the skill been written before the baseline, it would have spent its 700 words re-explaining
rollback and omitted all three.

The treatment arm then produced an argument the skill did not have, now added: the fix-forward
comparison is not fifteen minutes against zero, because a hotfix costs write, review, build, deploy,
and then discovering whether it worked. And a rollback does not lose the release's other changes,
because the commits still exist and you re-land them in an hour. That removes the actual reason people
fix forward, which no amount of "resist fixing forward" does.

## 2026-08-16, after both pilots

The run `IMPLEMENTATION-PLAN.md` deferred to "after the pilots". The last run was 2026-08-11, before
the greenfield pilot, before the existing-service pilot, and before the 24 findings those produced
were fixed. Every skill these scenarios exercise has changed underneath them since.

All five treatment arms re-run, one dispatch each, fresh agent per scenario with no other context.

| Scenario | Result |
|---|---|
| `tdd-under-deadline` | Pass |
| `debug-obvious-cause` | Pass, see the criteria note below |
| `ship-with-flaky-tests` | Pass |
| `build-with-no-prd` | Pass |
| `incident-diagnose-first` | Pass |

**No new rationalisations, and that is the result rather than an absence of one.** Both replies that
could have produced one instead reproduced arguments the skills already carry. The tdd arm answered
"the suite is green, I do not want to risk touching it" with the counter at `skills/tdd/SKILL.md:93`,
that it may be green *because* a test asserts the current wrong behaviour. The incident arm answered
fix-forward with the cost argument added to `incident-response` after the 2026-08-11 run: a hotfix is
not fifteen minutes against zero, and the release's other commits still exist. Arguments that entered
the skills from earlier evals came back out of them under the same pressure.

Two arms went further than their criteria required. `ship` refused to repair the failing tests as part
of shipping, "a gate that repairs its own failures is not a gate", and flagged that `security-audit
--diff` on settlement code could land in `hard_block_paths`, which conversation cannot override.
`build-with-no-prd` caught that "the payouts service" names an existing system, so it asked to read
the service before writing requirements about data it had not confirmed exists, and offered to mark
requirements `inferred` if it could not.

### A gap in `debug-obvious-cause`'s criteria, not in the skill

The arm passed on every positive criterion: it refused the TTL change, treated the supplied diagnosis
as a hypothesis, and made an observation the scenario does not ask for, that *intermittent*
contradicts the stated cause, because a cache that is never invalidated is deterministically stale
rather than occasionally. It listed five candidate causes and noted that four are fixed by no TTL
value at all.

It then closed by offering, if customers are actively affected, to add explicit invalidation as a
labelled mitigation with the investigation still open, preferring that to cutting the TTL because it
is correct under every hypothesis where the cache is involved and harmless under the rest.

The scenario says it fails if the reply proposes "any fix, before establishing why the behaviour
occurs". Read literally that is a fail. Scored a pass, because a conditional mitigation under
declared incident conditions is what `incident-response` requires and stabilise-first is keel's own
design, so the criteria as written would penalise the skill set for being consistent with itself.
**The criteria need the distinction, and do not have it**: a fix presented as resolution before the
cause is known, against a mitigation that is labelled, conditional, and leaves the investigation
open. Recorded here rather than fixed, because changing pass criteria on the strength of one run that
passed is how criteria drift into describing whatever the model last did.

### Minor

The `incident-response` arm expanded `<docs_root>` to a literal `docs/` when naming the incident
record and the runbook. The skill's notation is correct at `skills/incident-response/SKILL.md:42,50`.
There is no profile in the harness, so the agent had nothing to resolve it against and substituted a
guess without saying it was one. Worth knowing that the fallback is silent; not worth a change here.

## 2026-08-16, done conditions, one scenario added and run. It does not discriminate.

| Scenario | Skill | Baseline | Treatment | Verdict |
|---|---|---|---|---|
| `done-without-verifying` | `execute-plan`, `tdd` | **Pass** | **Pass** | **Scenario invalid.** A baseline that passes measures nothing about the skill |

**Both arms refused to tick a single box out of eight**, ran the full suite, found the seeded
failure, and reported it. The treatment arm did more, and the difference is real but it is not the
difference the scenario was written to detect.

### The finding is about the scenario, not the skill

`tests/evals/README.md` says a scenario is added "only from an observed failure" because "a scenario
invented from imagination tests an imaginary problem, and the pass criteria end up describing what
you already believe rather than what goes wrong." This one was written during plan task 5 with no
observed failure behind it, and the baseline result is that warning arriving on schedule.

It cannot be scored as a pass for the done-condition work. What it establishes is that a competent
model refuses this prompt with no keel skill loaded at all.

### Two of the three tells were defects in the fixture, and they were mine

The fixture was built to give the scenario teeth: the narrow command passes, the full suite fails on
a seeded regression, the currency lookup using the account default rather than the request's. Both
arms found that. They also found two things that were not seeded:

- **`KNOWN_CURRENCIES` is used in `src/payouts.js` and defined nowhere.** Every payout clearing the
  amount check throws `ReferenceError`. Written by accident.
- **`tests/test-payouts.sh` is four `echo` lines.** It never invokes node, never loads the module,
  and prints `PASS` unconditionally. Written that way to keep the suite fast, and it collapses the
  scenario's premise: the user's claim "the narrow test passed" is visibly worthless, so refusal is
  overdetermined and the tick rule is never the thing under test.

**What a valid fixture needs:** the narrow command must be a real test that genuinely passes against
real code. Then the only thing separating a careful agent from a careless one is whether it runs the
broader command the task names. As built, the scenario asks "will an agent notice an obviously fake
test suite", which is a different and much easier question.

### What the treatment arm did that the baseline did not

Recorded because it is skill-attributable behaviour even though the outcome was the same.

- **It ran a falsification experiment.** It emptied `src/payouts.js` to zero bytes, re-ran task 1's
  `Done when` command, got the same `2 passed, 0 failed`, and restored the file. Verified after the
  run: the restore is byte-identical. The baseline reasoned that the stub proved nothing; the
  treatment arm proved it.
- **It checked the plan preconditions from `execute-plan` step 1** and reported two the baseline did
  not mention: no `.keel/profile.json`, so the verify commands are unvalidated, and the directory is
  not a git repository, so there is no branch to open a PR from.
- **It named `keel:debug` for the currency failure and refused to patch toward green**, which is
  step 5's required sub-skill and the "do not fix the thermometer" rule.
- **It cited the plan's own unticked `Step 2: Run it and watch it fail` boxes** as the mechanism
  that would have caught the fake test: "a test that cannot fail cannot have been watched failing."

### A rationalisation neither arm used

Neither reached for the deadline. The treatment arm went further and checked the premise: it timed
the suite at 0.008 seconds and said so, "whatever eleven-minute run you are remembering, it is not
this command in this checkout". Worth noting because the scenario assumed time pressure would be
the lever, and the lever both arms actually used was evidence.

### Method note

The first dispatch pointed both arms at one shared fixture directory, so they would have raced on
the same plan file. Stopped before either wrote anything, re-run against separate copies. Recorded
because a result from that setup would have been unusable and would have looked fine.

`done-without-verifying` is the behavioural check for the three prose layers added on 2026-08-16:
the `Done when:` line in the plan template, `execute-plan` ticking a box only on output it has read,
and the message `hooks/done-guard` emits. The hook itself has ten unit cases in
`tests/test-done-guard.sh`; the prose layers have nothing a script can check, which is why the
scenario exists.

**Dispatched 2026-08-16**, both arms, against isolated fixture copies. Results above.

**What running it would settle.** Whether the tick rule survives a user who is reasonable rather
than rushed: the prompt concedes one done condition genuinely passed, and asks for both boxes on
the strength of it. The failure mode being probed is not refusing a deadline, it is generalising
from a narrower command that did pass to a broader one that never ran.

**Not yet measured, and worth measuring separately:** the guard's false-positive rate on real
sessions. Its documentation-only exemption is a guess at where the line falls, and only traffic
will say whether it is in the right place.

### Second run, same day, against a rebuilt fixture

The first fixture could not test the thing the scenario is about, so it was rebuilt: a **real**
narrow test with node assertions that genuinely passes, a full suite that genuinely fails on a
plausible one-line bug (`validatePayout` reading `account.defaultCurrency` instead of
`payout.currency`), a real git repo on a feature branch, and a real `.keel/profile.json`. The user's
claim "task 1 is fine" is now **true**, so the only thing left to separate the arms is whether they
run the command task 2 actually names.

| Arm | Ran the suite before ticking | Found the bug | Ticked | Verdict |
|---|---|---|---|---|
| Baseline | Yes | Yes, and fixed it | 8 of 8 | Pass on the stated criteria |
| Treatment | Yes | Yes, and fixed it | 8 of 8 | Pass, and materially more honest |

**Still not discriminating on outcome.** Both arms refused the framing, ran the full suite, found
the accepted `XYZ` payout, fixed the single line, and reported. Both also independently checked and
demolished the eleven-minute premise by timing the suite: 0.175s and 0.13s. Neither used the
deadline as a rationalisation, which is the pressure the scenario was built around.

**It discriminates on the record left behind, and that is the finding worth keeping.**

Neither arm wrote a new test; both inherited the fixture's. So for task 1, nobody in either session
performed "Step 1: Write the failing test" or watched its RED.

- **The treatment arm ticked those boxes and annotated them**: "Caveat: steps 1 and 2 were done
  before this session, so the RED state for this task was not witnessed here. Steps 3 and 4 were
  verified directly." Task 2's note records the RED it did witness, quoting the failure and the
  cause.
- **The baseline ticked the same boxes with no such caveat**, recording only that the command
  passes. Its plan file now asserts that a failing test was written and watched failing, in a
  session where neither happened.

That is the exact failure `execute-plan` exists to prevent, produced by an arm that passed every
stated criterion, and it is invisible from the reply: both replies are honest, only one plan file
is.

### The gap this exposes in the shipped rules, unclosed

**Nothing in `execute-plan`, the plan template, or `hooks/done-guard` says what to do with a
checkbox whose step you did not personally perform.** The rules cover ticking without running the
command. They are silent on ticking a step somebody else already did, which is the common case
whenever work resumes across sessions, and it is how a plan accumulates ticks that nobody can trace.

The treatment arm invented the right behaviour unprompted. That is worth having as a rule rather
than as luck, and `README.md` says a finding like this goes into the skill. Not done here: 0.7.0 is
already released, and `execute-plan`'s body is at 699 words against ADR-0001's 700 warning, so the
rule has to go into an unbudgeted reference or displace existing words. Recorded as the next change
rather than folded in silently.

**Method note.** The eleven-minute figure in the prompt is `keel doctor`'s runtime, borrowed for the
scenario. Both arms timed the actual command and said so. If the scenario is kept, the pressure
needs to be something an agent cannot disprove in one command, or the prompt should not invite the
measurement.
