# design-database Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** one skill, `design-database`, that owns schema design and existing-database review, and
whose content is the systematic sweep a skill-less agent omits rather than the review technique it
already has.
**Stories:** none. See "There are no stories, and that is a deviation" below.
**ADRs:** ADR-0001, the skill body word ceiling. This adds a 25th body to the distribution ADR-0001
asks to re-measure at each release, and the body is budgeted at 700 words for that reason.
**Architecture:** a required-sections review template plus engine references, per `create-skill`
Step 2. The body carries the routing seams and the required output shape and nothing else. Latency
work routes to `optimize-performance`, the document to `write-docs`, the ERD to
`design-architecture/references/mermaid-patterns.md`.

## Progress

Updated as each task lands. A tick here means its `Done when:` command was run and its output read.

| Task | | Landed |
|---|---|---|
| 1 | The skill exists and is routable, atomically | [x] |
| 2 | The review output template, which is the skill's actual content | [x] |
| 3 | `normalisation.md` and `type-selection.md`, the two swept omissions | [x] |
| 4 | `indexing-and-partitioning.md`, and the seam with `optimize-performance` | [x] |
| 5 | `postgres.md` and `oracle.md` | [x] |
| 6 | `design-architecture` states the seam in its description | [x] |
| 7 | `create-skill` Step 4: re-run the scenario with the skill, close what it finds | [x] |
| 8 | Close the idea record and the changelog | [x] |

## There are no stories, and that is a deviation worth naming

`write-plan` normally reads `docs/stories/<slug>.md`, and there is no PRD here either. The inputs are
`docs/ideas/database-design-and-review.md`, whose scope and form were decided on 2026-08-19, and the
`create-skill` Step 1 baseline recorded in `tests/evals/results.md` for the same date. The idea
record's own `Next` says "a plan under `docs/plans/`", not a PRD.

**That is defensible here and would not be for a feature.** `create-skill` is the process skill for
this artifact, its Steps 0, 1 and 2 are already run and recorded with a measured baseline, and its
Step 3 is "write the minimum". A PRD would restate decisions already taken. If anyone wants stories,
they should be written before task 2, which is the only task that decides what the skill asserts.

## Global constraints

Copied in full rather than linked. A task executed by a fresh agent that reads only its own section
must still obey these.

- **Verify commands, from `.keel/profile.json`:** test `tests/run-tests.sh`, one test
  `tests/validate-skills.sh` for skill shape and `tests/test-doc-claims.sh` for the counts, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
- **`shellcheck` is not installed on this machine.** `tests/run-tests.sh` prints `SKIP` for it and CI
  runs it. Say so on handover rather than reporting lint passed. Only task 1 touches a shell file.
- **Never start on `main`.** Work goes on `sandbox`.
- **No em dashes anywhere**, including in the skill body and every reference file.
- **ADR-0001: the body targets 700 words and 900 is the hard ceiling.** Over 700 warns and takes on
  an obligation to hold a passing eval arm at that length. Task 7 is that arm. Reference files have
  no word ceiling; `coding-standards` is the precedent at 12 references and 17,816 reference words
  with a body of 683.
- **The description ceiling is 216 characters**, and the sum of all descriptions is capped at 1,320
  tokens, `tests/validate-skills.sh:54`. The current total is about 1,066 at 24 skills, so a 25th
  description of the 44-token mean lands near 1,110. Room exists; it is not unlimited.
- **The body must not teach review technique.** The baseline found an unseeded 32 bit `SERIAL`
  exhaustion at 85 days' notice, the PCI exposure, the float-money reproducibility argument and two
  double-payment paths, unaided. `create-skill` Step 2: an omission from something the model already
  produces is fixed structurally, by a required field, never by prose reminders or prohibitions.

## The registration is atomic, and this is the plan's sharpest constraint

**Four rules fire the moment `skills/design-database/` exists, and they cannot be satisfied in
sequence.** Measured 2026-08-30 by reading the checks:

