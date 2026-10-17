# The short path

Read at `write-plan` step 1 when no stories exist and the work is small. It writes the same
one-task plan the [template](plan-template.md) defines, from a behaviour list the person approves,
and runs it through `execute-plan`'s existing delivery.

**Why it exists:** the long chain (PRD, stories, plan, reviewer, hand-offs) is sized for work that
needs a requirement written down. For a small change the behaviour list with its examples is the
requirement, and the person approving it is the check a PRD would give, so asking for the chain
first costs six hand-offs for a change one question can settle.

## When it applies

The short path is for small work with no stories: work the person can describe as at most 5
behaviours with examples, on a project whose profile has `verify.test` and `verify.test_one`.

- **At most 5 behaviours**, because past that the work is no longer small and earns the plan
  reviewer, which this path does not run.
- **The profile has `verify.test` and `verify.test_one`**, because the plan's `Done when:` and its
  steps read them from `.keel/profile.json`, and a plan whose commands are `null` cannot be verified
  as written.
- **No PRD or stories are needed**, because the behaviour list is the requirement and the person
  approves it.

## The steps, in order

1. **Read, then write the behaviour list.** Read the code the request touches, `.keel/profile.json`,
   `<docs_root>/standards.md` and the decisions (`artifacts.decisions`, else
   `<docs_root>/decisions/`), so the plan's `**ADRs:**` line names those that govern the change.
   Then write each behaviour with example values and the files it would touch, as root-relative file
   paths, never directories. Reading first keeps the behaviours about code that exists. Paths,
   because `keel plan risk` reads file names and a directory hides which file in it changes;
   root-relative, because `keel` reads every path as named from the root, so a path spelled from a
   subdirectory reads as `loop: light` and nothing flags it.

2. **Check scope against the three limits and name the one hit:**
   - more than 5 behaviours;
   - `verify.test` or `verify.test_one` missing from the profile;
   - `keel plan risk <the named files>` printing `loop: full`, exiting other than 0, or no `keel`
     to run. Each is read as sensitive, because failing to decide is never a reason to review less.

   On any of them, offer the full chain from `write-user-stories` (it routes to `write-prd` where no
   PRD exists; there the change enters `write-prd`'s gate, because the short path refused it), and
   say which limit was hit, because big or sensitive work earns the plan reviewer and the full loop.

   **Say that the check is a forecast:** `keel plan risk --staged` at execution still decides the
   review loop, so a build that touches a sensitive file nobody named gets the full loop. The files
   named here are a guess made before the build, and the staged files are what changed.

3. **Write a one-task plan** where `write-plan` step 3 says plans go (`profile.artifacts.plans` if
   set, otherwise `<docs_root>/plans/`, as `YYYY-MM-DD-<slug>.md`), in the template's shape, so
   `execute-plan`, `keel plan status` and `keel plan report` read it unchanged:
   - The header is the template's, with `**Stories:** none, short path: behaviours approved by
     <person>, <date>`, `**ADRs:**` from the decisions step 1 read (`none` when none govern the
     change), then `**Implementer routing:**` and `**Delivery:**`. The Stories, routing and delivery
     lines are filled when the person answers (step 5), and nothing else is left open.
   - **Global constraints** copied in full from the profile and `<docs_root>/standards.md`, as the
     template says, because a task is read by someone who sees nothing else. They include this
     line, in bold: **Delegated mode only: do not run inline, because the spec pass is this plan's
     only per-task review and no plan reviewer ran.**
   - One task, with its `**Files:**`, `**Depends on:** none`, `**Behaviours:**` and
     `**Done when:**`, and its steps. The `Done when:` is the profile's `test_one` command and its
     passing result, scoped to the task's own test as the template requires. The steps are the
     template's five, `Step 1.1` to `Step 1.5`, the last staging the named paths and stopping, with
     the commit the coordinator will make after both review passes.
   - Each behaviour carries an example, such as "a refund larger than the payment is refused with
     `refund_exceeds_payment`", with the values: refunding 1500 on a payment of 1000 gives
     `refund_exceeds_payment`.

4. **Run the template's mechanical self-review items.** No placeholders other than the three header
   lines step 5 fills (`**Stories:**`, `**Implementer routing:**` and `**Delivery:**`), commands
   from the profile, `keel plan status <plan>` exits 0, and every behaviour has an example. They
   cost nothing and catch what a reviewer would.

5. **Ask one question** carrying the behaviours, the routing and the delivery choice, following
   [asking-questions.md](../../keel/references/asking-questions.md), with "deliver to a pull
   request" first and "hand off" second, for example "Approve these 3 behaviours, implement on
   keel-implementer, deliver to a pull request". The pull request is first because it is the path's
   purpose: the person approved a list small enough to review once, and the gates after it are
   `review-code` and `ship`. **On the default branch** the question also names a new branch, for
   example "... on new branch `feat/<slug>`", and on approval the short path creates it
   (`git switch -c feat/<slug>`) before committing, because that answer is the consent
   `execute-plan`'s precondition asks for. If they decline the new branch, leave the plan
   uncommitted, start nothing and say so, as `write-plan` step 6 does, because a delivery run
   records its progress in a committed plan. Write the answer into the plan's two header lines, and
   the person and date into the `**Stories:**` line, because `execute-plan` reads those lines and
   not this conversation.

6. **Commit the plan alone,** `docs(plans): <slug>`. Then on `pull-request` start `execute-plan`,
   because approval chose the pull request as the next gate; on hand-off name it and do not start
   it, as `write-plan` step 6 does, because the person chose to carry on themselves.

## What it skips, and why

No stories, no plan reviewer and no file map beyond the one task's `**Files:**`. A one-task plan
whose behaviours the person approved has little a reviewer can add that the spec pass and
`review-code` will not catch, and the file map and story coverage have nothing to map.

It skips nothing in the build: `execute-plan` runs the plan under `tdd`, the review loop that
`keel plan risk --staged` picks, `review-code` and `ship`, as for any plan.
