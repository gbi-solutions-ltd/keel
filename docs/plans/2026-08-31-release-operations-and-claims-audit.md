# Release operations and claims audit: Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close five gaps in keel's coverage with two new reference files and four rules added to
existing files. No new skill, no description change, no router change.
**Stories:** none. See "There are no stories, and that is a deviation" below.
**ADRs:** ADR-0001, the skill body word ceiling. Three skill bodies are edited and every edit is
budgeted against it in "The three budgets" below. No body crosses the 700 word target, so this plan
creates no new eval arm obligation.
**Architecture:** references, not a skill. The five gaps are narrow and share two owners, so they
land as one reference under `setup-deployment`, one under `write-docs`, and four rules into files
that already exist under `security-audit`. A reference costs nothing in the always-loaded budget;
a skill costs about 45 tokens in every request in every keel project, forever.

## THE CLEAN-ROOM RULE

**Every task inherits this. It is the plan's most important constraint.**

**No task may read anything under `resources/skills-main`.** The implementer will be a session that
has never opened those files, and it stays that way. Every rule written into a keel reference must
be justified from keel's own practice, from this repository's own history, or from general
engineering knowledge, and this plan names which for each one. **If a rule can only be justified by
pointing at that collection, it does not go in.**

Concretely, for the implementer:

- Do not open, `grep`, `find`, `cat` or delegate a read of any path containing `skills-main`.
- Do not read `docs/ideas/leon-van-zyl-skill-collection.md` either. You do not need it. The five
  gaps are restated in full below, and every justification this plan gives cites a path inside this
  repository or names general engineering knowledge.
- No file this plan writes gets a `SOURCES.md` row, a `THIRD-PARTY-LICENSES.md` entry, or an
  attribution line. There is nothing to attribute: this is keel's own work.
- If a section below feels underspecified, write it from the cited keel file and from what you know
  about building software. That is the intended path, not a fallback.

**Why.** The collection that prompted this work carries no licence grant of any kind: no `LICENSE`
file, no statement in its README, and `"license": null` on its upstream repository, checked
2026-08-31. Under copyright the default is that all rights are reserved. Adapting its prose would
require a `SOURCES.md` row naming a source with no notice to reproduce, which is not a row that can
honestly be written. `SOURCES.md` exists precisely to record where the line between an idea and an
adaptation falls, so the safe side of that line is a session that never saw the expression at all.

## Progress

Updated as each task lands. A tick here means its `Done when:` command was run and its output read.

| Task | | Landed |
|---|---|---|
| 1 | `release-operations.md` under `setup-deployment`, and the body link | [x] |
| 2 | `claims-audit.md` under `write-docs`, and a word-neutral body edit | [x] |
| 3 | Four rules into `security-audit` | [x] |
| 4 | The catalog and the README say what the skills now do | [x] |
| 5 | The changelog and the idea record | [x] |
| 6 | Land it: `review-code`, then `ship` | [x] |

## Execution record, 2026-08-31

Tasks 1, 2 and 3 executed inline, not delegated: the session was instructed not to spawn agents.
Tasks 4, 5 and 6 were explicitly out of scope for this run and nothing was staged for them.

**Test pacing deviates from the per-task `Done when:`.** `tests/validate-skills.sh`, the profile's
`test_one`, ran after each task as the gate. `tests/run-tests.sh` ran once at the end and printed
`All test files passed`. All three word counts were taken after each task and are 695, 731, 653.

**Task 3 steps 1 and 2 are left unticked**, as the task instructs. No assertion was written and
nothing was watched failing; this task's correctness is checked by reading.

**`shellcheck` is absent locally.** The suite printed
`SKIP  shellcheck is absent locally. CI will run it: install it to see what CI sees.`
That costs the lint check and nothing else. No file touched by tasks 1 to 3 is a shell file.

### Task 6, run 2026-08-31, and the gate the plan wrote wrong

**Task 5 was completed after the rule was narrowed.** The clean-room rule was relaxed for the first
16 lines of `docs/ideas/leon-van-zyl-skill-collection.md`, its header table, which is keel's own
writing. `Status` and `Next` were set from that table and nothing below line 16 was read.

**`review-code` found one thing worth fixing and it was fixed.** The opening line of
`release-operations.md` asserted that a pipeline document "usually skips" these three moments,
which is a claim about pipeline documents in general that no keel path supports, and which is also
wrong about keel's own `pipeline-patterns.md`, since that file does cover rollback and secrets. It
now says the three moments sit either side of the pipeline that `SKILL.md` covers, which is
checkable. **That was the only sentence in either new reference that could not be traced to a
repository path or to a stated engineering reason.**

**The plan's own clean-room gate cannot pass as written, and that is a defect in this plan.** Task 6
requires `git diff main...HEAD | grep -n "skills-main"` to return nothing. It cannot: this plan
document names `resources/skills-main` in THE CLEAN-ROOM RULE, and the idea record names it too,
both of them precisely to say it must not be read. Five diff lines match, all in those two files and
none in shipped content. **Scoped to what the gate was written to protect it passes cleanly**:
`git diff --cached -- skills/ templates/ | grep -n "skills-main"` returns nothing. The five matching
lines were deliberately not printed, because four of them sit below line 16 of the idea record.
The gate should be scoped to `skills/` and `templates/` if this plan is ever used as a template.

### Tasks 4 and 5, run 2026-08-31

**Task 4 landed in full.** `tests/test-doc-claims.sh` reports `5 passed, 0 failed` and no counted
claim moved. One judgement call inside it: the plan offered "a row or a following sentence" for the
claims audit in the `write-docs` type table. A row was rejected and a following sentence written
instead, because the sentence above that table says the skill covers **six** document types, and a
seventh row would have created the exact countable drift `claims-audit.md` is written about. A
claims audit is also not a document type: it has no output path, which is the thing the plan asked
to be said plainly.

**Task 5 is half done, and the other half cannot be run under the clean-room rule.** `CHANGELOG.md`
is written: the two references and four rules named, the five gaps in a clause each, the three body
moves and the unchanged descriptions sum, the absence of any behavioural eval arm stated as a
limitation rather than a footnote, and the note that `SOURCES.md` and `THIRD-PARTY-LICENSES.md` are
unchanged deliberately because there is nothing to attribute.