| Rule | Where | Fails if |
|---|---|---|
| Every skill directory is named in the router | `tests/validate-skills.sh:326` | the hook does not name `design-database` |
| Every router destination exists | `tests/validate-skills.sh:306` | `skills/keel/SKILL.md` routes to it before the directory exists |
| The shipped cheatsheet mentions every routed skill | `tests/validate-skills.sh:313` | `templates/prompting-cheatsheet.md` omits it |
| README's skill count equals the directory count | `tests/test-doc-claims.sh:45` | README still says 24 |

So the directory, `hooks/session-start`, `skills/keel/SKILL.md`, `templates/prompting-cheatsheet.md`
and `README.md` all land in **one commit**, or the suite is red in between. That is task 1, and it is
why task 1 is larger than it looks.

### And the router has 1 character of headroom

`NFR-01` of `docs/prd/plain-language-chat.md` caps **every** profile combination at **1,285
characters, 356 tokens**. Bernard chose 356 over the 400 hard limit on 2026-08-18, and
`tests/validate-skills.sh:365` fails above it.

**Measured 2026-08-30 across all four combinations, which is what `NFR-02` requires and what a single
run from the repository root does not give you:**

| response_style | explain_level | chars | tokens |
|---|---|---|---|
| terse | technical | **1,284** | 356 |
| terse | plain | 1,283 | 356 |
| verbose | plain | 1,273 | 353 |
| verbose | technical | 1,082 | 300 |

The worst case is `terse` plus `technical` at 1,284, so there is **1 character of headroom**, and
adding `, design-database` costs 17.

**Decided 2026-08-30 by Bernard, asked as a choice: trim the router's wording, and hold `NFR-01`.**
Four trims, not three:

| From | To | Saves |
|---|---|---|
| `Unsure which fits: use the keel skill to route.` | `Unsure: use the keel skill to route.` | 11 |
| `apex-port-plan for Oracle APEX.` | `apex-port-plan.` | 16 |
| `Production is down now:` | `Production is down:` | 4 |
| `Answer directly when no skill fits;` | `Answer directly when none fits;` | 4 |

**The fourth trim is not padding, and simulating it is what showed why.** The three originally costed
save 19 against the 17 needed and land the worst case at 1,282 characters, which is **356 tokens
exactly**: passing, because the check fails above 356, but with zero tokens of headroom, so the next
skill or any router rewording fails immediately. Dropping `for Oracle APEX` costs nothing in meaning,
since `apex-export` and `apex-port-plan` both carry the word.

No skill name is dropped, and every trim is in the base block rather than the paragraph
`plain-language-chat`'s `FR-07`, `FR-08` and `FR-15` measured.

**Simulated result, measured 2026-08-30 on a copy of the hook with all four trims and the new skill
name applied:** worst case `terse` plus `technical` at **1,266 characters, 351 tokens**. That is 19
characters and 5 tokens inside `NFR-01`.

## No concurrent batch

Tasks 2 to 5 write different reference files and could look independent, but each one's `Done when:`
runs the whole suite, and `tests/validate-skills.sh` resolves `@` links from the body, which task 2
onwards keep editing. One at a time.

---

### Task 1: The skill exists and is routable, atomically

