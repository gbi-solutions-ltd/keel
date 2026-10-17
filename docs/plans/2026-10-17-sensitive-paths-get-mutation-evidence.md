# Sensitive paths get mutation evidence, and one mechanical answer Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Every task changes skill text and docs and carries no failing test; each behaviour's example is
> the wording or outcome it must produce, checked by the commands in `Done when:` and by a reviewer.

**Goal:** a change to a `hard_block_paths` path is reviewed in more depth, never less. The final
`review-code` mutates every changed decision line in those files and a surviving mutant blocks the
merge; and `review-code`, `security-audit` and `ship` decide whether a change touches those paths
with `keel plan risk`, the same mechanical answer the review loop already uses, instead of each
reading the profile.
**Stories:** none. A change to keel's own process, specified by a decided idea record.
**ADRs:** none written. ADR-0007 keeps the `tdd` cycle uniform, its alternative A (a stricter `tdd`
tier on `hard_block_paths`) included; this plan adds depth in `review-code`, not `tdd`, and only on
those paths. ADR-0002 holds (the coordinator writes no code); ADR-0001 governs the body edits.
**Architecture:** `keel plan risk --range <base>..HEAD` already prints each changed path a
declared pattern matches, then `loop: full` or `loop: light`, reading every profile the hook could
read, and treats a change to `.keel/profile.json` as full. `review-code` runs it with the review's
own base and hands the matched paths to its rubric pass, whose new item 6 makes one mutant per
changed decision line in them, in the throwaway worktree item 5 already uses. `security-audit` and
`ship` read the same command's verdict for "touches `hard_block_paths`".
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** tasks 1 and 2 may run at the same time. Task 3 requires both.
**Batch gate:** after tasks 1 and 2 land, `tests/run-tests.sh` is green.
**Decided:** Bernard, 2026-10-17, choosing among options put to him, recorded as "Decided" item 7 by
task 3: the mutation evidence comes from the independent reviewer in `review-code`, not the author
in `tdd`; every changed decision line in a sensitive file gets one mutant, capped at 10 per review,
and a survivor blocks; `review-code`, `security-audit` and `ship` decide the match with
`keel plan risk --range <merge-base>..HEAD`.
**Shape:** behaviours with examples, as gap 1 decided.
**Reviewed:** by a dispatched plan reviewer on 2026-10-17; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call.
- **Tasks 1 and 2 run in their own git worktrees, outside the repository, and commit there**;
  their `Done when:` is their own checks, and the suite runs once at the join (the batch gate). Task
  3 runs in the shared tree, stages named paths and hands over; the coordinator commits.