**`docs/ideas/leon-van-zyl-skill-collection.md` was not touched.** Task 5 asks for its header table
to be set to `built`, "keeping the sentence that the import was blocked for want of a licence".
That sentence cannot be kept without reading the file, and THE CLEAN-ROOM RULE names that exact path
as one the implementer must not read. **The plan therefore contradicts itself between its own most
important constraint and task 5**, and the contradiction is only visible at task 5. It is recorded
here rather than resolved, because the trade belongs to the person who set the rule. Whoever lifts
it for that one file, or supplies the two table rows, can finish the task in a single edit; nothing
else in the plan depends on it.

One line of that file was read incidentally and is disclosed rather than hidden: a
`grep -rn "claims-audit"` across `docs/` to find broken cross-references returned its line 8, the
header table's `Next` row, which cites this plan. It carries no content from the collection.

### Four plan claims that were wrong when checked

1. **Task 2, the configuration surface.** The plan states that `docs/standards.md` records a
   `profile.verify.lint` entry in this repository that named a broken command. It does not. What
   `docs/standards.md:289-296` records is that `verify.lint` is a 160 character `shellcheck`
   invocation whose length inflates a rendered template block, which is a different defect.
   `claims-audit.md` cites `docs/runbooks/going-public.md:128-129` instead, which is a genuine
   instance of the same class in this repository: an allowlist naming a path that no longer exists
   is "a rule protecting nothing, and nothing would report it".
2. **Task 3 rule 2, the hard block.** The plan states that `.keel/profile.json` sets
   `gates.security_audit` and `hard_block_paths`. It sets the first, to `warn`. `hard_block_paths`
   is absent from this repository's profile; `docs/07-open-decisions.md` decision 3 records that
   the field lives at the top level of the schema and is read by `hooks/sensitive-guard`. The
   written rule cites decision 3 only.
3. **Task 3 rule 1, the coverage check.** The recorded grep returns three hits inside
   `skills/security-audit/references/`, not four. `payments-checklist.md:54` carries the sentence
   the plan quotes but matches neither `webhook` nor `raw body`, so that grep does not return it.
   The conclusion the check was run to reach still holds.
4. **Task 3 rule 4, the coverage check.** The recorded grep returns nothing at all, not one hit at
   `report-template.md:40`. Line 40 is the `docker cp` example finding but contains none of the
   search terms. The conclusion holds and is stronger than recorded.

### Task 2's prescribed headings were replaced, 2026-08-31

**The plan prescribed three section headings that were too close to the external collection's own
section names**, which the clean-room rule exists to avoid. The plan should not have prescribed
them. They were renamed on review, before task 4:

| Prescribed by the plan | Written instead |
|---|---|
| `## A finding is a contradiction` | `## What counts as a finding, and what does not` |
| `## Quote both halves` | `## What a finding must carry` |
| `## Where claims live` | `## The surfaces to sweep` |

Only the headings changed, plus the four sentences whose "halves" wording the removed heading had
seeded. **No content was rewritten and no justification changed**, because the content is keel's own
and each rule still cites the repository path it came from. The section order is unchanged: it runs
definition, evidence bar, surfaces, one surface in detail, exclusions, output, which already reads
as keel's own sequence. No cross-reference or link was broken, and no skill body word count moved,
since a body carries only the link. `write-docs` is still 731.

**`## The ledger` in `release-operations.md` was kept.** It is a generic term for a written running
record, and it is already keel's own vocabulary in this repository:
`skills/security-audit/references/payments-checklist.md:30` has carried a `## The ledger` section
since before this work. Renaming it would have left two keel references using different words for
the same device.

Two smaller miscounts, neither of which changed anything written:
`payments-checklist.md` has seven `##` sections, not the eight the plan states, and the seven the
plan then lists by name are the seven that exist. `CONTRIBUTING.md`'s `git init` incident is at
144-145, not 145-146.


## There are no stories, and that is a deviation worth naming

`write-plan` normally reads `docs/stories/<slug>.md`, and there is no PRD here. The input is an
assessment recorded on 2026-08-31 whose Step 0 analysis found the gaps and whose decision was taken
the same day. That is the same shape `docs/plans/2026-08-30-design-database.md` ran under, and the
same reasoning applies: `create-skill` Step 0 is the process skill for deciding whether a gap needs
a skill or a reference, it has been run, and a PRD would restate a decision already taken.

**One thing is different from that precedent and is worse.** This plan writes reference content
whose value has not been measured against a baseline. `create-skill` Step 1 requires a baseline
before skill content, and none was run here. That is defensible only because nothing here is a
skill: no description enters the router, no body grows past its target, and a reference that turns
out to be useless costs a file rather than a permanent line in every request. **It is still an
unmeasured claim, and task 5 records it as one rather than letting the changelog imply otherwise.**

## The five gaps, restated in full

Self-contained. Nothing below requires reading another document.

**Gap 1: nothing records what a provisioning run created.** `setup-deployment` covers rolling back
a *deploy*: `skills/setup-deployment/SKILL.md:81-86` requires a runbook with a rollback and requires
executing it once, and `skills/setup-deployment/references/pipeline-patterns.md:126-131` states what
is and is not rolled back. Nothing covers unwinding a *provisioning* run: the databases, buckets,
DNS records, webhook endpoints and API keys created while standing an environment up. A run that
fails halfway leaves resources nobody has a list of.

**Gap 2: no per-variable method for configuration and secrets.**
`skills/setup-deployment/SKILL.md:73-76` asks "what differs, where secrets come from, who can
deploy", and `references/pipeline-patterns.md:120-124` says secrets are injected at runtime from the
platform's store and never in an image layer or a build argument. Neither says how to decide, for
one variable, whether its production value is the development value copied over, a different value,
a freshly generated value, or a value that must not exist in production at all. The expensive class
is the variable whose wrong value produces a **successful deploy and a broken system**: a sandbox
endpoint, a debug flag, a localhost URL, a test key, a session secret shared with a laptop.

**Gap 3: nothing verifies a release against the thing actually running.**
`skills/setup-deployment/SKILL.md:39` names "smoke test" as the last pipeline stage and says nothing
about what one checks. `skills/ship/SKILL.md:20-31` gates on tests, lint, audit, review, docs, plan
and branch, all of which are properties of the repository rather than of the running system. Nobody
checks that what is live is the artifact that was intended, or reports the difference between a
check that failed, a check that could not run because something upstream was broken, and a check
nobody attempted.