**Story:** none. Idea record, "Decided: one skill, handing the overlaps off rather than competing".
**Files:**
- Create: `skills/design-database/SKILL.md`
- Modify: `hooks/session-start`
- Modify: `skills/keel/SKILL.md`
- Modify: `templates/prompting-cheatsheet.md`
- Modify: `README.md`
- Modify: `docs/prompting.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `tests/test-session-start.sh` **(added during execution, see the deviation below)**

**Interfaces:**
- Produces: the skill directory every later task writes into, and the `@references/...` link targets
  tasks 2 to 5 fill in. **The body must not link a reference file that does not exist yet**, because
  `tests/validate-skills.sh` resolves those links; add each link in the task that creates its file.
  **Links are relative markdown, the name in brackets then the same path in parentheses, never the
  `@references/...` form:**
  the validator rejects the `@` form outright. Corrected during execution 2026-08-30.

**Depends on:** none

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`tests/validate-skills.sh` reports `25 skills validated` with no `FAIL`.

- [x] **Step 1: Write the failing test**

There is no new assertion to write. **The tests that gate this task already exist and currently
pass**, which is the opposite of the usual TDD position and is why this step is not skipped silently:
`validate-skills.sh:326`, `:306`, `:313` and `test-doc-claims.sh:45` all fire on the new directory.
Create the directory first with an empty `SKILL.md` and run the suite to watch them fail:

```bash
mkdir -p skills/design-database && : > skills/design-database/SKILL.md
tests/run-tests.sh
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/run-tests.sh`
Expected: FAIL, at least `hooks/session-start does not name the skill "design-database"` and
`skill count: README.md says 24, tree has 25`, plus frontmatter failures on the empty file.

- [x] **Step 3: Write the minimal implementation**

`skills/design-database/SKILL.md`, frontmatter first. The description states triggers only, never the
process, per `create-skill` Step 3:

```markdown
---
name: design-database
description: Use when designing a database schema, reviewing or remediating an existing one, normalising tables, choosing column types, or planning indexes and partitioning for a database.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Design Database

## Overview

Schema design, and review of a database that already exists.

**Core principle:** the findings are not the hard part. A capable reader already finds the urgent
defect; what gets skipped is the sweep, so every review fills in the same required sections whether
or not anything interesting turned up in them.

## What this skill does not own

Hand these off rather than repeating them. Each already has an owner that does it better.

| Concern | Goes to |
|---|---|
| Which engine, and whether a database is the right store at all | `design-architecture` |
| Query latency, N+1, missing indexes on a slow query, reading a plan | `optimize-performance` |
| Producing the document itself | `write-docs` |
| Drawing the ERD | `design-architecture/references/mermaid-patterns.md`, section ER |

Partitioning stays here, because it is a schema decision with a retention consequence rather than a
query fix.

## Step 1: Establish what you are looking at

Read the schema from the database where you can, and say so when you could not. A hand-regenerated
schema file may not describe production, and a review of the wrong artifact is worse than none.

Ask, or record as unverified: what enforces integrity outside the schema. Application validators are
invisible here and change every finding about a missing constraint.

## Step 2: Review, or design

Both produce the same document, and its sections are not optional.

## Step 3: Fill every required section

A section with nothing in it says `None found`, and that is a finding. A section left out is not.

## Common mistakes

| Mistake | Instead |
|---|---|
| Reviewing the headline defect and stopping | The sections are a sweep. Fill them all |
| An ERD left undrawn because the model was obvious to you | You reconstructed it to review it. Draw it |
| Recommending a rewrite when a constraint would do | Say what the smallest correct change is |
```

**The body stops there for now.** Tasks 2 to 5 add one `@references/...` link each as they create
the file, because the validator resolves links and a link to a file that does not exist fails.

Then, in `hooks/session-start`, apply the three trims from "And the router has 2 characters of
headroom" above, and add the skill to the design line:

```
Discover and define: repo-snapshot, shape-idea, write-prd, write-user-stories, design-architecture, design-database.
```

Then add a row to `skills/keel/SKILL.md`'s routing table, a row to
`templates/prompting-cheatsheet.md` and a row to `docs/prompting.md`, all three matching the existing
shape in each file. Then `README.md`: `24 skills built` becomes `25 skills built`, and `The 24
skills` becomes `The 25 skills`. Then an entry in `docs/02-skill-catalog.md` following the shape the
other entries use, with `Reads:`, `Writes:` and `Does:`.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, and `validate-skills.sh` reports `25 skills validated`.

**Then read the hook size explicitly**, because it is the constraint most likely to be silently
violated:

```bash
probe="$(mktemp -d)"; ( cd "$probe" && git init -q -b main . && mkdir -p .keel && \
  printf '{"docs_root":"docs","conventions":{"response_style":"terse","explain_level":"technical"}}' > .keel/profile.json && \
  "$OLDPWD/hooks/session-start" | wc -c ); rm -rf "$probe"
