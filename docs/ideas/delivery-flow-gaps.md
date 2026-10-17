# Idea: keel's delivery flow against a clean-slate design that keeps TDD and shortens turnaround

| | |
|---|---|
| Raised by | Bernard, 2026-10-16: "Assume keel's history didn't exist ... how would you have approached my current concerns. TDD is important but how do we keep it while still optimizing TAT of implementation", then asked for the comparison against keel |
| Status | open questions decided by Bernard 2026-10-16 (see "Decided"). Gap 7 is built by `docs/plans/2026-10-16-measure-delivery-and-implementer-model.md`: commits `e5dd976` and `c93dcda` (`keel plan report`), `a774c2f` (`keel-implementer`), `10afbeb` (routing recorded per task) and the commit titled `feat(skills): rework names its feature, and ship reports delivery`. Gap 5 is built by `docs/plans/2026-10-16-proportional-review-loop.md`: commits `997b2be` (`keel plan risk`), `1e47780` (`execute-plan` reviews in proportion to what a task touches) and the commit titled `feat(skills): the final review stops after one fix pass`. Gap 1 is built by `docs/plans/2026-10-16-plans-name-behaviours.md`: commits `5b8c887` (`write-plan` asks for behaviours with examples, not code) and the commit titled `feat(skills): execution and review build on a task's behaviours`. Gap 4 is built for planned work by `docs/plans/2026-10-16-deliver-to-a-pull-request.md`: commits `592ebf1` (`execute-plan` and `review-code` continue past their reports when the plan says so) and the commit titled `feat(skills): delivery to a pull request is chosen when the plan is approved`. Gap 4's short path is built by `docs/plans/2026-10-17-the-short-path.md`: commit `8ce8535` (`write-plan` runs a short path for small work) and the commit titled `feat(skills): the router sends small work down the short path`. The short path writes a one-task plan, so it joins `tdd`, `review-code` and `ship` for work with no PRD through `execute-plan`'s existing delivery, and gap 4 is built in full. Gap 2 is built by `docs/plans/2026-10-16-manage-test-speed.md`: commits `5e6fd9b` (`keel doctor` names a slow suite as a cost, and `verify.test_affected` is declared, ADR-0009) and the commit titled `feat(skills): the tdd unit boundary runs the affected tests when the profile names them`. Gap 6 is built by `docs/plans/2026-10-16-plans-declare-batches.md`: commits `807fceb` (`keel plan batches`) and `fda63ab` (feature flags merge unfinished work dark), run as a real batch and joined in `a3d49b2` and `8ed7430`, then `46f750f` (the batch's records) and the commit titled `feat(skills): plans declare every batch keel plan batches prints`. Gap 3 is built by `docs/plans/2026-10-17-sensitive-paths-get-mutation-evidence.md`: commits `8707650` (`review-code` mutates every changed decision line on a sensitive path) and `1be82ec` (the audit reads its sensitive-path match from `keel plan risk`), run as a real batch and joined in `d6d2c1d` and `1bfa92d`, then the commit titled `docs: records for gap 3, sensitive paths get mutation evidence`. Every gap in the decided order is now built |
| Recommendation | Keep `tdd` as it is. Close the gaps around it, starting with measurement and the number of review passes, which is where the one measured case spent its time |
| Next | What remains is the eval arms the edited skill bodies owe under ADR-0001, and measuring the changes with `keel plan report` on real work. [proportional-ceremony.md](proportional-ceremony.md) is gaps 5 and 1 in an earlier, narrower form and is closed |

## The clean-slate design

Written without reference to keel, then compared with it. Its premise: with a model writing the
code, test-first costs little typing and a lot of waiting, so keep test-first strict and design the
waiting out.

1. **The behaviour list is the plan.** Planning produces examples ("a net payout of 1000 at 3% is
   970"), approved by a human in minutes. Tests are written from it, watched red, then made green.
2. **Tests are fast.** One test runs in seconds, the cycle runs the tests a change affects, and the
   full suite runs once at the end and in CI. A slow suite is a defect.
3. **Depth follows risk, decided mechanically.** Every behaviour has a test. Money movement, auth
   and personal data add boundary cases, property or mutation evidence and a security audit. A path
   list, matched against the diff, decides; the model does not.
4. **Two human checkpoints.** Approve the behaviour list; approve the pull request. Nothing between
   waits on a human unless it is blocked.
5. **One bounded review.** Machines check what machines can. One reviewer judges intent, design and
   safety. Only a blocking finding sends work back, once; a second block goes to the human. The rest
   becomes a follow-up list.
6. **Overlap, not queue.** Independent behaviours build in parallel, review of one overlaps building
   the next, and release is decoupled from deploy by flags.
7. **Measure lead time and rework together.** Per feature, request to merge, and whether it came
   back as a defect.

## The gaps

Each row names what keel does now, with its source, and how far it is from the design.

### Gap 1: the plan is a second copy of the code (large)

**Built 2026-10-16**, see Status. What follows is the state before it was built.

`write-plan` needs stories, and stories need a PRD (`skills/write-plan/SKILL.md` step 1). Each task
then carries its test and its implementation verbatim
(`skills/write-plan/references/plan-template.md`, steps 3.1 and 3.3 of the example), a reviewer is
dispatched over the plan (step 5), and `execute-plan`'s implementer writes the same code again. The
behaviour list already exists one level up: stories carry Gherkin acceptance criteria
(`skills/write-user-stories/references/`, "Scenario: currency matches the account").

**Change:** a task names its behaviours with example values, the files, and its `Done when:`; the
implementer writes the tests and the code under `tdd`. Verbatim code in a plan becomes optional, for
an interface another task consumes. **Risk:** plan precision is what stops an implementer drifting;
the spec review, which judges against the task, is what would carry that instead.

### Gap 2: test speed is reported, not managed (medium)

**Built 2026-10-16**, see Status. What follows is the state before it was built.

`keel doctor` times each verify command and prints the seconds (`bin/keel`, the `verify.$k runs`
line), with no threshold. `tdd` already runs `verify.test_one` per case and the suite once at the
unit boundary (ADR-0006). Nothing runs only the affected tests, and nothing calls a slow suite a
problem.

**Change:** `doctor` warns when `verify.test` passes a threshold or `verify.test_one` is null, and
names that as the cost of every cycle. An optional `verify.test_affected` for stacks that have one.

### Gap 3: risk depth is half there (small)

**Built 2026-10-17**, see Status. What follows is the state before it was built.

`hard_block_paths` is the mechanical list, and `hooks/sensitive-guard` asks a human before a commit
touching it, which a sentence in chat cannot satisfy. `gates.security_audit` sets the audit's force
in `ship`. Mutation is a technique in `skills/tdd/references/writing-good-tests.md`, not tied to
those paths. [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) rejected
*lightening* the cycle off those paths; it says nothing against *deepening* it on them, and the
laundering risk it names does not arise when the list only adds work.

**Change:** a diff touching `hard_block_paths` needs mutation evidence in `review-code`, and the
audit is required there whatever `gates.security_audit` says.

### Gap 4: six hand-offs instead of two checkpoints (large)

**Built 2026-10-16 for planned work, and the short path built 2026-10-17**, see Status. What follows
is the state before either was built, so "goes straight to `tdd`" below is the router before the
short path.

Eight skills end by naming the next one and saying not to start it: `write-prd`,
`write-user-stories`, `design-architecture`, `write-plan`, `execute-plan`, `review-code`,
`repo-snapshot` and `apex-export` (grep "Do not start" in `skills/*/SKILL.md`). On the delivery
path that is six points where a feature waits for a person to say go. The router already has a
short path: "implement X, add feature Y" goes straight to `tdd` (`skills/keel/SKILL.md`), but
nothing joins `tdd`, `review-code` and `ship` into one run.

**Change:** a delivery path that, once the behaviour list is approved, runs build, review and `ship`
to an open pull request without stopping, except on a blocker, a blocking finding the loop cannot
clear, or `sensitive-guard`'s ask. The long chain stays for work that needs a PRD.

### Gap 5: review volume and the loop (largest)

**Built 2026-10-16**, see Status. What follows is the state before it was built.

A three-task feature through the full chain gets a plan reviewer (`write-plan` step 5), a spec and a
quality pass per task (`skills/execute-plan/references/subagent-prompts.md`), then `review-code`'s
`/code-review` plugin and its own rubric pass (`skills/review-code/SKILL.md` steps 2 and 3), then
`security-audit --diff` in `ship`. That is ten review dispatches before any rework. A blocking
finding discards the attempt and re-dispatches from scratch; nothing caps the rounds. The one
measured case, `4ee1a35` on 2026-10-14, spent most of its time here, not in the test cycle.

**Change:** per task, one spec pass against the behaviour list; at the end, one `review-code`; a
blocking finding gets one fix pass, and a second goes to the human; should fix and consider become a
follow-up list. `hard_block_paths` diffs keep the full set. ADR-0002 governs delegation and the
coordinator writing no code, not the number of passes, so this needs no ADR change.

### Gap 6: queue, not overlap (medium)

**Built 2026-10-16**, see Status. What follows is the state before it was built.

Concurrent batches exist but only where the plan declares them and five conditions hold
(`skills/execute-plan/references/parallel-batches.md`). Otherwise "never the next while the previous
is unreviewed" (`skills/execute-plan/SKILL.md` step 3), whose reason is that task N+1 may have built
on task N. Feature flags appear only as a rollback lever (`skills/incident-response/SKILL.md`,
`skills/coding-standards/references/house-defaults.md`), never as a way to release separately from
deploying.

**Change:** a task whose `Depends on:` is `none` may start while the previous is in review, since
the stated reason does not apply to it. `setup-deployment` and `ship` name flags as the way to merge
unfinished work dark.

### Gap 7: nothing is measured (large, cheap)

**Built 2026-10-16**, see Status. What follows is the state before it was built.

No skill or command records how long a feature took or whether it came back. `keel plan tick` writes
no timestamp. ADR-0007's reopening condition 1 asks for a measured cost, and keel cannot produce
one.

**Change:** ticks are timed by their commits rather than stamped: a tick is committed with its task,
so the commit's author time is the stamp, and `keel plan report` reads it. `ship` puts that report
in the pull request; a `debug` run names the feature it fixes with a `Reworks <plan path>` line in
the fix's commit body, which is rework. Two numbers per plan: lead time and a rework count; a share
of features that came back is taken across plans, from many reports.

## What stays

`tdd` keeps the iron law, the start record, the behavioural unit, the watched red and the boundary
run through every gap above, as do `hooks/sensitive-guard`, the coordinator writing no code, and
ADR-0007. The boundary may now run the affected tests, with the start record's reds carried forward
(gap 2, ADR-0009).

## Decided

Bernard, 2026-10-16, choosing among options put to him:

1. **Order: 7, 5, 1, 4, 2, 6, 3.** Measurement first, so every later change can be judged against
   lead time and rework rather than by feel.
2. **Gap 1: behaviours only.** A plan task names its behaviours with example values, its files and
   its `Done when:`. Verbatim code stays only for an interface another task consumes. The precision
   question is answered by the spec pass, and gap 7's numbers are how to tell if that was wrong.
3. **Gap 4: yes, the pull request is the gate.** Once the behaviour list is approved, keel runs
   build, review and `ship` to an open pull request without stopping, except on a blocker, a second
   blocking finding, or `sensitive-guard`'s ask.
4. **Gap 5: one spec pass per task and one final review.** Outside `hard_block_paths`, each task
   gets one spec pass against the behaviour list and the feature gets one `review-code` before
   `ship`. A blocking finding gets one fix pass, and a second goes to Bernard. `hard_block_paths`
   diffs keep the full set. The finding of 2026-10-14, that the two per-task passes found different
   problems in every round, is the risk taken; gap 7's rework number is how to see whether it bites.
5. **Gap 2: warn at 60 seconds, and let the unit boundary run the affected tests.** `doctor` warns
   when `verify.test` takes longer than 60 seconds, and the profile can override the number.
   `verify.test_affected` replaces the suite at the `tdd` unit boundary when it is set, with the
   full suite still in `review-code`, `ship` and CI, under a new ADR, ADR-0009. It is set by hand
   only: `keel init` detects no runner.
6. **Gap 6: plans declare batches by default.** Not a runtime pipeline in `execute-plan`:
   `write-plan` runs `keel plan batches` and declares every batch it prints, so the approver sees
   the overlap. Feature flags are named in references, with one line in `ship`. A batch's shared
   records go in a records task after the batch, and the standard's "same commit" becomes "same pull
   request, and for a batch the records task at its join". The plan that built it ran its tasks 1
   and 2 as a real batch.
7. **Gap 3: the reviewer mutates, and one command decides the match.** The mutation evidence
   comes from the independent reviewer in `review-code`, not the author in `tdd`. Every changed
   decision line in a sensitive file gets one mutant, capped at 10 per review, and a survivor
   blocks. `review-code`, `security-audit` and `ship` decide the match with
   `keel plan risk --range <merge-base>..HEAD`. The audit half of the gap was already met: under
   any value of `gates.security_audit`, `ship` audits a diff touching `hard_block_paths`, and a
   finding on such a path blocks and cannot be overridden in conversation (see the plan's "What
   this plan does not build"). The plan changed only how the match is decided.
8. **Gap 4's short path: a one-task plan, written for the person.** Bernard,
   2026-10-17, choosing among options put to him: the record is a one-task plan that `write-plan`
   writes and `execute-plan`'s delivery runs, so nothing downstream changes. It takes at most 5
   behaviours and no `hard_block_paths` change, decided by `keel plan risk` on the files the
   behaviours name, and offers the full form otherwise, with the reason. Approval asks each time,
   with delivery to a pull request first and hand-off the other option. After the plan review: on
   the default branch the approval question names a new branch and the short path creates it, that
   answer being the consent; and `write-plan`'s description claims small changes while `tdd`'s
   defers them to the short path, so a session that picks by description reaches it. The router
   sends "implement X" to the short path and keeps "just write the code for X, no PR" on `tdd`.

## Not decided here

- How long after delivery a fix still counts as rework.
- Whether gaps 1 and 4 together make `write-plan` optional for a feature with stories, or replace
  it.
- How [proportional-ceremony.md](proportional-ceremony.md) closes: folded into gap 5 when gap 5 is
  planned.