**Gap 4: nothing audits what a repository claims against what it does.**
`skills/write-docs/SKILL.md:33` warns that prose restating the code goes stale silently, `:87-90`
requires a document to record the commit it describes so staleness is judgeable, and
`skills/review-code/SKILL.md:83` gates a behaviour change on its documentation. All three prevent
*new* drift. None detects drift that already exists. This repository has already paid for that gap:
`tests/test-doc-claims.sh:44-63` exists because README claimed counts the tree contradicted, and
`docs/02-skill-catalog.md:7-11` records a skill that shipped with no catalog section and survived
two releases because nothing checked.

**Gap 5: nothing audits discoverability artifacts.** A sitemap, a `robots.txt`, an `llms.txt` and
page metadata are machine-readable claims about which routes exist and which a stranger may open.
`grep -rln "sitemap\|robots.txt\|llms.txt" skills/` returns nothing. A sitemap listing a route that
404s, or a `robots.txt` disallowing a path the sitemap invites a crawler to open, is the same class
of defect as gap 4 and has no owner. **This is truthfulness, not marketing.** Ranking advice, keyword
strategy and content suggestions are out of scope and the reference must say so.

## The three budgets, measured 2026-08-31

Every number below was measured on this tree at `e60dcee` on branch `sandbox`, with
`awk 'f;/^---$/{c++; if(c==2) f=1}' <file> | wc -w`, which is the same body extraction
`tests/validate-skills.sh:85` uses.

**Budget 1: `setup-deployment` has 17 words of body headroom.**
Its body is **683 words**. The warning threshold is 700 (`TARGET_WORDS=700`,
`tests/validate-skills.sh:24`) and the ceiling is 900 (`CEILING_WORDS=900`, `:23`).
`grep -n "setup-deployment" tests/evals/results.md` returns **nothing**, so it holds no eval arm,
and ADR-0001 requires "a passing eval arm at that length" for any body over 700. Running that arm is
not in scope here, so **the body must land at 700 words or fewer**. That is 17 words for everything
task 1 adds. Task 1's addition is measured at 12, leaving 5.

**Budget 2: `write-docs` must be word-neutral.**
Its body is **738 words**, over the target, and it holds a passing arm at exactly that length:
`tests/evals/results.md:599`, "`write-docs` at 738 words, the ADR-0001 length arm". Growing past 738
requires a new arm at the new length. So **task 2's body edit must remove at least as many words as
it adds**, and its `Done when:` states the before and after counts. Task 2's measured net is minus 7,
landing at 731.

**Budget 3: the descriptions sum does not move.**
It was **1,121 tokens of a 1,320 ceiling** when this was written, and is about 1,130 since
`coding-standards` gained its assess trigger on 2026-09-01 (`DESC_TOTAL_MAX_TOKENS=1320`,
`tests/validate-skills.sh:54`), reported by `tests/validate-skills.sh` on every run as
`descriptions about 1121 tokens`. **Nothing in this plan changes any skill description, the router
in `hooks/session-start`, `skills/keel/SKILL.md`, or `templates/prompting-cheatsheet.md`**, so the
sum stays at 1,121 and the 199 tokens of headroom stay intact. **That is the reason this work is
references rather than a new skill.** A skill for any one of these five gaps would spend about 45 of
those 199 tokens in the prefix of every request in every keel project, permanently, to serve a job
that two files answer for free.

There is a fourth number worth stating because task 3 touches it. **`security-audit`'s body is 620
words** and it holds no eval arm either, so it has 80 words before the 700 target. Task 3 adds a
measured 33, landing at 653.

## Global constraints

Copied in full rather than linked. A task executed by a fresh agent that reads only its own section
must still obey these.

- **The clean-room rule above applies to every task without exception.**
- **Verify commands, from `.keel/profile.json`:** test `tests/run-tests.sh`, one test
  `tests/validate-skills.sh` for skill and reference shape, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
- **`shellcheck` is not installed on this machine.** `tests/run-tests.sh` prints
  `SKIP  shellcheck is absent locally. CI will run it: install it to see what CI sees.` and continues.
  **That costs the lint check and nothing else here: no task in this plan touches a shell file**, so
  the risk is nil and CI covers it regardless. Say so on handover rather than reporting lint passed.
- **Never start on `main`.** Work goes on `sandbox`, which is the current branch.
- **No em dashes and no en dashes anywhere**, including in reference files, the changelog and this
  plan. `tests/validate-skills.sh:171-172` checks shipped content and `:203-204` checks `docs/`.
- **Relative links must resolve.** `tests/validate-skills.sh:177-182` resolves every link inside a
  reference file against the filesystem, and `:207-213` does the same for `docs/`. A body must not
  link a reference file that does not exist yet, so each link lands in the task that creates its
  file.
- **No `@` links.** `tests/validate-skills.sh:130-132` rejects them in a skill body. Use the
  relative markdown form: the name in brackets, then the path in parentheses.
- **`<docs_root>`, never a literal `docs/keel` path.** `tests/validate-skills.sh:135-138` and
  `:163-169`.
- **No organisation name in shipped content.** `tests/no-internal-leaks.sh` fails on `\bGBi`
  anywhere under `skills/` or `templates/`.
- **Reference files have no word ceiling.** `skills/coding-standards` is the precedent at 12
  references and 17,816 reference words with a body of 683. Length is not the constraint; the body
  budgets above are.

## No concurrent batch

Tasks 1, 2 and 3 touch three different skills and look independent. They are not run concurrently,
because each one's `Done when:` runs the whole suite and `tests/validate-skills.sh` recomputes the
descriptions sum and every link in the tree on each run. One at a time, and the suite green between
each.

---

### Task 1: `release-operations.md` under `setup-deployment`, and the body link

**Story:** none. Gaps 1, 2 and 3.
**Files:**
- Create: `skills/setup-deployment/references/release-operations.md`
- Modify: `skills/setup-deployment/SKILL.md`

**Interfaces:**
- Produces: `skills/setup-deployment/references/release-operations.md`, linked from the body. The
  link and the file land in the same commit, because `tests/validate-skills.sh:149-153` resolves
  body links and a link written first fails the suite.