```

Expected: **1,266**. Anything above 1,285 fails `NFR-01`, and the suite says so. The simulation that
produced 1,266 ran on a copy, so a different number here means the trims were applied differently,
and that difference is worth reading rather than accepting.

**Two deviations, found during execution 2026-08-30 and recorded rather than absorbed.**

**The body must not carry the `references/review-template.md` link, and this task's own draft
carried it.** The constraint is in the `Interfaces` block above, and task 2 step 1 adds that link as
its failing test. The draft contradicted both. The sentence ships without the link and task 2 adds
it, which is what the surrounding text already said.

**`tests/test-session-start.sh:132` pins the hook's exact size for all four forms**, not as an upper
bound, and this task's `Files` block did not list it. Its own comment says why the pin is exact: "a
wording edit has to be a deliberate act with a re-measurement rather than a drift that stays green
until it does not." So re-measuring is the intended workflow rather than a broken test, and the four
numbers move in this commit: 1284 to 1266, 1283 to 1265, 1082 to 1064, 1273 to 1255.

- [x] **Step 5: Hand over**

```bash
git add skills/design-database/SKILL.md hooks/session-start skills/keel/SKILL.md \
        templates/prompting-cheatsheet.md README.md docs/prompting.md docs/02-skill-catalog.md \
        tests/test-session-start.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** Paste the `git status --porcelain` output into
your report, and report the character count you read.

---

### Task 2: The review output template, which is the skill's actual content

**Story:** none. Baseline: "the form is structural, not prose".
**Files:**
- Create: `skills/design-database/references/review-template.md`
- Modify: `skills/design-database/SKILL.md`, to add the `@` link

**Interfaces:**
- Consumes: the body from task 1.
- Produces: the required section list tasks 3 to 5 write reference files for.

**Depends on:** task 1

**Done when:** `tests/run-tests.sh` prints `All test files passed` with the new `@` link resolving.

**This is the task the whole skill exists for.** The baseline omitted four things, and every one is a
sweep rather than an insight: column types were never swept, denormalisation went unmentioned though
normalisation was in the request, no ERD was drawn though the model had been reconstructed, and
partitioning appeared once in passing rather than as a decision with a partition key and a retention
consequence. A required section for each is the structural fix `create-skill` Step 2 prescribes.

- [x] **Step 1: Write the failing test**

Add the link to the body, which fails until the file exists:

```markdown
Both produce the same document, and its sections are not optional. See
[references/review-template.md](references/review-template.md).
```

**The template itself ships without its three forward links.** It refers to `type-selection.md`,
`normalisation.md` and `indexing-and-partitioning.md`, which tasks 3 and 4 create, and the validator
resolves those too. Tasks 3 and 4 already list `review-template.md` under `Files` for this reason.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL naming the unresolved link to `references/review-template.md`.

- [x] **Step 3: Write the minimal implementation**

`skills/design-database/references/review-template.md`. The required sections, in order, each with
what it must contain and what it says when empty:

1. **What was read, and what could not be.** The source of the schema, whether it came from the
   database or a file, and what enforces integrity outside it.
2. **The model, as an ERD.** Mermaid, every relationship labelled, per `mermaid-patterns.md`. Never
   omitted on the grounds that the model is simple.
3. **Keys and constraints.** Every table's primary key, or its absence. Unique constraints the
   business rules imply and the schema lacks.
4. **Column types, swept table by table.** Every column whose type does not match its meaning. This
   is a sweep, not a search: the finding is the list, and `None found` is a valid entry only after
   every table has been looked at.
5. **Normalisation.** Duplicated columns, partial and transitive dependencies. See
   `normalisation.md`.
6. **Indexes and partitioning.** Partitioning stated as a decision with a partition key and a
   retention consequence, or `Not warranted, because`. See `indexing-and-partitioning.md`.