- **Records.** Tasks 1 and 2 do not touch `CHANGELOG.md`, `README.md`, `docs/02-skill-catalog.md`
  or the ideas record; task 3 writes them. A reviewer of task 1 or 2 is told so.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only. Never `git add -A`, `git add .` or `git commit -a`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`.
- **Skill bodies.** `review-code` is at 601 words, `security-audit` at 840 and `ship` at 877; each
  stays at or below 900 as `tests/validate-skills.sh` counts it. A body edit to one over 700 words
  owes an ADR-0001 eval arm, recorded as owed in `CHANGELOG.md` by task 3.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number. Validators check line
  citations even in record directories, for range and blank lines, so run
  `tests/validate-citations.sh` after each edit and keep cited lines on their text, or repoint live
  citations by phrase. `docs/02-skill-catalog.md` keeps its 627 lines.
- **Plans are scanned for links.** Write paths in backticks, never as markdown links, in this plan.
- **Every rule carries its reason.**
- Never `sed -i` on this repository's mount: it drops the exec bit. Edit with a read-modify-write.

## What this plan does not build

- **No change to `tdd`.** The author's cycle is the same on every path, as ADR-0007 decided;
  the evidence comes from the reviewer.
- **No mutation tool or profile key.** Mutants are made by hand, one line each, as
  `skills/tdd/references/writing-good-tests.md` "Proving a case can fail, after the fact" already
  describes. A `verify.mutation` command for a project with Stryker, mutmut or PIT is left for
  later.
- **No mutation in the per-task reviews** inside `execute-plan`; it runs once, in the final
  `review-code`, where the whole change is in view.
- **No change to what `hard_block_paths` holds** or to `hooks/sensitive-guard`.
- **No change to the audit's force.** Gap 3's other half, that the audit is required on a
  sensitive diff whatever `gates.security_audit` says, is already met by the current text: under
  any value, `ship` runs the audit on a diff touching `hard_block_paths` and a finding on such a
  path blocks and cannot be overridden in conversation. A finding elsewhere in that diff keeps the
  gate's value (under `warn`, the person decides). Task 2 changes only how the match is decided.

---

### Task 1: `review-code` mutates every changed decision line on a sensitive path

**Story:** none.
**Files:**
- Modify: `skills/review-code/SKILL.md`, `skills/review-code/references/rubric-pass.md`

**Depends on:** none

**Behaviours:**

1. **Step 3 decides the match mechanically.** Before dispatching the rubric pass, the driver finds
   the sensitive files with `keel plan risk`, because a sentence in chat is not a decision and the
   review loop already uses this one:
   - the base is the one the request names, else `git merge-base <default_branch> HEAD`; for
     committed work run `keel plan risk --range $(git merge-base <base> HEAD)..HEAD`, since a
     branch name passed to `--range` would pull in the default branch's own commits; where
     anything is uncommitted, run instead
     ```bash
     git diff -z --no-renames --name-only $(git merge-base <base> HEAD) | xargs -0 keel plan risk --
     ```
     which covers the commits and the uncommitted edits together, and an empty list means no
     sensitive files (calling it with no paths would fall back to `--staged`); read stdout only,
     since `keel` writes notes to stderr;
   - on exit 0 and `loop: full`, the paths printed before the `loop:` line are the sensitive files;
     on `loop: light`, there are none;
   - if a printed path is a `.keel/profile.json` (or a path ending `.keel`), every changed
     production file counts as sensitive and the report says so, because a change cannot lower its
     own review by editing the list that judges it;
   - on any other exit, every changed production file counts as sensitive and the report says so,
     because failing to decide is never a reason to review less;
   - without `keel`, a project whose profile declares no `hard_block_paths`, on the default branch
     and in the working tree, has none; anything else counts every changed production file as
     sensitive.
   The body stays at or below 900 words; detail that does not fit goes in `rubric-pass.md`.
2. **The brief hands them over.** `rubric-pass.md`'s "What the driver must hand over" gains the
   sensitive files and `verify.test_one` with its placeholder unfilled, and the prompt gains
   `Sensitive paths: <the files, or none>` and that command. The prompt's "do not run it again,
   except through item 5's revert check" also allows item 6, and item 6 runs before the worktree is
   removed. Step 3's "five checks" becomes six.
3. **Item 6, mutation evidence.** The prompt gains a sixth check, in substance: for each changed
   decision line in a sensitive file that is production code, make one mutant in the same
   throwaway worktree item 5 uses (creating it as item 5 says if item 5 made none), run the covering
   test, record killed or survived, restore.
   - **Production code** is a file some test runs. Tests, docs, `*.json`, `*.yml`, `*.yaml` and
     `*.toml` are not, and are listed as unchecked with the reason "no test runs it". keel's own
     list is the example: `hooks/*` counts; `settings.json`, `.github/workflows` and
     `templates/ci-review.yml` do not.
   - **A decision line** is a condition, comparison, guard, early return, boolean operator or
     boundary constant. One example per language, with its mutant: shell `[ "$n" -ge 3 ]` to `-gt`,
     `|| exit 1` removed, a `case` arm removed; awk `NR > 1` to `NR > 2`; Python `if a and b` to
     `or`; TypeScript `===` to `!==`, `??` removed.
   - **The covering test** is the test file the diff changed for that source, else the one named
     after it (`tests/test-<name>.sh`, `test_<name>.py`, `<name>.test.ts`), run with
     `verify.test_one`; else `verify.test`.
   - **The cap:** at most 10 mutants per review, in diff order, and at most 3 where only
     `verify.test` can run them, because each then costs a whole suite run. Every decision line
     left unchecked is named; those are reported, not findings, so the cap never becomes a block.
   - With no sensitive file, item 6 reports `not applicable: no hard_block_paths path changed`.
   The reason is stated: these are the paths a mistake costs most on, and a test that cannot fail
   on a changed guard is no evidence (cite `skills/tdd/references/writing-good-tests.md` by its
   heading phrase "Proving a case can fail, after the fact").
4. **A survivor blocks.** A surviving mutant is reported as a Blocking finding naming the line, the
   mutation and the case that would kill it, because nothing in the suite observes that line's
   behaviour on a path the project marked sensitive. Example in the brief:
   `| src/auth/session.ts:42 | >= to > | npm test -- session.test.ts | survived |` becomes the
   finding "no case pins a session expiring exactly at its limit".
5. **The report carries the evidence.** The prompt asks for a table, `| file:line | mutation |
   command | killed or survived |`, one row per mutant, and the unchecked lines after it, so the
   evidence is read, not asserted.
6. **The re-review re-runs it.** Step 5's re-review after a fix pass runs item 6 afresh, the
   round's survivors first: each must now die, and a decision line the fix adds gets its own
   mutant, because a fix for a survivor is a new test whose power to fail is the whole point.

**Done when:** all of these, in this task's worktree:
- `tests/validate-skills.sh` prints `OK`, with `review-code` at or below 900 words.
- `tests/validate-citations.sh` and `bash tests/test-doc-claims.sh` pass.
- `grep -c 'plan risk' skills/review-code/SKILL.md`, `grep -c 'six checks'
  skills/review-code/SKILL.md` and `grep -c 'Sensitive paths'
  skills/review-code/references/rubric-pass.md` each print at least 1.
- A reviewer finds behaviours 1 to 6, with the examples.

- [x] **Step 1.1: Edit `review-code` step 3** for behaviour 1.
- [x] **Step 1.2: Edit `rubric-pass.md`** for behaviours 2 to 6.
- [x] **Step 1.3: Check and commit.** You are in your own worktree, so this task commits rather than Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 2 in worktree g3-t1; spec DEVIATES (re-review unreachable from step 5, keel example missing), one fix pass amended to 8707650, second spec COMPLIES; review-code 601 to 881 words
  handing over. Run the `Done when:` checks, then:
  ```bash
  git add skills/review-code/SKILL.md skills/review-code/references/rubric-pass.md
  git commit -m "feat(skills): review-code mutates every changed decision line on a sensitive path"
  ```

---

### Task 2: `security-audit` and `ship` read the match from `keel plan risk`

**Story:** none.
**Files:**
- Modify: `skills/security-audit/SKILL.md`, `skills/ship/SKILL.md`
- Create (only if behaviour 4 needs it): `skills/security-audit/references/sensitive-match.md`

**Depends on:** none

**Behaviours:**

1. **`security-audit` step 1** decides whether the diff touches a `hard_block_paths` path with
   `keel plan risk --range <base>..HEAD`, `<base>` being `git merge-base <default_branch> HEAD`, the
   base `ship` opens the pull request against; where anything is uncommitted, the same
   `git diff -z ... | xargs -0 keel plan risk --` form task 1 uses, since `ship` runs this gate
   before committing and `security-audit` runs on its own. `loop: full` means it does, and the paths
   it printed are the sensitive ones; a printed `.keel/profile.json` (or a path ending `.keel`)
   makes every changed file sensitive. Any other exit is read as touching, and the report says so,
   because a change cannot lower its own audit and failing to decide is never a reason to audit
   less. Without `keel`, a profile declaring no `hard_block_paths`, on the default branch and in the
   working tree, means no match; anything else is read as touching. `gates.security_audit` is still
   read from the default branch where the diff changes it, so a branch cannot switch off its own
   audit.
2. **A finding's path** is on a sensitive path when its file is among the paths step 1's run
   printed, or step 1 printed a profile path, or step 1 could not decide. There is no separate call
   per path, because `keel plan risk <path>` reads only the working tree's profile, which the
   change under audit may have relaxed.
3. **`ship` check 4** says the `hard_block_paths` match is the one `security-audit` reads from
   `keel plan risk`, and keeps reading `gates.security_audit` from the default branch where the diff
   changes it. Only the `hard_block_paths` half of "Read both keys from the default branch where the
   diff changes either" moves. `ship` stays at or below 900 words (877 now).
4. **Room.** `security-audit` has 60 words of headroom; if behaviours 1 and 2 do not fit, the match
   rule moves to a new `skills/security-audit/references/sensitive-match.md`, linked from step 1,
   and that file is added to this task's commit.

**Done when:** all of these, in this task's worktree:
- `tests/validate-skills.sh` prints `OK`, with `security-audit` and `ship` at or below 900 words.
- `tests/validate-citations.sh` and `bash tests/test-doc-claims.sh` pass.
- `grep -c 'plan risk' skills/security-audit/SKILL.md` and the same in `skills/ship/SKILL.md` each
  print at least 1.
- A reviewer finds behaviours 1 to 4.

- [x] **Step 2.1: Edit `security-audit`** for behaviours 1, 2 and 4.
- [x] **Step 2.2: Edit `ship` check 4** for behaviour 3.
- [x] **Step 2.3: Check and commit.** You are in your own worktree, so this task commits rather than Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 1 in worktree g3-t2; spec COMPLIES, four minor notes carried to review-code; match rule moved to references/sensitive-match.md; committed 1be82ec; joined by merges d6d2c1d and 1bfa92d, run-tests.sh at the join witnessed by me, all passed
  handing over. Run the `Done when:` checks, then:
  ```bash
  git add skills/security-audit/SKILL.md skills/ship/SKILL.md
  git commit -m "feat(skills): the audit reads its sensitive-path match from keel plan risk"
  ```

---

### Task 3: the batch's records

**Story:** none.
**Files:**
- Modify: `CHANGELOG.md`, `docs/02-skill-catalog.md`, `docs/ideas/delivery-flow-gaps.md`,
  `templates/profile.schema.json`, `docs/profile-keys.md`, `docs/standards.md`

**Depends on:** tasks 1 and 2

**Behaviours:**

1. **`CHANGELOG.md`:** one Unreleased entry for tasks 1 and 2, with the owed ADR-0001 arms for the
   `security-audit` and `ship` body edits, and for `review-code` if it ends over 700 words, with
   their word counts.
2. **Catalog:** the `review-code` entry says a change to a sensitive path gets one mutant per
   changed decision line and a survivor blocks; the `security-audit` entry says the match comes from
   `keel plan risk`. The file keeps 627 lines.
3. **Records:** `docs/ideas/delivery-flow-gaps.md`:
   - Status names gap 3 built by this plan, with tasks 1 and 2's commits and task 3's title, and
     says every gap in the decided order is now built;
   - Next says what remains: the short path without a plan (gap 4's unbuilt half), the owed eval
     arms, and measuring the changes against `keel plan report` on real work;
   - the gap 3 section gets "**Built 2026-10-17**, see Status. What follows is the state before it
     was built.";
   - "Decided" gains item 7 with Bernard's three answers, and notes that the audit half was already
     met (see this plan's "What this plan does not build").
4. **The key's readers:** `hard_block_paths`'s description in `templates/profile.schema.json` names
   its new readers (the `review-code` mutation step and the audit's match), and its `x-keel-read-by`
   adds `advisory:skills/review-code/references/rubric-pass.md#<phrase>` and
   `advisory:skills/security-audit/SKILL.md#<phrase>`, each phrase free of `|`;
   `docs/profile-keys.md` is regenerated with `tests/generate-profile-keys.sh`, never edited by
   hand.
5. **The standard:** `docs/standards.md`'s line saying `review-code` step 3 "names the five checks
   it carries" says six.

**Done when:**
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- `tests/validate-skills.sh` prints `OK` (the profile-keys page matches the schema).
- A reviewer finds behaviours 1 to 5.

- [x] **Step 3.1: Write the records** for behaviours 1 to 5.
- [x] **Step 3.2: Check and stage.** Run the `Done when:` checks, stage the changed files by path, Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; spec COMPLIES; records for the batch at its join, profile-keys regenerated; doc-claims, citations and skills validators checked by implementer and reviewer
  show `git status --porcelain`, and stop. The coordinator commits, with this plan:
  `docs: records for gap 3, sensitive paths get mutation evidence`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-17. Applied: a change that edits the profile now
counts every changed production file as sensitive in `review-code`, where the draft would have
mutated nothing; a finding's path is judged from step 1's range run, not a per-path call that reads
the relaxed working-tree profile; `ship` keeps reading `gates.security_audit` from the default
branch; the base and the uncommitted case are spelled out; without `keel`, a profile with no list
means no sensitive paths, so a project without the list is not mutated or audited on every change;
"production code", "decision line" and "covering test" get rules and examples per language; the
brief hands over the unfilled `verify.test_one`, item 6 runs before the worktree goes and the step
says six checks; the re-review re-runs the mutants; unchecked lines are reported, not findings;
the audit half of gap 3 is recorded as already met; the profile key's readers are recorded; and the
ADR-0007 sentence says what that ADR actually decided. A second review then made the audit's match
cover uncommitted work too, as `review-code`'s does, with the exact command; gave both tasks the
same profile rule; made the reference file conditional; named the `x-keel-read-by` form; and added
the standard that names `review-code`'s checks.