**Depends on:** none

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/setup-deployment/SKILL.md | wc -w` prints **695**, which
is under the 700 target, so `tests/validate-skills.sh` emits no `WARN` for `setup-deployment`.

- [x] **Step 1: Write the failing test**

There is no new assertion to write, and this is stated rather than skipped silently. The checks that
gate this task already exist and already pass: `tests/validate-skills.sh` resolves the body's links
(`:149-153`), enforces the body budget (`:113-128`) and rejects em dashes in the new file
(`:171-172`). Create the link before the file to watch them fire:

```bash
printf '\nRead [references/release-operations.md](references/release-operations.md) before provisioning anything, and again before calling a release done.\n' >> skills/setup-deployment/SKILL.md
tests/run-tests.sh
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/run-tests.sh`
Expected: FAIL, with
`setup-deployment: broken link to references/release-operations.md`.

- [x] **Step 3: Write the minimal implementation**

**First, put the link where it belongs** rather than at the end of the file where step 1 appended it.
Remove the appended line and place this exact sentence as the last line of `## Step 6: Environments
and secrets`, after the migrations paragraph:

```markdown
Read [references/release-operations.md](references/release-operations.md) before provisioning anything, and again before calling a release done.
```

That sentence is 12 words, measured. 683 plus 12 is 695.

**Then write `skills/setup-deployment/references/release-operations.md`.** Required sections, in this
order. Each section's rule and its justification class are given; write the prose from the
justification, not from anywhere else.

1. **`# Release operations`**, with a one-line statement that the file covers three moments:
   creating a resource, deciding a configuration value, and deciding whether a release worked.

2. **`## The ledger`.** Every resource a provisioning run creates is written down as it is created,
   never reconstructed afterwards, with four columns: what it is, where it lives, what it costs, and
   how to remove it.
   - *Justification class: general engineering knowledge.* A process that fails partway through is
     exactly the process that cannot remember what it made, so the record has to be written before
     the step that might fail, not after the run that might not finish.
   - *Justification class: keel practice.* `skills/setup-deployment/SKILL.md:88-91` already requires
     a closing report naming what gates, what does not, and whether rollback was tested. A ledger is
     the same instinct applied to resources rather than to checks.
   - The cost column is not optional: a free tier is a limit that becomes an incident later, and a
     resource with no stated cost is one nobody will decommission.

3. **`## Unwinding a partial run`.** On failure: stop, report, print the ledger, and hand the
   decision to the user. Never delete a resource to start clean. Distinguish a transient failure,
   which may be retried, from a deterministic one, which may not: retrying a build error, a rejected
   request or a failed migration unchanged is superstition, because the same input produces the same
   result.
   - *Justification class: keel practice.* `skills/ship/SKILL.md:34-35`: "Say which check failed,
     show the output, and stop. Do not fix it as part of shipping: a gate that repairs its own
     failures is not a gate, and the fix belongs in its own reviewed change." Same shape, applied to
     provisioning: a process that repairs its own failures destroys the evidence of what happened.
   - *Justification class: general engineering knowledge*, for the retry taxonomy and for the rule
     that a resource holding data is never recreated.
   - State the seam: an outage in a running system is `keel:incident-response`, not this file. A
     failed provisioning run has no users yet, which is what makes stopping cheap.

4. **`## Deciding a configuration value`.** For each variable the system reads, one of five
   dispositions, decided per variable and recorded: copy the development value unchanged, transform
   it, regenerate it, refuse it because it must not exist in production, or ask the user because
   only they hold it. Nothing is copied by default.
   - *Justification class: keel practice.* `skills/setup-deployment/SKILL.md:30-31`: "Every pipeline
     stage runs a command from `profile.verify`. If a command is `null`, the pipeline cannot check
     that thing and you must say so rather than substituting a guess." The rule generalises: decide
     each item explicitly, and where the answer is unknown say so rather than substituting a
     plausible one.
   - *Justification class: keel practice.*
     `skills/setup-deployment/references/pipeline-patterns.md:120-124` already sets the handling
     rule: injected at runtime, never in an image layer or a build argument, never echoed. This
     section is the decision that precedes the handling, not a replacement for it.

5. **`## Values that deploy successfully and break the system`.** A named list of classes, each with
   the failure it produces, because every one of them passes a build: a debug or development flag
   left on, a sandbox or test-mode switch, a `localhost` or private address, a test credential, a
   signing or session secret shared with a developer machine, and a value that is present at runtime
   but absent at build time in a stack that reads configuration at build time.
   - *Justification class: keel practice.*
     `skills/security-audit/references/owasp-checklist.md:119-127`, "Security misconfiguration",
     already names the shape: "A value that starts the service when empty is worse than one that is
     missing, because it starts." This section is that observation turned into a pre-deploy list.
   - *Justification class: general engineering knowledge*, for the specific classes.
   - The shared-secret item carries its own consequence: a session secret copied from a laptop means
     a token minted on that laptop is valid in production. Regenerate, never copy.

6. **`## Verifying a release against what is running`.** Four states for every check, and the
   vocabulary is the point: `passed`, `failed`, `blocked` (something upstream is broken, so this
   check could not run and says which), and `not attempted` (nobody ran it, and it is named rather
   than left out). A cascade reports one cause once rather than fifteen failures.
   - *Justification class: keel practice.*
     `skills/repo-snapshot/references/section-templates.md:169` already runs a three-value evidence
     vocabulary, `measured`, `estimated`, `unmeasured`, "and the word" is required on every value.
     This is the same device for a different question.
   - *Justification class: keel practice.* `skills/security-audit/SKILL.md:66-67`: "Say plainly what
     you did not cover. An audit that implies completeness it does not have is worse than a narrow
     one." `not attempted` is that rule given a name so it cannot be omitted by silence.

7. **`## What the checks are`.** At minimum: the running artifact is the one that was intended, and
   this is compared rather than assumed; the system answers on the address people will actually use;
   a schema migration that the release depended on has evidence it ran; and a check must not mutate
   the system it is checking.
   - *Justification class: keel practice.* `skills/setup-deployment/SKILL.md:59-61`: "Then build it
     and look inside... What a Dockerfile appears to copy and what lands in the image are different
     questions." Same principle at the other end of the pipeline: what the pipeline says it deployed
     and what is answering requests are different questions.
   - *Justification class: general engineering knowledge*, for the rest.

**What this file must not contain.** No vendor, no platform, no CLI. `setup-deployment` reads its
commands from `profile.verify` and its target from `profile.deploy`, and a reference naming a
specific host would be the first file in `skills/` to do so.

- [x] **Step 4: Run it and watch it pass**

```bash
tests/run-tests.sh
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/setup-deployment/SKILL.md | wc -w
```

Expected: `All test files passed`, `25 skills validated` with no `FAIL`, no `WARN` naming
`setup-deployment`, and a word count of **695**.

- [x] **Step 5: Hand over**