7. **Capacity.** Anything with a ceiling: integer key ranges against current row counts, and the
   query that settles each.
8. **What to change first.** Ordered, with the smallest correct change for each.

Include the rule that a section with nothing in it says `None found` and that omitting a section is
not permitted, since that is the entire mechanism.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add skills/design-database/references/review-template.md skills/design-database/SKILL.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 3: `normalisation.md` and `type-selection.md`, the two swept omissions

**Story:** none. Baseline: "Column types were never swept", "Denormalisation went unmentioned".
**Files:**
- Create: `skills/design-database/references/normalisation.md`
- Create: `skills/design-database/references/type-selection.md`
- Modify: `skills/design-database/references/review-template.md`, to link both

**Interfaces:**
- Consumes: the section list from task 2.

**Depends on:** task 2

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

Both files are one task because neither is useful without the other: sections 4 and 5 of the
template are the pair the baseline skipped, and shipping one leaves the sweep half-built.

- [x] **Step 1: Write the failing test**

Link both from `review-template.md` sections 4 and 5. The links fail until the files exist.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL on both unresolved links.

- [x] **Step 3: Write the minimal implementation**

`normalisation.md`: the forms through 3NF stated as questions a reviewer answers per table, the
duplicated-column case the fixture actually carried (`transactions.merchant_name` and
`transactions.customer_email` duplicating columns on their parents), when denormalisation is a
deliberate and recorded decision rather than a defect, and what evidence makes it deliberate.

`type-selection.md`: the mismatches the baseline walked past, each with why it costs something, not
merely that it is wrong. `date_of_birth VARCHAR(20)` cannot be compared or validated.
`active VARCHAR(5)` for a boolean admits `'true'`, `'TRUE'`, `'yes'` and `''`. `deleted INT` as a
soft-delete flag carries no deletion time and no actor. Money as `FLOAT`, with the reason the
baseline itself gave: `SUM()` over floats is not associative under parallel aggregation, so a
disputed settlement figure cannot be reproduced. Include the integer-width question, since the
baseline's best finding was a 32 bit `SERIAL` at 1.5 billion rows.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add skills/design-database/references/normalisation.md \
        skills/design-database/references/type-selection.md \
        skills/design-database/references/review-template.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 4: `indexing-and-partitioning.md`, and the seam with `optimize-performance`

**Story:** none. Baseline: "Partitioning appeared once, as something to combine with a rebuild".
**Files:**
- Create: `skills/design-database/references/indexing-and-partitioning.md`
- Modify: `skills/design-database/references/review-template.md`, to link it

**Depends on:** task 2

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

**The seam matters more than the content here.** `optimize-performance` Step 3 already covers N+1,
missing indexes, `SELECT *` and reading the query plan, and the idea record's step 0 found that. This
file must not restate them. It owns partitioning as a schema decision, and index design at the point
where it is a modelling question rather than a slow-query fix.

- [x] **Step 1: Write the failing test**

Link it from `review-template.md` section 6.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL on the unresolved link.

- [x] **Step 3: Write the minimal implementation**

Partitioning stated as a decision requiring three answers, none of which may be left blank: the
partition key, the retention consequence, and what breaks if the key is wrong. Include the case the
fixture carried, a 400 million row `transactions` table whose settlement job went from twenty minutes
to nine hours, and why partitioning is a different answer from an index there. State the referral to
`optimize-performance` explicitly, so a reader who arrived with a slow query is sent on rather than
served a worse copy of that skill's Step 3.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add skills/design-database/references/indexing-and-partitioning.md \
        skills/design-database/references/review-template.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 5: `postgres.md` and `oracle.md`

**Story:** none. Idea record: "PostgreSQL and Oracle references first, body engine-agnostic".
**Files:**
- Create: `skills/design-database/references/postgres.md`
- Create: `skills/design-database/references/oracle.md`
- Modify: `skills/design-database/SKILL.md`, to link both