```bash
git add skills/setup-deployment
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

---

### Task 2: `claims-audit.md` under `write-docs`, and a word-neutral body edit

**Story:** none. Gaps 4 and 5.
**Files:**
- Create: `skills/write-docs/references/claims-audit.md`
- Modify: `skills/write-docs/SKILL.md`

**Interfaces:**
- Produces: `skills/write-docs/references/claims-audit.md`, linked from the body.
- Consumes: nothing from task 1.

**Depends on:** task 1, for sequencing only. Both run the whole suite and neither should be
diagnosing the other's link failures.

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/write-docs/SKILL.md | wc -w` prints **731**, which is
**at or below the 738 the existing eval arm covers** (`tests/evals/results.md:599`), so no new arm
is owed. Record both numbers on handover: before 738, after 731.

- [x] **Step 1: Write the failing test**

Same position as task 1: the gating checks exist and pass. Create the link first:

```bash
printf '\nAuditing what the docs already claim, rather than writing them, is [references/claims-audit.md](references/claims-audit.md).\n' >> skills/write-docs/SKILL.md
tests/run-tests.sh
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/run-tests.sh`
Expected: FAIL, with `write-docs: broken link to references/claims-audit.md`.

- [x] **Step 3: Write the minimal implementation**

**First, the body edit, and it is exactly two changes.** Remove the line step 1 appended.

*Change one, the addition.* Add this as a new line at the end of `## Step 1: Pick the type`, after
"A README written for the 3am reader is unreadable, and a runbook written for the browsing reader is
useless.":

```markdown
Auditing what the docs already claim, rather than writing them, is
[references/claims-audit.md](references/claims-audit.md).
```

That is 12 words, measured.

*Change two, the removal.* `## Step 5` currently ends with this paragraph, which is 63 words:

```markdown
Write the current state. A document says what is true now, never the review history that produced
it. Durable tradeoffs go to an ADR, stated as properties of the option. When feedback shows a
section is wrong, delete it and write it again from the code: patching the sentence that carried
the wrong claim keeps its frame. Reread against the tells in
[references/current-state-prose.md](references/current-state-prose.md).
```

Replace it with this, which is 44 words:

```markdown
Write the current state. A document says what is true now, never the review history that produced
it. Durable tradeoffs go to an ADR. When a section is wrong, delete it and write it again from the
code. Reread against the tells in
[references/current-state-prose.md](references/current-state-prose.md).
```

**This is deduplication, not word golf, and that distinction is load bearing.** ADR-0001's
Consequences names "a word-golf exercise where a genuine improvement must be paid for by deleting a
different one" as the pathology it exists to stop, and
`tests/evals/results.md:610-613` records a `write-docs` edit being reverted for exactly that reason.
The two clauses removed here are not deleted, they are already in the reference the same paragraph
links: `skills/write-docs/references/current-state-prose.md:22` carries "stated as properties of the
option rather than", and `:10` carries "Amending the sentences that carried the wrong claim keeps
their frame". The body keeps every instruction and hands back the reasoning to the file that already
holds it, which is the split ADR-0001 endorses. **Verify both lines are there before making the cut**,
and if either has moved, do not make the cut and report it.

Net: plus 12, minus 19, so 738 becomes **731**.

**Then write `skills/write-docs/references/claims-audit.md`.** Required sections, in this order.

1. **`# Claims audit`**, with a one-line statement of what the file is for: checking that what a
   repository says about itself is still true, as a review that produces findings rather than as a
   document.

2. **`## A finding is a contradiction`.** Every finding is a claim the repository publishes set
   against the code that fails to keep it. An absence is not a finding here.
   - *Justification class: keel practice.* `skills/review-code/SKILL.md:68-69`: "Per finding:
     `file:line`, what is wrong, why it matters, and what to do. Never a finding without a location,
     and never a location without a reason." A drift finding has two locations rather than one, and
     both are required.
   - **State the seam explicitly, because the rule is otherwise wrong.** keel's audits *are*
     largely lists of absences: `skills/security-audit/references/owasp-checklist.md:79-101` is a
     whole section asking what is missing, and `skills/ship/SKILL.md:21-22` treats a missing test as
     an incomplete change. "Absence is not a finding" is a rule for **this** audit only, because a
     claims audit that lists what a bigger project would have has stopped being a claims audit.
     Absences belong to `keel:security-audit` and `keel:review-code`; say so and hand them over.
   - *Justification class: keel practice*, for stating the seam at all.
     `docs/02-skill-catalog.md:7-11` and this repository's own idea records treat an unstated seam
     between two owners as a defect in its own right.

3. **`## Quote both halves`.** Every finding carries the claim verbatim with the file and line it
   appears on, and the `path:line` of the code that fails to keep it. A finding with only one half
   is unactionable and does not go in the report.
   - *Justification class: keel practice.* `skills/security-audit/SKILL.md:13-14`: "every finding
     needs a concrete exploit and a `file:line`. A report of forty maybes gets ignored; three real
     ones get fixed."

4. **`## Where claims live`.** The surfaces to sweep, with what each typically over-claims: the
   README and its quickstart; every document under the docs root; a public site or landing copy; an
   API reference; a changelog; a privacy or terms page; and the project's own configuration, where a
   declared command or gate may name something that no longer exists.
   - *Justification class: this repository's history, and it is the strongest justification in this
     plan.* `tests/test-doc-claims.sh:44-63` exists because `README.md` stated counts that the tree
     contradicted, and it now pins five of them mechanically: the skill count, the eval scenario
     count, two supply chain rule counts and the open decision count.
     `docs/02-skill-catalog.md:7-11` records the other half: `incident-response` shipped at 0.3.0
     with no catalog section and the gap survived two releases "because nothing checked". Both are
     this exact defect found in this exact repository.
   - The configuration surface is not speculative either: `docs/standards.md` records a
     `profile.verify.lint` entry in this repository that named a broken command.

5. **`## Discoverability artifacts`.** A sitemap, a `robots.txt`, an `llms.txt` and page metadata
   are machine-readable claims about which routes exist and which a stranger may open. Check each
   against the routes that exist: a listed route that does not resolve, a disallowed path the
   sitemap invites a crawler to open, a canonical address that disagrees with the one being served,
   metadata describing a page's content wrongly, and structured data asserting facts the system has
   no record of.
   - *Justification class: general engineering knowledge*, for the mechanics.
   - **`## What is out of scope`, as its own subsection.** Ranking advice, keyword strategy, content
     suggestions, backlinks and "consider adding" are not findings. A project deliberately kept out
     of search, and consistently kept out, is a decision and passes.
   - *Justification class: keel practice.* `skills/review-code/SKILL.md:56-58` already separates
     "Consider", a genuine preference to be said once, from what blocks, and
     `skills/security-audit/SKILL.md:66-67` requires an audit to state its limits. A file that
     wandered into ranking advice would be claiming a competence keel does not have.

6. **`## Reporting`.** Ranked by who is affected and how badly, capped, and closing with a named
   list of what could not be checked and why. The audit is read-only: it reports, and fixing is a
   separate explicit ask.
   - *Justification class: keel practice.* `skills/review-code/SKILL.md:63-64` caps at "around ten
     findings. More than that means the change is too large to review, and that is itself the
     finding", and `:82` sets the read-only rule: "Rewriting it yourself in the review | Say what is
     wrong. The author fixes it." `skills/security-audit/SKILL.md:66-67` sets the closing statement.

**What this file must not contain.** No framework, no file-naming convention from one stack, and no
claim about which crawlers read which file. The first two would make it useless on twelve of the
fifteen languages `lib/detect-stack.sh:306-369` detects; the third is a fact with a short shelf life
and this repository has no way to keep it current.

- [x] **Step 4: Run it and watch it pass**

```bash
tests/run-tests.sh
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/write-docs/SKILL.md | wc -w
```

Expected: `All test files passed`, and a word count of **731**. `tests/validate-skills.sh` still
emits its `write-docs: body is 731 words, over the 700 target` warning, which is correct and
expected: the body was already over the target and the existing arm at 738 covers it.

- [x] **Step 5: Hand over**

```bash
git add skills/write-docs
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** Report before 738, after 731.

---

### Task 3: Four rules into `security-audit`

**Story:** none. Four single rules, each with no current home. **Before writing each one, read the
file it goes into and confirm it is not already covered**; this task records what that check found
on 2026-08-31 so a second finding can be compared against it.

**Files:**
- Modify: `skills/security-audit/references/owasp-checklist.md`
- Modify: `skills/security-audit/references/payments-checklist.md`
- Modify: `skills/security-audit/references/report-template.md`
- Modify: `skills/security-audit/SKILL.md`

**Depends on:** task 2, for sequencing only.

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/security-audit/SKILL.md | wc -w` prints **653**, under
the 700 target, so no `WARN` names `security-audit`.

- [ ] **Step 1: Write the failing test**

None to write, and this is reported rather than ticked silently. Three of the four changes are
prose additions to reference files, which the suite checks for shape and dashes but not for content,
and the fourth is a body edit the word budget already covers. **The honest position is that this
task's correctness is checked by reading, not by a command**, which is the same position
`docs/plans/2026-08-30-design-database.md` recorded for its documentation task.

- [ ] **Step 2: Run it and watch it fail**

Nothing to watch. Do not tick this box; report it.

- [x] **Step 3: Write the minimal implementation**

**Rule 1: a webhook signature is verified over the raw request body.**
Goes into `skills/security-audit/references/owasp-checklist.md`, section
`## Software and data integrity failures`, as a bullet directly after the existing
`- Is an inbound webhook's authenticity verified, or only its sender's key? A shared key
authenticates the sender and does not bind the message.` at `:149-150`.

*Coverage check, run 2026-08-31.* `grep -rn "webhook\|raw body" skills/security-audit/references/
skills/coding-standards/references/` returns four hits: `owasp-checklist.md:74` (a bounded replay
window), `owasp-checklist.md:149` (authenticity versus sender), `stride.md:21` (inbound arrows),
`payments-checklist.md:54` (binds the message, not just the sender), plus two in
`coding-standards/references/api-contracts.md` about outbound webhooks. **None of them says the
signature must be computed over the bytes as received, and none says a verification failure must
return before touching any store.** Re-run that grep and confirm before writing.

The rule: the signature is verified against the raw request bytes, not against a body that was
parsed and re-serialised, because a re-serialisation that changes one byte of whitespace or key
order produces a valid message that fails, or an invalid one that passes, depending on which side
normalised. And a failed verification returns without reading or writing anything, because a handler
that records the event first has already accepted it.
- *Justification class: general engineering knowledge.*

**Rule 2: a payments go-live is a separate explicit confirmation, and endpoints are listed before
they are created.**
Goes into `skills/security-audit/references/payments-checklist.md`, as a new final section
`## Going live` after `## Reconciliation and evidence`.

*Coverage check, run 2026-08-31.* That file has eight sections: money arithmetic, idempotency, the
ledger, card data, partner integrations, authorisation on money, reconciliation and evidence. **None
of them mentions test mode, sandbox mode, a go-live step, or creating an integration endpoint.** It
audits the code that moves money and is silent on the moment the money becomes real. Confirm with
`grep -n "^##" skills/security-audit/references/payments-checklist.md` before writing.

The rules, as checklist items in the file's existing interrogative style:
- Is the switch from test to live a separate, explicitly confirmed act, rather than a consequence of
  a general go-ahead? It is the only step that can charge a real card.
- Is the current mode visible to whoever is operating the system, rather than inferable only from a
  credential prefix?
- Before an integration endpoint is created, is the existing set listed first? A second endpoint on
  the same address delivers every event twice, and the stored signing secret matches one delivery
  and fails the other, so the symptom is intermittent.
- Are amounts and currencies read back and confirmed before anything is created live? A live price
  is usually deactivatable and not deletable, so a wrong figure is a permanent record and a business
  event rather than a bug.
- *Justification class: keel practice*, for the shape. `.keel/profile.json` sets
  `gates.security_audit` and `hard_block_paths`, and `docs/07-open-decisions.md` decision 3 resolved
  that anything touching money movement is hard blocked and "not overridable by a sentence in chat".
  A go-live is the largest instance of that decision and the checklist did not have it.
- *Justification class: general engineering knowledge*, for the duplicate-endpoint and price-immutability
  mechanics.

**Rule 3: parallel reviewers do not see each other's findings.**
Goes into `skills/security-audit/SKILL.md`, appended to the existing delegation paragraph at
`:46-48`, which currently reads "Delegate phases to parallel subagents on a `--full` run, one per
phase, model `sonnet`, and say which model in one line. The reading stays out of the main context,
and step 3 verifies every finding before it is written, so nothing ships on the cheaper model's
judgement alone."