**Depends on:** task 2

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

**Two engines, not five, and the record says why:** writing five engine references on speculation is
content nobody has validated. SQL Server, MySQL, MariaDB and MongoDB are added when a project needs
one. Do not add them here.

- [x] **Step 1: Write the failing test**

Link both from the body.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL on both unresolved links.

- [x] **Step 3: Write the minimal implementation**

Each file carries only what changes an answer on that engine: the type choices that differ, how a
primary key and a sequence or identity are really declared, what partitioning is called and what it
costs, and the one query that answers "how close is this integer key to its ceiling". `postgres.md`
carries the `SERIAL` versus `IDENTITY` question and the logical replication consequence of a missing
primary key, both of which the baseline reached unaided and which the reference exists to make
repeatable.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add skills/design-database/references/postgres.md \
        skills/design-database/references/oracle.md skills/design-database/SKILL.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

### Task 6: `design-architecture` states the seam in its description

**Story:** none. Idea record: "Its description needs the seam stated, or the router picks
arbitrarily and neither skill improves, which is `create-skill` Step 0's warning".
**Files:**
- Modify: `skills/design-architecture/SKILL.md`

**Depends on:** task 1

**Done when:** `tests/run-tests.sh` prints `All test files passed`, and
`tests/validate-skills.sh` reports the description total still under 1,320 tokens.

`design-architecture`'s description currently claims "choosing a stack or datastore", which reads as
covering schema design, and its body says nothing about schema design. That is the router collision
step 0 found. The fix is in the description, not the body.

- [x] **Step 1: Write the failing test**

No new assertion. The existing description-total check at `tests/validate-skills.sh:157` is what this
task must not break, and the per-description 216 character ceiling is what constrains the wording.
Record the current total before editing:

```bash
tests/validate-skills.sh 2>&1 | grep 'descriptions about'
```

- [ ] **Step 2: Run it and watch it fail**

There is nothing to watch fail, and saying so is the honest report. This task is a wording change
whose only mechanical gates are two budgets. **Note it in the handover rather than ticking a step you
did not perform.**

- [x] **Step 3: Write the minimal implementation**

Amend `design-architecture`'s description so datastore choice stays and schema design is visibly not
its job, within 216 characters. The seam the idea record decided: `design-architecture` keeps which
engine and whether a database is the right store at all; `design-database` takes the schema.

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, and the description total reported under 1,320 tokens. Read the
number and put it in the report.

- [x] **Step 5: Hand over**