*Coverage check, run 2026-08-31.*
`grep -rni "corroborat\|see each other\|share findings" skills/security-audit/ skills/review-code/`
returns nothing. `skills/execute-plan/references/subagent-prompts.md:5-13` has the nearest relative,
"Why two review passes and not one", but it is about splitting one reviewer into two questions, not
about isolating concurrent ones, and it belongs to `execute-plan`.

The exact text to append, measured at 33 words:

```markdown
Brief each on its own phase and nothing else. An agent that can read another's findings starts
agreeing with them, and agreement between agents that see each other is an echo, not corroboration.
```

620 plus 33 is **653**.

**This goes in the body and not in a reference, and that is a deliberate departure worth
recording.** `skills/security-audit/SKILL.md:29-44` lists seven phases and only three of them have a
reference file (`stride.md`, `owasp-checklist.md`, `payments-checklist.md`). A rule placed in a
reference would reach three of seven subagents. The rule is an instruction to whoever dispatches, so
it belongs where the dispatch instruction already is.
- *Justification class: keel practice.* `skills/review-code/SKILL.md:26-27` already prefers
  independent reviewers for exactly this reason: "Its multi-agent confidence scoring catches more
  than one inline read." Confidence from several agents is only worth more than one agent's if the
  agents are independent.

**Rule 4: an audit does not modify what it is auditing.**
Goes into `skills/security-audit/references/report-template.md`, section `## Not covered`.

*Coverage check, run 2026-08-31.*
`grep -rni "read-only\|non-destructive\|do not modify\|system under test" skills/security-audit/`
returns one hit, `report-template.md:40`, and it is an example finding about `docker cp`, not a rule
of conduct. **Nothing in the skill or its four references says an audit must not change the thing it
is auditing.** Confirm before writing.

The rule: nothing in an audit modifies what is being audited. No configuration edit, no install, no
migration, and no request to a write endpoint to find out what it does. A check that needed a change
to the system in order to pass was not run, and it belongs in this section under its real name
rather than in the findings. On a client system, running a write to see what happens is a change to
somebody's data made without asking.
- *Justification class: keel practice.* `skills/security-audit/SKILL.md:66-67`: "Say plainly what
  you did not cover. An audit that implies completeness it does not have is worse than a narrow one."
  This rule is what makes that sentence enforceable: without it, a check can be made to pass and
  then honestly reported as passing.
- *Justification class: this repository's history.* `CONTRIBUTING.md:145-146` records it happening
  here: "During development a probe of mine ran `git init` in a project as a side effect of a
  read-only check, which it had no business doing." The reference is written from that, and the
  section may cite it.

- [x] **Step 4: Run it and watch it pass**

```bash
tests/run-tests.sh
awk 'f;/^---$/{c++; if(c==2) f=1}' skills/security-audit/SKILL.md | wc -w
```

Expected: `All test files passed`, no `WARN` naming `security-audit`, and a word count of **653**.

- [x] **Step 5: Hand over**

```bash
git add skills/security-audit
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** Report, for each of the four rules, what the
coverage check returned when you ran it, and whether it matched what this task recorded.

---

### Task 4: The catalog and the README say what the skills now do

**Story:** none. Standing rule, `CONTRIBUTING.md:125`: "Documentation lands in the same commit.
`README.md`, `CHANGELOG.md`, and the plan."
**Files:**
- Modify: `docs/02-skill-catalog.md`
- Modify: `README.md`

**Depends on:** tasks 1, 2, 3.

**Done when:** `tests/run-tests.sh` prints `All test files passed`, including
`tests/test-doc-claims.sh` reporting `5 passed, 0 failed`.

- [ ] **Step 1: Write the failing test**

None, and the reason is worth stating because it is the gap this plan's task 2 is about.
`tests/test-doc-claims.sh:44-63` pins five counted claims and **none of them counts reference
files**, so the catalog can go stale here without the suite noticing. Adding a sixth claim is not in
scope and is recorded in "What this plan does not settle".

- [ ] **Step 2: Run it and watch it fail**

Nothing to watch. Do not tick this box; report it.

- [x] **Step 3: Write the minimal implementation**

`docs/02-skill-catalog.md`, three edits:

- The `### setup-deployment` section at `:402`. Its `**Does:**` paragraph lists the pipeline stages
  and its following paragraphs cover environments, secrets and the runbook. Add a sentence naming
  `references/release-operations.md` and the three moments it covers: recording what a provisioning
  run created, deciding a configuration value, and deciding whether a release worked.
- The `### write-docs` section at `:440`. Its type table lists six document types. Add a row or a
  following sentence for the claims audit, and say plainly that it produces findings rather than a
  document, so nobody looks for an output path.
- The `### security-audit` section at `:345`. Add a sentence naming the reviewer independence rule
  and the no-modification rule, since both change what the skill does rather than only what it
  checks.

`README.md`, one edit. Its skill table at `:180-185` gives each skill a one-line "Built" note.
`skills/coding-standards`'s row at `:178` is the precedent for naming a skill's references in that
table. Extend the `setup-deployment` and `write-docs` rows to name the new reference, in the same
compressed style. **Do not change any counted claim**: the skill count, the eval scenario count, the
two supply chain rule counts and the open decision count are all pinned by
`tests/test-doc-claims.sh` and none of them moves.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, with `tests/test-doc-claims.sh` reporting `5 passed, 0 failed`.

- [x] **Step 5: Hand over**

```bash
git add docs/02-skill-catalog.md README.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 5: The changelog and the idea record

**Story:** none. Standing rule: a change lands with the documents it makes wrong.
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/ideas/leon-van-zyl-skill-collection.md`

**Depends on:** tasks 1 to 4.

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

- [ ] **Step 1: Write the failing test**

None. The suite has no assertion for a changelog entry or a status line, which is why nine idea
records went stale and were corrected on 2026-08-30. Say so on handover.

- [ ] **Step 2: Run it and watch it fail**

Nothing to watch. Do not tick this box; report it.

- [x] **Step 3: Write the minimal implementation**

**`CHANGELOG.md`, under the existing `## Unreleased` heading**, below the `design-database` entry.
The entry states what landed and, in the same breath, what is unmeasured, because the alternative is
a changelog that implies evidence this work does not have:

- Two new references and four rules, named, with the five gaps they close stated in one clause each.
- The budgets, because they are the reason this is references rather than a skill: the descriptions
  sum is unchanged at 1,121 of 1,320, `setup-deployment` moves 683 to 695, `write-docs` moves 738 to
  731 and stays inside its existing eval arm, and `security-audit` moves 620 to 653.
- **That none of it has a behavioural eval arm.** `create-skill` Step 1 requires a baseline before
  skill content; none was run, and the justification is that nothing here is a skill. Write that as
  a limitation, not as a footnote.
- **That it is keel's own work with no third-party source**, so `SOURCES.md` and
  `THIRD-PARTY-LICENSES.md` are unchanged and deliberately so.

**Do not touch `VERSION`.** Established from `CONTRIBUTING.md:132-137`: releases are monthly, tagged
and gated by the behavioural evals, and nothing in that section or anywhere else in `CONTRIBUTING.md`
ties a change to a version bump. The existing `## Unreleased` block already holds the
`design-database` work with `VERSION` unmoved, which is the precedent. **No version bump is required
and none is planned.**

**`docs/ideas/leon-van-zyl-skill-collection.md`**, header table only. Set `Status` to `built
<date>`, citing this plan, keeping the sentence that the import was blocked for want of a licence
and that the gaps were filled from keel's own practice instead. Set `Next` to nothing outstanding,
or to what remains. Change nothing else in that file: its assessment sections are the record of what
was examined and are not rewritten by the outcome.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add CHANGELOG.md docs/ideas/leon-van-zyl-skill-collection.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 6: Land it

**Story:** none. `.keel/profile.json` sets `gates.review` and `gates.done_verified` to `required`.
**Files:** none created or modified by the task itself.

**Depends on:** tasks 1 to 5.

**Done when:** `tests/run-tests.sh` prints `All test files passed` and `ship` reports a PR URL.

- [ ] **Step 1: Write the failing test**

None. This task runs gates rather than adding behaviour.

- [ ] **Step 2: Run it and watch it fail**

Nothing to watch. Do not tick this box; report it.

- [x] **Step 3: Run `review-code`**

`use review-code` over the full diff against `main`. Two of its Step 3 checks matter most here and
are called out so they are not skipped:

- **Does the diff match the plan?** Anything in the diff that no task above asked for is unplanned
  scope. In particular, **any reference to `resources/skills-main` in any staged file is a
  clean-room violation** and blocks: `git diff main...HEAD | grep -n "skills-main"` must return
  nothing.
- **Does it contradict an accepted decision?** ADR-0001 is the one at risk. Re-run the three word
  counts and confirm 695, 731 and 653.

Fix anything blocking before continuing.

- [x] **Step 4: Run `security-audit --diff`, then `ship`**

`use security-audit --diff` first, because `ship`'s gate at `skills/ship/SKILL.md:24-25` requires it.
The diff is markdown only, so expect it to be short and say so rather than implying a full audit ran.

Then `use ship`. It runs `tests/run-tests.sh`, checks the branch is not `main`, and opens the PR.
**On `shellcheck`:** it is absent locally and the suite prints `SKIP`. Report lint as skipped, not
passed, and say CI runs it. No file in this plan is a shell file, so nothing here is at risk from it.

The PR body states what changed and why, which of the five gaps each file closes, that no behavioural
eval arm was run and why, and the three word counts before and after.

- [x] **Step 5: Hand over**

Report the PR URL, what the gate checked, and anything accepted rather than fixed.

---

## Self-review, run 2026-08-31

`write-plan` Step 5's four mechanical checks, run against this plan before it was handed over.

1. **Story coverage.** There are no stories. All five gaps map to tasks: gaps 1, 2 and 3 to task 1,
   gaps 4 and 5 to task 2. The four `security-audit` rules in task 3 are not among the five gaps and
   are named as separate work in the goal.
2. **Placeholder scan.** No "TBD", no "implement later", no "similar to task N", no "add appropriate
   error handling". Every file is named, every section is enumerated, and every word count is
   measured rather than estimated.
3. **Name consistency.** Two files are created and each is named identically everywhere it appears:
   `skills/setup-deployment/references/release-operations.md` and
   `skills/write-docs/references/claims-audit.md`.
4. **Command accuracy.** Every verifying command is `tests/run-tests.sh` from `profile.verify.test`,
   or `tests/validate-skills.sh` from `profile.verify.test_one`. The `awk`/`wc` word counts and the
   `grep` coverage checks are investigative and read-only, which `write-plan` Step 5 item 4
   explicitly permits.

**The dispatched plan review was not run**, and `write-plan` Step 5 requires recording that rather
than omitting it. The reason is scope: this turn was instructed to produce the plan and no other
artifact, and a review subagent was not requested. The four mechanical checks compare the plan to
itself and none of them opens a file the plan does not name, so **the risk this leaves open is the
one Step 5 says it leaves open**: a plan can pass all four and still be unbuildable. The mitigation
is that every claim in this plan about this repository was verified by reading the cited line before
it was written, and task 6's `review-code` pass reads the resulting diff against the plan.

## What this plan does not settle

**Whether either reference is any good.** Nothing here is measured. `create-skill` Step 1 requires a
baseline before skill content and none was run, on the argument that a reference is cheap to remove
and a skill is not. That argument is sound about cost and says nothing about value. **The honest
statement is that two files are being written on the strength of a Step 0 gap analysis alone**, and
task 5 puts that in the changelog so it is not later mistaken for evidence.

**Whether the claims audit belongs in `write-docs` at all.** `review-code` was the other candidate
and it has 89 words of body headroom against `write-docs`'s zero, which would have avoided task 2's
compression entirely. `write-docs` won because `skills/review-code/SKILL.md:18` scopes that skill to
a diff and its plan from the first instruction, while drift is a property of the repository rather
than of a change. If the reference turns out to be used mostly during review, that decision should
be revisited rather than defended.

**Whether reference files should be counted by `tests/test-doc-claims.sh`.** Task 4 relies on
discipline for the catalog, which is exactly the failure mode task 2's reference is written about.
`docs/02-skill-catalog.md:7-11` already admits it: "**This file is not** [checked], so it stays a
discipline: a skill added without a section here is a skill nobody can look up." Adding a sixth
counted claim is a change to the test suite and is out of scope here.

**`security-audit`'s remaining headroom.** After task 3 its body is 653 of a 700 target, leaving 47
words and no eval arm. The next rule that needs to reach all seven phases has nowhere to go, because
four of the seven have no reference file. That is a real structural gap in that skill and it is not
this plan's to fix.

**Whether the licence could still be obtained.** The decision recorded on 2026-08-31 was to stop
waiting, not that asking is pointless. If a grant ever arrives, the assessment's own recommendation
becomes live again, and the files this plan writes would then be compared against it rather than
replaced by it.