```bash
git add skills/design-architecture/SKILL.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.**

---

### Task 7: `create-skill` Step 4, re-run the scenario with the skill

**Story:** none. `create-skill` Step 4, and ADR-0001 if the body lands over 700 words.
**Files:**
- Modify: `tests/evals/results.md`
- Modify: `skills/design-database/` as the re-run requires

**Depends on:** tasks 1 to 6

**Done when:** the arm's reply is scored against the four omissions by reading it, the result is
recorded in `tests/evals/results.md`, and `tests/run-tests.sh` prints `All test files passed`.

**This is the task that decides whether the skill works**, and skipping it makes everything above an
assertion. `create-skill` Step 4: the agent should comply while usually finding a new way around the
edge; add that, re-run, repeat. Two or three passes is normal.

**It costs real money and needs saying before it is run.** The Step 1 baseline was `claude-opus-5[1m]`,
8 turns, $1.14, 377 seconds. Expect the same order per pass, and budget for two or three.

- [x] **Step 1: Write the failing test**

The scenario is the test and it already exists as a fixture: the six table payments schema described
in `tests/evals/results.md` under 2026-08-19. **Check the fixture is still on disk before dispatching**,
and if it is not, reconstruct it from that record's description and say in the handover that you did,
because a re-run against a different fixture is not comparable to the baseline.

- [x] **Step 2: Run it and watch it fail**

**Deviation, 2026-08-30: the baseline was re-run rather than cited.** This step said to cite the
2026-08-19 record and not re-run the no-skill arm. That was written before anyone checked whether the
fixture still existed, and it does not. Citing a baseline taken on an artifact that no longer exists,
while running the treatment on a rebuild, compares two different inputs. Both arms were run against
the rebuilt fixture instead. The re-run baseline came back much stronger than the recorded one, which
is a finding in its own right and is written up in `tests/evals/results.md`.

The original text follows. The baseline is the recorded failure, and it is already written down: types never swept,
denormalisation unmentioned, no ERD, partitioning in passing. Do not re-run the no-skill arm. Cite
the 2026-08-19 record.

- [x] **Step 3: Write the minimal implementation**

Stage and dispatch the treatment arm, injecting `design-database`, with the same flags every other
arm uses:

```bash
dir=$(tests/evals/stage.sh <scenario>)
cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json"
```

**If no scenario file exists for this**, add one under `tests/evals/scenarios/` first, following the
shape of `build-with-no-prd.md`, with pass criteria that are the four omissions. Note that adding a
scenario moves `tests/test-doc-claims.sh`'s eval scenario count in `README.md`, which must move in
the same commit.

- [x] **Step 4: Run it and watch it pass**

Score the reply by reading it, against exactly four criteria: every column type swept rather than
sampled, denormalisation named, an ERD drawn, and partitioning stated as a decision with a partition
key and a retention consequence. Scoring is deliberately human; a grep for the section headings is
satisfied by an agent that fills them with nothing.

Where it complies but finds a new edge, add that to the template and re-run. Record every pass in
`tests/evals/results.md`, including the ones that failed, with model, turns, cost and duration.

- [x] **Step 5: Hand over**

```bash
git add tests/evals/results.md skills/design-database
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** Report the cost and the verdict per criterion.

---

### Task 8: Close the idea record and the changelog

**Story:** none. Standing rule: a change lands with the documents it makes wrong.
**Files:**
- Modify: `docs/ideas/database-design-and-review.md`
- Modify: `CHANGELOG.md`

**Depends on:** tasks 1 to 7

**Done when:** `tests/run-tests.sh` prints `All test files passed`.

- [x] **Step 1: Write the failing test**

None. This is a documentation task and the suite has no assertion for a status line, which is
precisely why nine idea records went stale and were corrected on 2026-08-30. Say so in the handover.

- [ ] **Step 2: Run it and watch it fail**

Nothing to watch. Do not tick this box; report it.

- [x] **Step 3: Write the minimal implementation**

Set the idea record's `Status` to `built <date>` and its `Next` to nothing, citing this plan, in the
shape the nine records corrected on 2026-08-30 now use: state what landed, where the evidence is, and
what stayed out. What stayed out is real and must be named: SQL Server, MySQL, MariaDB and MongoDB
references, and the "documenting database objects" half of the original ask, which `write-docs` owns.

Add a `CHANGELOG.md` entry under `## Unreleased`. **Do not touch `VERSION`.**

- [x] **Step 4: Run it and watch it pass**

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Hand over**

```bash
git add docs/ideas/database-design-and-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.**

---

## What this plan does not settle

**Whether the skill earns its place at all.** `create-skill` Step 0 says "no new skill" is a correct
outcome, and this is the second Step 1 baseline to come back showing the model already performs well.
The decision to build was taken on 2026-08-19 on the grounds that the omissions are structural and
that no existing skill owns schema design. **Task 7 is where that decision is testable**, and a
treatment arm that shows no improvement over the baseline is a reason to stop, not a reason to
re-run until it passes.

**The three engines left out.** SQL Server, MySQL and MariaDB get references when a project needs
one. MongoDB is further out than the other three: the template's sections assume a relational model,
and normalisation and column types do not transfer unchanged.

**The "documenting database objects" half of the original ask.** `write-docs` owns producing
documents, and the idea record's step 0 called this partial rather than a gap: nothing says what a
database document must contain. Task 2's template is the closest this plan comes, and it is a review
output rather than a reference document. Left open deliberately.
