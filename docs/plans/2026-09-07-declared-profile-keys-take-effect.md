# Every declared profile key either takes effect, or says it does not: Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** every key `templates/profile.schema.json` declares either has a reader that changes
behaviour, or says in the generated reference that it does not, and a validator rule keeps it that
way.

**Stories:** none. `keel:write-user-stories` was skipped deliberately: the input is Bernard's brief
of 2026-09-07 plus `docs/ideas/declared-profile-keys-take-effect.md`, which carries the problem,
the evidence and the case against. Each task below traces to a row of that record's verdict table
instead of to a story id. Recorded here rather than left for a reader to notice.

**ADRs:** ADR-0001 (body budgets), ADR-0003 (gate availability from a capability manifest),
ADR-0004 (a guarantee belongs to a repository and harness pair), ADR-0007 (rejected 2026-09-07).

**Architecture:** the 22 keys split five ways, and the sentence that used to be here said three and
did not add up. Six are retired, four are wired, nine are declared human-read, one
(`gates.coding_standards`) stays declared and unread, and **two** the census wrongly called dead
were already read. Six plus four plus nine plus one is 20, which is the number of keys read by
nothing; the other two are `stack.package_manager` and `verify.test_integration`, and the verdict
table gives both the reason "The census was wrong". The earlier sentence reached 22 by saying three
rather than two and by giving `gates.coding_standards` no bucket at all. Corrected 2026-09-09. A new schema field,
`x-keel-read-by`, records which of those a key is, and `tests/validate-skills.sh` checks that the
reader it names still exists. That field replaces the dotted-path matcher the brief proposed, which
was prototyped and measured at 28% false positives before it was rejected.

## The verdict table

Twenty-two keys, one verdict each. `harnesses` is stated for every `gates.*` key, per ADR-0004.

| # | Key | Verdict | Mechanism | Harnesses | Reason |
|---|---|---|---|---|---|
| 1 | `gates.tdd` | **retire** | n/a | n/a | The only wiring ever proposed, `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:419-420`, defined `required` as "the tiers apply with the strict list binding". It was tiering's carrier and fell with it. See the ADR-0007 finding below |
| 2 | `gates.coding_standards` | **wire, advisory. Not built here** | The `=== PROJECT STANDARDS ===` block at `skills/execute-plan/references/subagent-prompts.md:29` | both, advisory | `docs/ideas/standards-that-bind.md:488-510` already ranks this, third of six, behind two zero-body-word mechanisms. Task 6 leaves the key in the schema and marks it `unread:` pointing at that record. Building it here would open a competing record |
| 3 | `gates.review` | **retire** | n/a | n/a | `skills/ship/SKILL.md` names no `gates.*` key and its step 5, "`review-code` has run and nothing blocking remains", is unconditional. A key whose only possible effect is to weaken a gate the skill runs anyway is a key whose `off` value is a lie |
| 4 | `gates.observability` | **retire** | n/a | n/a | No mechanism is proposed anywhere in the tree, and the census found no reader, no named reader and no idea record |
| 5 | `gates.docs_updated` | **retire** | n/a | n/a | Same as `gates.review`. `skills/ship/SKILL.md` step 6 is unconditional |
| 6 | `plugins.excluded` | **wire** | `plugin_report` in `lib/harness/claude.sh` | **claude only** | `plugins.recommended` is read at `lib/harness/claude.sh:63` and there is no Codex counterpart of that report. ADR-0004: the description must say so, and task 4 writes it |
| 7 | `conventions.working_branch` | **retire** | n/a | n/a | The brief's proposed home does not work: the push guard at `bin/keel:1640-1650` protects `default_branch` and already permits a push to any other branch, so reading `working_branch` there would change nothing |
| 8 | `deploy.target` | **human-read** | n/a | n/a | See the deploy set, below |
| 9 | `observability.log_shipping` | **retire** | n/a | n/a | `observability.backend` already makes the distinction: `none` in the table at `skills/coding-standards/references/observability.md:19-24` is "Structured logs to stdout only". The key appears only inside that file's JSON example at `:11-17` and nothing branches on it |
| 10 | `notes` | **human-read** | n/a | n/a | It was written for a skill to read and no skill can afford to: `hooks/session-start` has 4 characters of headroom against the 1,285 limit at `tests/validate-skills.sh:522`. The corrected description says plainly that no skill reads it |
| 11 | `project.name` | **human-read** | n/a | n/a | Written by `bin/keel:505`, read by nothing. "used in generated documents and reports" is the false half |
| 12 | `project.description` | **human-read** | n/a | n/a | "Skills quote it at the top of a snapshot or a PRD" is false; no skill names it. The rest of the description, "Left empty by init because only a human knows the answer", is already the human-read case |
| 13 | `stack.package_manager` | **already wired, description corrected** | `bin/keel:853-856` | n/a | The census was wrong: init branches on empty against set to decide whether to print its note. "Skills prefix commands with it" is the false half |
| 14 | `stack.datastores` | **human-read** | n/a | n/a | Detected by `lib/detect-stack.sh` and written by `bin/keel:508`; no skill reads it back. "Skills use it to know which failure modes are worth asking about" is false |
| 15 | `verify.e2e` | **wire** | `cmd_doctor` reports it without running it | all, harness-neutral | Class C: written into every profile by `bin/keel:516` and read nowhere, so the evidence of wiring is in the user's own file. Cheapest real win in the list |
| 16 | `verify.test_integration` | **already wired. No change** | `skills/tdd/SKILL.md:31` and `:67` | both, advisory | The census was wrong. "Where a behaviour touches persistence, test against a running database. Use `verify.test_integration` from the profile" is a real branch. Its description is accurate |
| 17 | `gates.security_audit` | **wire, advisory** | A branch in `skills/security-audit/SKILL.md` step 5 | **both**, advisory | The one true named-but-not-branched case: `:23` fetches the value and nothing acts on it. No hook is involved, so ADR-0003's manifest does not bind; skill bodies load identically on both harnesses |
| 18 | `deploy.ci` | **human-read** | n/a | n/a | See the deploy set, below |
| 19 | `deploy.registry` | **human-read** | n/a | n/a | See the deploy set, below |
| 20 | `deploy.envs` | **human-read** | n/a | n/a | See the deploy set, below |
| 21 | `deploy.secrets_manager` | **human-read** | n/a | n/a | See the deploy set, below |
| 22 | `verify.security` | **wire** | `cmd_doctor` reports it without running it | all, harness-neutral | Class C, with `verify.e2e` |

**The deploy set, one verdict for the five.** `setup-deployment` is the named reader in four of the
five descriptions and cannot become one: its body is 695 words against ADR-0001's 700 target, five
words of headroom, and `CONTRIBUTING.md` requires a passing eval arm at any length over 700.
`deploy.target`, `.ci` and `.envs` are detected by `keel init` and proposed by a snapshot
(`skills/repo-snapshot/references/section-templates.md:249-250`); `.registry` and
`.secrets_manager` exist so a pipeline and a runbook agree on one value, which is a person's job by
construction. All five become human-read and their descriptions stop naming `setup-deployment`.
**The alternative, rejected:** a `cmd_doctor` warning when `deploy.ci` is null and a CI config
exists. Cheap and testable, but nobody asked for it and `lib/detect-stack.sh:220` already detects
`ci` at init. Recorded in the idea record's open question 2 so the decision is not silently made.

**Three keys the brief's provisional table raises that are outside its 22.** `verify_notes` is
human-read and its description already says so correctly, so it gets a marker and no prose change.
`stack.runtime` is human-read and its description makes no false claim.
`observability.otlp_endpoint_var` is **human-read**, corrected during execution on 2026-09-07: the
plan first called it advisorily read at `skills/coding-standards/references/observability.md:30`,
"Gate export on the endpoint being set". That line never names the key and nothing in the tree
resolves the key to a variable name. Its only shipped appearance is `:14`, inside an illustrative
JSON block, which is exactly where `observability.log_shipping` appears one line below at `:15`.
Identical evidence cannot carry opposite verdicts, and a change that exists to remove over-claims
must not ship a fresh one. It is not retired with `log_shipping` because it is not redundant:
nothing else records which environment variable holds the endpoint.

**Keys we are recommending be retired rather than wired, as one list:** `gates.tdd`,
`gates.review`, `gates.observability`, `gates.docs_updated`, `conventions.working_branch`,
`observability.log_shipping`. Six.

### The ADR-0007 finding, in full, because `gates.tdd` cannot be retired without it

The brief requires this stated before any `gates.tdd` verdict. ADR-0007 proposed tiering TDD rigour
by what the code does, and was rejected on 2026-09-07. Its Decision gives five grounds, and the ADR
names which two decided it: "reasons 1 and 2 are the discriminating ones. A cheaper cycle removes
most of what tiering was for, and what is left costs twice the words the body has"
(`docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md:99-101`). Reason 1 is that
ADR-0006 already cut cycle cost (`:35`); reason 2 is that `skills/tdd/SKILL.md` has 31 words of
headroom against the 60 to 80 tiering needs (`:42-44`).

**Whether a project-wide floor survives those grounds, or fell with the tiering.** It fell. The only
wiring ever specified is task 7 step 4 of `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`,
at `:419-420`: "Wire `gates.tdd` as the project-wide floor the skill reads: `required` means the
tiers apply with the strict list binding". `required` there *means* the tiers; the step has no
existence apart from them, and its task is stamped closed at `:382`. The nearest tiering-free shape,
Alternative A, was considered on its own and declined "on reasons 2 and 3"
(`ADR-0007:79-82`). So no untiered floor survives: none was ever proposed, and the closest thing to
one was refused for the same budget-and-sequencing reasons.

The brief's rule is then decisive: "If it fell, the verdict is retire, not wire."

**The tension, stated rather than buried.** `ADR-0007:110-113` records that "`gates.tdd` stays
declared and unread", and that consequence is one day old. Retiring the key does not contradict it:
the ADR records that *wiring* does not happen, not that the key must exist, and `ADR-0007:134-141`
already holds the two conditions that would reopen the question. An ADR is where intent lives; a
schema is a contract of what takes effect, and "Declared so the intent has somewhere to live once
something enforces it" is the sentence that produced this entire defect class. Task 7 appends a
dated line to ADR-0007 saying so. **This is the verdict Edrine's review should look at hardest.**

### The capability answer for every `gates.*` key in scope

**No `gates.*` schema key is a capability-manifest gate.** `lib/harness/capabilities` carries four
`requires` rows, for `session-start`, `done-guard`, `context-watch` and `sensitive-guard`, and none
of `gates.tdd`, `.coding_standards`, `.review`, `.observability`, `.docs_updated` or
`.security_audit` appears in one. ADR-0003 therefore binds only if one of them becomes a hook, and
none of the wirings in this plan does.

Two mechanisms are used, and each carries a different guarantee under ADR-0004:

- **`cmd_doctor`** is a CLI path. It runs identically wherever `keel` runs, touches no hook event,
  and is outside the manifest. Harness-neutral. Used for `verify.e2e` and `verify.security`.
- **Skill prose** loads from the same `skills/` tree on both harnesses, so it reaches Claude Code
  and Codex alike. It is **advisory and not a guarantee**: nothing asserts it at runtime. Used for
  `gates.security_audit`, and `docs/profile-keys.md` will say the word advisory beside it.

The one axis on which a harness split would appear is a gate escalated to a hook that puts a
command to a human. That needs `pretooluse_ask`, which Codex does not provide
(`lib/harness/codex.sh:5-6`, citing the vendor's own `permissions.rs`), and it is why
`sensitive-guard` is Claude Code only. **No task here proposes one.** `plugins.excluded` is the
single Claude-only wiring, and for a different reason: `plugin_report` lives in
`lib/harness/claude.sh` and has no Codex counterpart.

## Global constraints

Copied in full rather than linked. A task executed by a fresh agent that reads only its own section
must still obey them.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  `verify.format`, `verify.typecheck` and `verify.build` are `null` in this project.
- Never start on `main`. This work is on `profile-keys-take-effect-or-say-they-do-not`, off `sandbox`.
- **Never hand-edit `docs/profile-keys.md`.** It is generated. Change the schema and run
  `tests/generate-profile-keys.sh > docs/profile-keys.md`. `tests/validate-skills.sh:612-640`
  fails when the two disagree and names that command.
- **A field-set change bumps `SCHEMA_VERSION` in `bin/keel` and adds a line to
  `schema_fingerprint_for` in `tests/validate-skills.sh:82-88`, in the same commit.** Never edit an
  existing line: `tests/validate-skills.sh:699` says why, and it is a released version's record.
  A **description** change is not a field-set change: the fingerprint at
  `tests/validate-skills.sh:668-680` hashes property paths only, so tasks 1 to 5 move nothing.
- `docs/profile-keys.md` is in scope for the unregistered-harness-claim scan
  (`tests/test-harness-claims.sh:139-147` puts depth-1 `docs/*.md` in scope). **A description
  containing `done-guard`, `sensitive-guard`, `context-watch`, `session-start`, `900-word`,
  `word ceiling`, `description budget` or `hard_block_paths` needs a `CLAIMS` entry in
  `tests/generate-profile-keys.sh#print("# Profile keys")`, or the build goes red.** No description written by this
  plan uses one of those words. **The Read by column task 2 adds does**: three of its citations
  name `hooks/session-start` and `hooks/done-guard`, so task 2 adds three `CLAIMS` entries for
  them. If a later task finds it needs another, add the tag rather than rewording the citation
  around the check.
- ADR-0001: a skill body over 700 words owes a passing eval arm recorded in
  `tests/evals/results.md` at that length. Only task 5 touches a body, and it lands at 688,
  so it owes none.
- `CONTRIBUTING.md`: a skill body change goes through `keel:create-skill`, baseline first.
- **No em dashes and no en dashes**, in code, comments, prose or commit messages.
- Every rule states its reason, naming the failure. "Six of ten delegation rows were false" is the
  shape that survives an argument.
- `tests/validate-citations.sh` applies to every document this plan touches. A `path:line` written
  here must still point at non-blank content when the task lands.

**Concurrent batches: none.** Tasks 3, 4 and 6 all modify `bin/keel`; tasks 3 and 4 both modify
`tests/test-keel.sh`; and every task from 2 onward edits `templates/profile.schema.json`, which is
shared config and disqualifies a batch under rule 3 of the template. Sequential, and said here
rather than left to be discovered.

---

### Task 1: Correct every description that implies enforcement it does not have

**Traces to:** verdict rows 8 to 22, and the three keys outside the 22.
**Files:**
- Modify: `templates/profile.schema.json` (eleven deletions, no additions)
- Modify: `docs/profile-keys.md` (**generated, never by hand**)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new. Description text only; no key is added, removed, renamed or moved, so
  `SCHEMA_VERSION` does not move and `schema_fingerprint_for` gains no line.

**Depends on:** none

**Done when:** `tests/validate-skills.sh` passes, and `tests/test-harness-claims.sh` passes.

**Why this lands alone and first.** It is the largest share of the harm and the cheapest fix:
eleven descriptions imply a reader that does not exist, and deleting one changes no field set, needs
no eval arm and costs no body words. Landing it separately means that if nothing else in this plan
is approved, the schema no longer claims anything false. Tasks 3 to 5 add the true reader back to
the keys they wire, in the commit that makes it true.

- [x] **Step 1: Write the failing test**

There is no unit test for description text, and inventing one would read as coverage. The test is
the existing generated-page check, which fails while the page and the schema disagree. Make it fail
by editing the schema and not the page.

In `templates/profile.schema.json`, in `project.name`, delete the four words `, used in generated
documents and reports` so the description opens `Name of this project. keel init takes it...`.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/validate-skills.sh`
Expected: FAIL, "docs/profile-keys.md disagrees with templates/profile.schema.json: a stale
description for project.name. Regenerate it with tests/generate-profile-keys.sh"

- [x] **Step 3: Write the minimal implementation**

**Every edit in this task is a deletion. Nothing is added, anywhere.** Delete the quoted clause and
close the gap so the surrounding sentences still read. Add no replacement sentence, no reader claim,
no consequence clause, and no word that was not already in the file.

**Why deletion only, and this is the whole design of the task.** The defect the brief names is that
14 descriptions "imply enforcement they do not have". The defect is the false implication, so
removing it is the entire fix. Stating the true reader instead is a second, harder job, and task 2
does it once, mechanically, in `x-keel-read-by` with a citation the validator checks and a **Read
by** column the generator renders. A description that also asserts a reader is a second copy of that
fact, hand-maintained, in the one file about to get a checked one. Four attempts at this task were
rejected, each on a different false reader-claim written into this table, and the last was refuted
by the row next to it. `docs/standards.md` has the general form of this rule at "One definition per
verify command".

| Key | Delete exactly this | Leaving |
|---|---|---|
| `project.name` | `, used in generated documents and reports` | "Name of this project. keel init takes it from the directory name; change it where the directory is not what the project is called." |
| `project.description` | ` Skills quote it at the top of a snapshot or a PRD, so a reader who has never seen the repository knows what they are looking at.` | "One line saying what this project is for, in the terms its users would use. Left empty by init because only a human knows the answer." |
| `stack.package_manager` | ` Skills prefix commands with it, so a wrong value produces commands that do not run.` | "How dependencies are installed and scripts are run, such as pnpm, poetry or cargo. A project with no package manager gets the string none rather than null." |
| `stack.datastores` | ` Skills use it to know which failure modes are worth asking about: a service with postgres has migrations and transactions to reason about, one with none does not.` | "Datastores this project talks to, detected from declared dependencies." |
| `verify.e2e` | `, so a skill may run the unit suite and skip this one` | "The command that runs end-to-end tests against a running system. Separate from verify.test because it usually needs an environment." |
| `deploy.target` | ` setup-deployment reads it to know which pipeline shape applies.` | "Where this project runs once shipped, such as kubernetes, lambda or a plugin marketplace. null means it has not been decided, which is different from having no deployment." |
| `deploy.ci` | `, and setup-deployment proposes one rather than assuming` | "The CI system that runs this project's pipeline, such as github-actions or gitlab-ci. null means there is none yet." |
| `deploy.envs` | ` Skills use the order to know what promotes to what.` | "The environments this project deploys to, in promotion order, such as staging then production. An empty list means it deploys nowhere yet." |
| `observability.log_shipping` | ` It decides whether generated code configures an exporter or simply writes to stdout.` | "How logs reach the backend: otlp to export them directly, stdout to let the platform collect them, none where nothing is shipped." |
| `notes` | ` a skill should know` | "Project facts that nothing else records." |
| `gates.security_audit` | ` warn elsewhere reports findings without blocking.` | "Whether security-audit must run before a change ships. required on anything touching money, credentials or personal data." |

Eleven deletions, and every one is a clause claiming a reader that does not exist. Each was checked
against `bin/`, `lib/`, `hooks/`, `skills/`, `agents/`, `templates/` and `output-styles/` on
2026-09-07 under all six read shapes, including a parent-map read such as
`skills/coding-standards/references/seed.md:19` reading the whole `stack` map and
`skills/setup-deployment/SKILL.md:30` reading the whole `profile.verify` map. None of them resolves
any of these eleven leaves to a decision.

`gates.security_audit`'s clause goes because nothing branches on the value, so `warn` does not
report without blocking any more than `required` blocks. Task 5 makes that sentence true and puts
it back.

**Every other key in the schema is untouched by this task**, including `stack.runtime`,
`verify.security`, `verify_notes`, `observability.otlp_endpoint_var`, `deploy.registry`,
`deploy.secrets_manager`, `plugins.excluded`, and the five keys task 6 retires. None of them
carries a false reader claim, so none of them has a clause to delete, and adding a true one is
task 2's job.

Then regenerate the page:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/validate-skills.sh`
Expected: PASS, with the "OK 25 skills validated" summary line and no FAIL rows. The six WARN rows
for skill body length are pre-existing and this task touches no skill body.

Run: `tests/test-harness-claims.sh`
Expected: PASS. In particular "docs/profile-keys.md matches its generator" and "no unregistered
harness claim in a document in scope". If the second fails, a description used one of the eight
vocabulary words listed in the global constraints; add a `CLAIMS` entry in
`tests/generate-profile-keys.sh` rather than rewording to dodge the check.

Run: `tests/run-tests.sh`
Expected: PASS. Nothing else may break.

**Every box above is ticked on output the coordinator read in a subagent's report, not on work the
coordinator watched.** Steps 1 to 5 were performed by the implementer of the fourth attempt; the
step 2 failure (`524 passed, 2 failed`, the two message cases, no `verify.e2e` or `verify.security`
line in the doctor output) and the step 4 passes (`526 passed, 0 failed`, four new cases) are
quoted from that report and were reproduced independently by both reviewers. The marker sweep and
the two repaired comments were re-verified by the coordinator directly.

**Two follow-ups this task consciously does not do**, raised by the code-quality pass and judged
not worth a fifth cycle:

1. **`verify.security`'s description lost its scar.** It used to end "security-audit then does its
   own reading rather than reporting a clean scan that never ran". It now ends "security-audit does
   its own reading either way". The behaviour survived and the reason did not, which grazes
   `docs/standards.md`'s rule that a rule carries its reason. Repairing it is a description edit
   plus a regenerate, and nothing else.
2. **`verify.e2e`'s description lost "Separate from `verify.test` because it usually needs an
   environment."** The new text implies the need without saying why the key exists apart from
   `verify.test`, which is the question a reader of the generated page arrives with.

Both are one commit together and neither blocks anything. Recorded here rather than carried in a
head, because the fifth attempt that would have fixed them is the one this task declined to run.

- [x] **Step 5: Hand over**

```bash
git add templates/profile.schema.json docs/profile-keys.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -m "docs(profile): every key description says what actually reads it"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

---

> **Ticked 2026-09-07 by the coordinator, with two things a reader needs to know.** The implementing
> subagent completed the work and staged it, then its process died on a network error before it
> reported, so **no implementer report exists for this task**. Steps 1 and 3 are ticked on the diff,
> which is proof of the outcome: all eleven deletions verified word by word against `HEAD`, key set
> and document order unchanged, nothing added. **Step 2's failure was reproduced by the coordinator
> after the fact, not witnessed by the implementer in order.** Restoring `HEAD`'s
> `docs/profile-keys.md` against the edited schema produces the expected FAIL naming all eleven
> keys, so the drift guard genuinely fires; nobody saw it fire before the fix. Step 4 was re-run by
> the coordinator and by the reviewer independently, both green.
>
> This task took five implementation attempts. Four were rejected, each on a different false
> reader-claim in prose the table prescribed, and the design changed to deletion-only after the
> fourth. The record is in the commits between `ff7d862` and `58d7355`.

---

### Task 2: A declared reader on every key, and a validator rule that checks it

**Traces to:** the idea record's recommendation, "Replace the proposed checker".
**Files:**
- Modify: `templates/profile.schema.json` (add `x-keel-read-by` to all 61 leaf entries)
- Modify: `tests/validate-skills.sh` (the new rule, and the row regex at `:628`)
- Modify: `tests/test-validate-skills.sh` (eleven pinned cases, **and `profile_keys_fixture` at
  `:623-632` plus its four call sites, which build four-column rows and must build five**)
- Modify: `tests/generate-profile-keys.sh` (a "Read by" column, and three new `CLAIMS` entries)
- Modify: `tests/test-profile-keys.sh` (one case: the column is populated for every row)
- Modify: `docs/profile-keys.md` (**generated**)
- Modify: `CONTRIBUTING.md` (one bullet under "The rules the validator enforces")
- Modify: `CHANGELOG.md` (one citation renumbered: it cites a line of
  `tests/test-profile-keys.sh` that this task's new case pushes further down the file)
- Modify: `docs/plans/2026-08-31-release-operations-and-claims-audit.md`,
  `docs/plans/2026-08-18-usable-profile.md`,
  `docs/plans/2026-08-18-context-window-at-init.md` (five citations into `CONTRIBUTING.md`
  repointed by section name; see the note below)

**Adding the CONTRIBUTING bullet shifts every line below it, and three plan documents cite
`CONTRIBUTING.md` by line number.** Only a shift of 0, 1, 2, 8 or 11 lines leaves all three on
non-blank content, and the natural four-line wrap of this bullet is not one of them, so
the "Do not touch `VERSION`" paragraph of
`docs/plans/2026-08-31-release-operations-and-claims-audit.md` goes red. Repoint it the way
`tests/validate-citations.sh` prescribes in its own failure message, by dropping the line number and
naming the section instead: "Established from the Releases section of `CONTRIBUTING.md`". Do not
pick a bullet length to dodge the collision; a wrap width chosen to keep a citation green is a
citation that will break on the next edit anyway.

**The collision is five sites across three plan documents, not one, and all five are repaired
here.** Line 125 of `CONTRIBUTING.md` is cited from `docs/plans/2026-08-18-usable-profile.md` twice, from
`docs/plans/2026-08-18-context-window-at-init.md` once and from
`docs/plans/2026-08-31-release-operations-and-claims-audit.md` once; lines 145 to 146 are cited from
the last of those. All five already named content that had moved, and passed only because
`tests/validate-citations.sh` checks that the first cited line is not blank, which its header says
is deliberate: the phrase-matching fourth rule was measured at a 70% false positive rate and thrown
away. The nine-line bullet lands both of those lines blank, so they go red.

Repair all five the way the checker prescribes in its own failure message, by dropping the line
number and naming the section: "the Commits and review section of `CONTRIBUTING.md`", "the Testing
against a real repository section of `CONTRIBUTING.md`". **Do not choose a bullet width that keeps
them green.** The permitted widths are 0, 1, 2, 4, 6, 8, 10, 11, 13 and 15 lines, and picking one
would be keeping green five citations this plan has already established point at the wrong content.
Add the two 2026-08-18 plans to the Files list.

**Interfaces:**
- Consumes: the corrected descriptions from task 1.
- Produces: the `x-keel-read-by` grammar, consumed by tasks 3 to 6, which flip their own keys'
  entries as they wire or retire them.

**Depends on:** task 1

**Done when:** `tests/test-validate-skills.sh` passes with eleven new reader cases, and
`tests/validate-skills.sh` passes against this repository.

**Why a declared reader and not a matcher.** The brief asked for a dotted-path rule and named its
hard problem. The rule was prototyped against the tree on 2026-09-07 and does not work in either
direction. It flags 25 of 61 leaves, and 7 of the 25 are genuinely read: `artifacts.stories`,
`.architecture`, `.decisions` and `.plans` through the map iteration at `bin/keel:1341-1350`,
`gates.context_warn_pct` and `.context_stop_pct` through `lib/context_watch.py:497-508`, and
`conventions.default_branch` through the sed at `bin/keel:1640`. That is 28% false positives,
against `docs/standards.md:79` calling the too-strict failure the unrecoverable one and
`tests/validate-citations.sh:20-25` recording a rule thrown away at 70%. It also under-reports:
`gates.done_verified`'s real read is `(prof.get("gates") or {}).get("done_verified")` at
`hooks/done-guard:114`, and the dotted string appears in that file only in comments and refusal text
at `:25`, `:72` and `:111`. Falling back to bare leaf names passes everything, because `name` occurs
337 times in this tree, `test` 484 and `review` 146, so all 22 dead keys would pass.

So the mechanism is a declared marker, which the brief called "a worse mechanism and an honest one".
The citation check is what gives it teeth: it is modelled on `lib/harness/capabilities`, whose own
rule at `:88-89` is that a primitive with no source is treated as not provided, and absent evidence
fails rather than passes.

**The grammar.** `x-keel-read-by` is a string or an array of strings. Four forms:

| Form | Means | Checked |
|---|---|---|
| `code:<path>:<line>` | shipped code reads it and behaviour differs by value | the file exists, the line is inside it, the line is not blank |
| `advisory:<path>:<line>` | skill prose reads it; nothing asserts it | the same three rules |
| `human` | its job is to be read by a person or quoted into a runbook | nothing to check |
| `unread:<path>:<line>` | nothing reads it, and here is the record that decided so | the same three rules |

`unread:` is what stops this becoming a rubber stamp. A key may be dead, but only with a citation to
the decision that left it dead, so adding a speculative key means writing down where the intent
lives. `x-` prefixed members are ignored by JSON Schema validators, and the fingerprint at
`tests/validate-skills.sh:668-680` walks `properties` only, so this adds no path and moves no
version.

- [x] **Step 1: Write the failing test**

Add to `tests/test-validate-skills.sh`, after the existing `profile_keys_fixture` cases that end at
`:824` (line numbers as of the 2026-09-11 profile-key residuals batch; they were `:679` on
2026-09-07 and have moved since with ordinary additions to the file).

**Use `check_reports`, never `run`.** `run` asserts on the exit code, and
`tests/test-validate-skills.sh:785-788` records why that cannot isolate a schema rule: "Declaring a
schema in a fixture also activates the fingerprint rule, which reads SCHEMA_VERSION from a bin/keel
a small fixture has no reason to carry, so the validator exits 1 whatever the reference says."
Verified still true on 2026-09-07: a fixture carrying only `templates/profile.schema.json` exits 1
on the fingerprint rule alone, so every `run` case here would assert nothing. `check_reports` is at
`:790` and takes `<name> <yes|no> <needle> <mutate-fn>`.

```bash
# ---- every declared profile key says what reads it ------------------------
#
# 22 of 61 keys were read by nothing on 2026-09-07 and CHANGELOG.md recorded seven. This rule is
# what stops that recurring. Asserted on the message and not the exit code, for the reason stated
# above profile_keys_fixture: a fixture that declares a schema trips the fingerprint rule too.
readby_fixture() {   # readby_fixture <root> <json-value-for-x-keel-read-by> <read-by-cell>
    local root="$1" entry="$2" cell="$3"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'a real line a citation can point at\n' > "$root/bin/reader"
    printf '{"properties":{"a":{"type":"string","description":"A.","x-keel-read-by":%s}}}\n' "$entry" \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `a` | string | **you** | %s | A. |\n' "$cell"
    } > "$root/docs/profile-keys.md"
}

m_readby_code()   { readby_fixture "$1" '"code:bin/reader:1"' '`bin/reader:1`'; }
check_reports "a key naming a reader that exists is not reported" no \
  "x-keel-read-by" m_readby_code

m_readby_human()  { readby_fixture "$1" '"human"' 'a person'; }
check_reports "a key declared human-read is not reported" no \
  "x-keel-read-by" m_readby_human

# THE MUST-NOT-REJECT CASE, and it needs its own fixture rather than reusing readby_fixture.
#
# 10 of the 61 real keys ride on a parent-map read: all six artifacts.* on bin/keel:1346, which is
# `d=json.load(...).get('artifacts',{})`, plus verify.lint, verify.typecheck and verify.build on
# bin/keel:1387 and verify.format on bin/keel:1767, which are `json_get ... "verify.$k"`. Not one of
# those cited lines contains the leaf name. The regression this pin exists to catch is somebody
# hardening the rule to demand the leaf name on the cited line, which is the dotted-path matcher
# creeping back in after it was measured at 28% false positives and thrown away.
#
# A fixture reusing readby_fixture cannot catch that: its schema is flat, so there is no parent, and
# bin/reader contains neither a leaf name nor a parent name. This one is nested and its reader line
# names the parent only, so it fails the moment the rule starts asking for the leaf. It is also the
# only case in this file that exercises the recursive branch of the walk, which builds the dotted
# path artifacts.stories from two levels.
m_readby_parent() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs" "$root/bin"
    printf 'for k in prof["artifacts"]:\n' > "$root/bin/reader"
    printf '%s\n' '{"properties":{"artifacts":{"type":"object","properties":{"stories":{"type":"string","description":"S.","x-keel-read-by":"code:bin/reader:1"}}}}}' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `artifacts.stories` | string | **you** | `bin/reader:1` | S. |\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a key covered only by a parent-map read is not reported" no \
  "x-keel-read-by" m_readby_parent

m_readby_absent() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '{"properties":{"a":{"type":"string","description":"A."}}}\n' \
      > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
      printf '| `a` | string | **you** | _undeclared_ | A. |\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a key that declares no reader is reported" yes \
  "a declares no x-keel-read-by" m_readby_absent

m_readby_stale()  { readby_fixture "$1" '"code:bin/reader:99"' '`bin/reader:99`'; }
check_reports "a key naming a line its reader does not have is reported" yes \
  "that file has 1 lines" m_readby_stale

m_readby_gone()   { readby_fixture "$1" '"code:bin/nosuchreader:1"' '`bin/nosuchreader:1`'; }
check_reports "a key naming a file that does not exist is reported" yes \
  "that file does not exist" m_readby_gone

m_readby_bad_type() { readby_fixture "$1" '7' 'a person'; }
check_reports "a marker that is not a string or a list is reported" yes \
  "could not run to completion" m_readby_bad_type

m_readby_zero()  { readby_fixture "$1" '"code:bin/reader:0"' '`bin/reader:0`'; }
check_reports "a marker citing line zero is reported" yes \
  "that file has 1 lines" m_readby_zero

m_readby_advisory_code() { readby_fixture "$1" '"code:bin/reader.md:1"' '`bin/reader.md:1`'; }
check_reports "code: naming a markdown file is reported" yes \
  "Prose nothing asserts is advisory" m_readby_advisory_code

# THE FLOOR. A schema with no properties yields no keys, so the rule checks nothing and would pass
# everything. Copied from the tool-table floor at tests/validate-skills.sh:592, pinned at
# tests/test-validate-skills.sh:425, and deliberately NOT from the delegation floor at
# tests/validate-skills.sh:475, which is pinned in neither direction.
m_readby_no_keys() {
    local root="$1"
    mkdir -p "$root/templates" "$root/docs"
    printf '{"definitions":{"a":{"type":"string"}}}\n' > "$root/templates/profile.schema.json"
    { printf '# Profile keys\n\ngenerate-profile-keys.sh\n\n'
      printf '| Key | Type | Set by | Read by | Description |\n|---|---|---|---|---|\n'
    } > "$root/docs/profile-keys.md"
}
check_reports "a reader rule that extracts no keys is reported" yes \
  "read no keys at all" m_readby_no_keys
```

Then widen `profile_keys_fixture` at `:623-632` and its four call sites, because the row regex
changes from four columns to five in step 3 and every one of those fixtures builds four. Leaving
them would break `m_keys_ok` (`:658`), `m_keys_missing` (`:663`), `m_keys_stale` (`:667`) and
`m_keys_extra` (`:673`), which the plan reviewer confirmed on 2026-09-07. In the fixture, change
the header to `| Key | Type | Set by | Read by | Description |` with a five-dash separator, add
`"x-keel-read-by":"human"` to both schema properties, and in each of the four row strings insert
`a person |` between the "Set by" and description cells, so a row reads:

```
| `a` | string | `keel init` | a person | A. |
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: **nine failures.** The eight `yes`-expecting new cases fail with `wanted saw=yes, got
saw=no`, because no rule exists yet to emit any needle. The three `no`-expecting new cases pass, for
the right reason under `check_reports`: the needle genuinely is absent.

The fifth is `m_keys_ok`, reporting `wanted saw=no, got saw=yes`, and it is expected here. Step 1
widens `profile_keys_fixture` to five columns while the row regex is still four, so the existing
drift rule sees every fixture row as unparseable until step 3 widens the regex. The other three
`profile_keys_fixture` cases stay green because they assert on `yes` needles that still fire. All
four are green again after step 3, and that is the proof this ordering is meant to give: the
transient failure shows the regex and the fixture are genuinely coupled.

- [x] **Step 3: Write the minimal implementation**

Add to `tests/validate-skills.sh` **immediately after `:701`**, which is the `fi` closing the
fingerprint check, and **before `:703`**, which opens `if [ "$errors" -eq 0 ]; then`. Putting it
after `:703` would place the rule inside the success summary, where `report` increments a counter
nothing reads again and the validator has already decided to exit 0. Checked on 2026-09-07: `:703`
to `:716` is that summary and the two `exit` lines.

```bash
# Every declared profile key says what reads it, and the reader it names still exists.
#
# THE FAILURE. On 2026-09-07, 22 of the 61 keys templates/profile.schema.json declares were read by
# nothing, and 14 carried a description implying enforcement they did not have. CHANGELOG.md
# recorded seven. That is the delegation map's failure in a different file: the wiring map in
# docs/04-plugin-strategy.md was false in six of its ten rows, and the rule above exists for it.
#
# WHY A DECLARED READER AND NOT A GREP. A dotted-path matcher was written and measured against this
# tree before this rule was chosen. It flagged 25 of 61 keys and 7 of the 25 are genuinely read:
# artifacts.stories, .architecture, .decisions and .plans through the map iteration at
# bin/keel:1341-1350, gates.context_warn_pct and .context_stop_pct through
# lib/context_watch.py:497-508, and conventions.default_branch through the sed at bin/keel:1640.
# 28% false positives, against docs/standards.md's rule that a check is never stricter than correct
# output. It under-reports too: gates.done_verified is read as (prof.get("gates") or
# {}).get("done_verified") at hooks/done-guard:114 and the dotted string appears in that file only
# in comments. Bare leaf names rescue nothing: `name` occurs 337 times in this tree and `test` 484,
# so all 22 dead keys would have passed.
#
# So the key declares its reader and this checks the citation, the way lib/harness/capabilities
# declares a primitive and its source. Its rule is the one that applies here: absent evidence fails,
# never passes. `unread:` is legal and needs a citation to the record that decided it, so a
# speculative key cannot be added without writing down where its intent lives.
if [ -f templates/profile.schema.json ] && command -v python3 >/dev/null 2>&1; then
    readby="$(python3 - <<'PYRB'
import json, os, re

schema = json.load(open("templates/profile.schema.json"))


def declared(node, p=""):
    out = {}
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            out.update(declared(v, path))
        else:
            out[path] = v.get("x-keel-read-by")
    return out


keys = declared(schema)
if not keys:
    print("the schema walk read no keys at all, so this rule is checking nothing. "
          "templates/profile.schema.json has been reshaped past the properties walk above.")
    raise SystemExit(0)

form = re.compile(r"^(code|advisory|unread):([^:]+):([0-9]+)$")
problems = []
for path in sorted(keys):
    entries = keys[path]
    if entries is None:
        problems.append("%s declares no x-keel-read-by" % path)
        continue
    if isinstance(entries, str):
        entries = [entries]
    if not entries:
        problems.append("%s has an empty x-keel-read-by" % path)
        continue
    for e in entries:
        if e == "human":
            continue
        m = form.match(e if isinstance(e, str) else "")
        if not m:
            problems.append("%s has an unreadable x-keel-read-by entry %r, "
                            "not human and not <code|advisory|unread>:<path>:<line>" % (path, e))
            continue
        f, line = m.group(2), int(m.group(3))
        if not os.path.isfile(f):
            problems.append("%s names %s and that file does not exist" % (path, e))
            continue
        body = open(f, encoding="utf-8", errors="replace").read().splitlines()
        if line > len(body):
            problems.append("%s names %s and that file has %d lines" % (path, e, len(body)))
        elif not body[line - 1].strip():
            problems.append("%s names %s and that line is blank" % (path, e))
print("; ".join(problems))
PYRB
)"
    # "x-keel-read-by" is in the message on EVERY firing, not only when a key is missing one. The
    # three must-not-reject cases in tests/test-validate-skills.sh assert that this string is
    # ABSENT, and a needle the rule sometimes omits would let those cases pass while the rule was
    # firing for a different reason. Same class as the floors above: an assertion that cannot
    # distinguish quiet from broken is not an assertion.
    [ -z "$readby" ] \
      || report "templates/profile.schema.json has an x-keel-read-by problem: $readby. Every key states what reads it: code:<path>:<line> or advisory:<path>:<line> where something does, human where a person is the reader, unread:<path>:<line> naming the record that decided nothing reads it."

    # THERE IS NO SECOND FLOOR HERE, AND THAT IS DELIBERATE. A draft of this rule carried a count
    # check comparing this walk against the row count in docs/profile-keys.md, on the stated ground
    # that they were "two different walks of the same schema". They are not: the count walk was
    # structurally identical to declared() above, same properties recursion and same isinstance
    # guard, so it dropped exactly the same subtrees and could not see what it claimed to. The drift
    # rule 90 lines above already reports a dropped subtree precisely, by name. A floor whose reason
    # is false and whose needle no test asserts is the delegation floor's mistake, which
    # tests/test-validate-skills.sh copies from nobody on purpose.
```

**Three further corrections, from the review of the first attempt. Apply all three.**

**(d) Validate the marker's type where it is known, not by accident of truthiness.** The `readby_rc`
capture in (a) is a backstop and must stay, but on its own it lets one malformed marker blank every
other finding: with key `a` citing a missing file and key `b` set to `7`, `a`'s finding is built
into `problems`, the loop then raises on `b`, and nothing is ever printed. The operator sees one
generic sentence instead of the real defect. It also diagnoses three ways for one fault: `0` and
`false` are caught by `if not entries` and reported as "has an empty x-keel-read-by", which is
false, they are the wrong type; `{}` iterates its keys; `7` and `true` crash. One guard fixes all of
it, placed immediately after the `None` check:

```python
    if not isinstance(entries, (str, list)):
        problems.append("%s has an x-keel-read-by that is %s, not a string or a list of strings" % (path, type(entries).__name__))
        continue
```

Pin it with a marker of `0`, expecting the needle `not a string or a list of strings`, which is the
case that reports the wrong thing today rather than crashing.

**(e) A line number below 1 gets its own message.** `code:bin/reader:0` currently reports "names
code:bin/reader:0 and that file has 1 lines", which reads as a contradiction and shares its needle
with the stale-line case, so the two are indistinguishable from the message:

```python
        if line < 1:
            problems.append("%s names %s, and line numbers start at 1" % (path, e))
        elif line > len(body):
```

Retarget `m_readby_zero`'s needle to `line numbers start at 1`.

**(f) Pin the `advisory:` direction too.** The task says to pin both directions of the file-type
clause and only the `code:`-naming-markdown direction has a case, so deleting the advisory half
leaves the suite green. That is the defect this task exists to remove, thirty lines from the comment
condemning it:

```bash
m_readby_advisory_nonmd() { readby_fixture "$1" '"advisory:bin/reader:1"' '`bin/reader:1`'; }
check_reports "advisory: naming a file that is not markdown is reported" yes \
  "which is not a markdown file" m_readby_advisory_nonmd
```

**Two corrections to the rule, found by review and reproduced. Apply both.**

**(a) A non-zero exit from the python block is a finding, not a pass.** As first written the rule
assigns `readby="$(python3 ...)"` and tests only whether the string is empty. An `x-keel-read-by`
whose value is a JSON number or `true` is truthy and not iterable, so `for e in entries` raises
`TypeError`, stdout is empty, and an empty `$readby` reads as "no problems found". Measured on
2026-09-07: the validator exits 0 on a schema whose marker is `7`. The file runs `set -uo pipefail`
with no `-e`, so nothing downstream catches it. That is this rule's own stated principle inverted,
and it is the failure class the whole task exists to remove. Capture the status:

```bash
    readby_rc=0
    readby="$(python3 - <<'PYRB'
...the block unchanged...
PYRB
)" || readby_rc=$?
    [ "$readby_rc" -eq 0 ] || readby="the reader rule could not run to completion, python exited $readby_rc. A marker whose value is not a string or a list of strings is the known cause."
```

Pin it, because neither floor covers it: a case whose marker is the number `7`, expecting the needle
`could not run to completion`.

**(b) A line number of `0` is accepted and validates against the file's last line.** `[0-9]+`
matches `0`, `0 > len(body)` is false, and `body[-1]` is the last line. Change the range test to
reject it:

```python
        if line < 1 or line > len(body):
            problems.append("%s names %s and that file has %d lines" % (path, e, len(body)))
```

Pin it too: a marker of `code:bin/reader:0` must be reported.

**(c) The `advisory:` and `code:` distinction is checked, not left to guesswork.** As first written
nothing separates them and the failure message treats them as interchangeable, so the next person
guesses and the generated page prints "(advisory)" to a reader with no legend. The rule is one
clause: an `advisory:` citation names a markdown file, because advisory means prose a model may
follow; a `code:` citation names anything else, because code means something executes. Add to the
form check, and pin both directions:

```python
        if m.group(1) == "advisory" and not f.endswith(".md"):
            problems.append("%s uses advisory: for %s, which is not a markdown file. advisory: is for prose a model may follow; use code: for something that executes." % (path, e))
        if m.group(1) == "code" and f.endswith(".md"):
            problems.append("%s uses code: for %s, which is a markdown file. Prose nothing asserts is advisory:, not code:." % (path, e))
```

Then add `x-keel-read-by` to all 61 leaf entries in `templates/profile.schema.json`. The values are
the verdict table plus the census. Every key not listed below takes `human`.

**One obligation this task inherits from task 1.** Task 1 deleted `notes`' only audience signal
("a skill should know"), leaving "Project facts that nothing else records", which defines the key
purely by exclusion on a key `keel init` never writes. The **Read by** column is what repairs it:
`notes` takes `human`, so its row renders "a person" and a reader learns both what belongs there and
who reads it. **Check that row renders before calling this task done.** If the column is not enough,
say so rather than adding a sentence back to the schema by hand.

| Value | Keys |
|---|---|
| `code:bin/keel:465` | `harnesses` |
| `code:bin/keel:1517` | `schema_version` |
| `code:bin/keel:1516` | `keel_version` |
| `code:bin/keel:1331` | `project.kind` |
| `advisory:skills/keel/references/tool-choices.md:20` | `stack.language` |
| `code:bin/keel:853` | `stack.package_manager` |
| `code:bin/keel:1418`, `advisory:skills/coding-standards/references/house-defaults.md:31` | `stack.has_ui` |
| `advisory:skills/coding-standards/references/house-defaults.md:31` | `stack.framework` |
| `advisory:skills/keel/references/tool-choices.md:21` | `stack.also` |
| `code:bin/keel:1381`, `code:hooks/done-guard:118` | `verify.test` |
| `code:bin/keel:1432` | `verify.test_one` |
| `advisory:skills/tdd/SKILL.md:31` | `verify.test_integration` |
| `code:bin/keel:1387` | `verify.lint`, `verify.typecheck`, `verify.build` |
| `code:bin/keel#cmd="$(field "verify.$k"` | `verify.format` |
| `code:bin/keel#fix="$(field verify.format_fix` | `verify.format_fix` |
| `unread:this plan's verdict row 15` | `verify.e2e` |
| `unread:this plan's verdict row 22` | `verify.security` |
| `unread:this plan's verdict row 6` | `plugins.excluded` |
| `unread:this plan's verdict row 17` | `gates.security_audit` |
| `unread:this plan's verdict row 1` | `gates.tdd` |
| `unread:this plan's verdict row 3` | `gates.review` |
| `unread:this plan's verdict row 4` | `gates.observability` |
| `unread:this plan's verdict row 5` | `gates.docs_updated` |
| `unread:this plan's verdict row 7` | `conventions.working_branch` |
| `unread:this plan's verdict row 9` | `observability.log_shipping` |
| `unread:docs/ideas/standards-that-bind.md:506` | `gates.coding_standards` |
| `code:bin/keel:1346` | `artifacts.snapshot`, `artifacts.prd`, `artifacts.stories`, `artifacts.architecture`, `artifacts.decisions`, `artifacts.plans` |
| `code:bin/keel:1826` | `gates.commit_guard` |
| `code:hooks/done-guard:114` | `gates.done_verified` |
| `code:lib/context_watch.py:570` | `gates.context_watch` |
| `code:lib/context_watch.py:591` | `gates.context_window` |
| `code:lib/context_watch.py:507` | `gates.context_warn_pct` |
| `code:lib/context_watch.py:508` | `gates.context_stop_pct` |
| `code:hooks/sensitive-guard:162` | `hard_block_paths` |
| `advisory:skills/ship/SKILL.md:60` | `conventions.commit_style` |
| `code:bin/keel:1640` | `conventions.default_branch` |
| `code:bin/keel:1817` | `conventions.protect_default_branch` |
| `code:hooks/session-start:111` | `conventions.response_style` |
| `code:hooks/session-start:116` | `conventions.explain_level` |
| `advisory:skills/coding-standards/references/observability.md:19` | `observability.backend` |
| `code:lib/harness/claude.sh:63` | `plugins.recommended` |
| `code:bin/keel:332` | `docs_root` |

`conventions.commit_style` and `stack.also` are marked `advisory:` and are the same defect as
`gates.security_audit`: named in a body, never branched on. They are outside this brief's 22 and
are recorded in the idea record's "Not decided here" rather than fixed here.

Then add the column to `tests/generate-profile-keys.sh`. `declared()` at `:45` returns 3-tuples of
`(path, type, description)` and the loop at `:97` unpacks three. Widen both to four: append
`read_by(v)` to the tuple inside `declared()`, so the renderer is called where `v` is in scope and
the loop becomes `for path, typ, rb, desc in declared(schema):`. Do not thread the raw dict out;
`read_by` takes the property dict, and returning it would make the tuple carry a mutable schema
node into the print loop for no gain.

```python
def read_by(v):
    """What reads this key, as the reference page shows it.

    A person reading the page needs one of three answers: something reads it, a person reads it,
    or nothing reads it. The citation is printed rather than summarised because the citation is
    the thing tests/validate-skills.sh checks, and a summary would be a second copy to keep in
    step with it.
    """
    e = v.get("x-keel-read-by")
    if e is None:
        return "_undeclared_"
    if isinstance(e, str):
        e = [e]
    out = []
    for one in e:
        if one == "human":
            out.append("a person")
        elif one.startswith("unread:"):
            out.append("nothing yet, see `%s`" % one.split(":", 1)[1])
        elif one.startswith("advisory:"):
            out.append("`%s` (advisory)" % one.split(":", 1)[1])
        else:
            out.append("`%s`" % one.split(":", 1)[1])
    return ", ".join(out)
```

Print the header as `| Key | Type | Set by | Read by | Description |` with a five-column separator,
and put the `Read by` cell fourth, before the description. It goes before rather than after because
the `CLAIMS` tag at `:100-101` rides at the end of the description cell, and a column appended after
it would sit between the tag and the row's closing pipe, where the regex below expects the
description to end.

Then widen the row regex at **`tests/validate-skills.sh:628`** from four columns to five:

```python
row = re.compile("^\\| \x60([^\x60]+)\x60 \\| [^|]* \\| [^|]* \\| [^|]* \\| (.*) \\|$", re.M)
```

**Add three `CLAIMS` entries in `tests/generate-profile-keys.sh#print("# Profile keys")`.** The new column prints
citations, and three of them name gate vocabulary that `tests/test-harness-claims.sh:207` scans for
in any depth-1 `docs/*.md`, which `docs/profile-keys.md` is. `gates.done_verified` and
`hard_block_paths` are already safe because their rows carry a tag and `untagged_claims` skips a
line that has one (`:226`). These three are not:

```python
    "conventions.response_style": ["gate=session-start harness=claude", "gate=session-start harness=codex"],
    "conventions.explain_level": ["gate=session-start harness=claude", "gate=session-start harness=codex"],
    "verify.test": ["gate=done-guard harness=claude", "gate=done-guard harness=codex"],
```

Each pair is granted by the manifest: `session-start` and `done-guard` are both active on both
harnesses, which `tests/test-harness-resolve.sh` already pins, so `claim_gaps` accepts them. If a
tag is refused, the manifest is the authority and the citation is what changes, not the tag.

**Give each new entry its reason, and correct the two comments this change falsifies.** The comment
above `CLAIMS` says "Two keys name a gate in their description" and the row-regex comment in
`tests/validate-skills.sh` says "Two rows carry one"; both become five. Say why the three new ones
are there: the **Read by** column prints a citation, not a description, so these rows name
`hooks/session-start` and `hooks/done-guard` in a cell nobody wrote by hand. Deleting any of the
three turns `tests/test-harness-claims.sh` red, which is how to check the tags are load bearing
rather than decoration.

Add a short paragraph to the generated page explaining the **Read by** column, beside the one that
already explains **Set by**, and widen the page's opening line, which currently offers only "what it
does, and whether keel writes it".

Regenerate:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

Add one bullet to `CONTRIBUTING.md`, in "The rules the validator enforces", after the
`SCHEMA_VERSION` bullet:

```markdown
- Every key in `templates/profile.schema.json` declares `x-keel-read-by`, and the citation it gives
  still points at a real, non-blank line. `code:<path>:<line>` where something executes,
  `advisory:<path>:<line>` where a markdown file is prose a model may follow and nothing asserts it,
  `human` where a person is the reader, `unread:<path>:<line>` naming the record that decided
  nothing reads it. **The check does not tie the line to the key**, deliberately: the
  phrase-matching version of that idea was measured at a 70% false positive rate and thrown away,
  which `tests/validate-citations.sh` records. 22 of 61 keys were read by nothing on 2026-09-07
  while the changelog recorded seven; a key that cannot say what reads it is a key a user tests by
  hand.
```

Add one case to `tests/test-profile-keys.sh`, beside the existing coverage assertions. The repo
pairs the generator with its own test, and the validate-skills drift rule only proves the page
matches the schema, never that the new column carries anything:

```bash
# The column is the whole point of the change: an empty cell is a page that renders the question
# and answers none of it. _undeclared_ is what read_by prints for a key with no marker, and
# validate-skills.sh fails on that separately; here it must never reach the page at all.
blank="$(grep -cE '^\| `[^`]+` \| [^|]* \| [^|]* \|  *\|' "$work/a.md" || true)"
[ "$blank" = "0" ] && ok "every row carries a Read by value" \
  || bad "every row carries a Read by value" "$blank row(s) have an empty Read by cell"
grep -q '_undeclared_' "$work/a.md" \
  && bad "no row renders as undeclared" "$(grep -n '_undeclared_' "$work/a.md" | head -3)" \
  || ok "no row renders as undeclared"
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS on all eleven new cases, on the four `profile_keys_fixture` cases the widened fixture
keeps green, and on every case that was passing before.

Run: `tests/validate-skills.sh`
Expected: PASS against this repository, with no `x-keel-read-by` findings and no
"profile-keys.md disagrees" finding from the widened regex.

Run: `tests/test-profile-keys.sh`
Expected: PASS, including the two new cases.

Run: `tests/test-harness-claims.sh`
Expected: PASS, and specifically "no unregistered harness claim in a document in scope". **This is
the check the new column most easily breaks**, because the citations it prints name
`hooks/session-start` and `hooks/done-guard`, which are gate vocabulary. If it fails, the three
`CLAIMS` entries above are missing or misspelt; add the tag rather than rewording the citation.

Run: `tests/run-tests.sh`
Expected: PASS.

- [x] **Step 5: Hand over**

```bash
git add templates/profile.schema.json tests/validate-skills.sh tests/test-validate-skills.sh \
        tests/generate-profile-keys.sh tests/test-profile-keys.sh docs/profile-keys.md \
        CONTRIBUTING.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -m "test(profile): every declared key names its reader, and the citation is checked"`.
Paste the `git status --porcelain` output into your report.

---

> **Ticked 2026-09-08. Landed as `1a60d66`, with the plan corrections in `ad519d0`.**
>
> Two review rounds. The first passed on spec and found two blocking quality defects in the rule
> itself: it reported nothing when a marker's value was a JSON number or `true`, measured as the
> validator exiting 0 on a marker of `7`; and `m_readby_parent` was byte-identical to
> `m_readby_code`, so the must-not-reject case pinned nothing. The second found the `advisory:`
> half of the file-type clause shipped unpinned, so deleting it left the suite green. All three
> were defects in this plan's own text, not in the implementation.
>
> The rule now carries eleven pinned reader cases and one floor, and every guard was proved by
> mutation: a reviewer deleted the floor and confirmed its pin goes red, and the implementer
> deleted the advisory clause and confirmed the same. The must-not-reject case has a nested fixture
> whose reader line names the parent and never the leaf, so it fails the moment somebody hardens
> the rule back toward a dotted-path matcher.
>
> **A coordinator error is recorded here because the branch shows its repair.** The first
> implementation was committed by mistake inside a commit subjected `docs(plans):`, carrying 599
> added lines it did not describe, because `git add <paths>` was followed by a bare `git commit`
> while other work was staged. Nothing was pushed. It was split into the two commits above after
> Bernard chose that repair over leaving it. That is the same failure the hand-over step of every
> task in this plan warns about, made by the coordinator rather than an implementer.
>
> Correction (d) had a consequence the plan did not anticipate: validating the marker type made the
> captured-exit backstop unreachable by any marker value, silently unpinning it. The implementer
> caught that, retargeted the old pin and added `m_readby_walk_crashes`, which reaches the backstop
> through a malformed schema shape instead.

---

### Task 3: `verify.e2e` and `verify.security` are reported by `keel doctor`

**Traces to:** verdict rows 15 and 22.
**Files:**
- Modify: `bin/keel` (in `cmd_doctor`, after the `for k in test lint typecheck build` loop that
  ends at `:1409`)
- Modify: `templates/profile.schema.json` (the two descriptions and their `x-keel-read-by`)
- Modify: `docs/profile-keys.md` (**generated**)
- Modify: `tests/validate-skills.sh` and `tests/test-validate-skills.sh` (one prose citation each,
  falsified by this task's insertion; step 3 says which and why only these two)
- Test: `tests/test-keel.sh`

**Interfaces:**
- Consumes: the `x-keel-read-by` grammar from task 2.
- Produces: two new `cmd_doctor` output lines, `ok    verify.e2e is set (declared, not run)` and
  `ok    verify.e2e is null: keel did not detect one, so set it if this project has one`, and the
  same pair for `verify.security`. **Both are `ok`, not `WARN`, and that was decided on 2026-09-08
  after a review measured the alternative.** `verify.security` has no detector in any language
  (`lib/detect-stack.sh` mentions it once, in a comment saying it deliberately has no branch), and
  `verify.e2e` is detected only from a node `test:e2e` script, so `bin/keel:516` writes null for
  effectively every profile keel has ever created. A `WARN` there fires on 100% of projects, can
  be cleared by no keel command, and is mandated null on Dart by `docs/prd/dart-flutter-stack-detection.md`
  FR-14. `docs/standards.md:79` names that failure exactly: "too strict teaches people to ignore
  checks, which is unrecoverable". The line still differs by value and a test still proves it, so
  the brief's definition of wiring is met without the noise.

**Depends on:** task 2

**Done when:** `tests/test-keel.sh` passes with four new cases, `tests/validate-skills.sh` passes,
and neither repaired comment contains a `bin/keel` line number any more.

**Reported and not run, deliberately.** The loop at `:1387-1409` runs each command it reads.
`verify.e2e` needs a running system by its own description and `verify.security` is a scanner that
reaches the network, so running either in doctor would make the check cost what a deployment costs,
and `bin/keel:1268-1270` already records that a check nobody can afford to run is one they stop
running. Reporting still satisfies the brief's definition of wiring: behaviour differs between two
values of the key, and a test proves it.

- [x] **Step 1: Write the failing test**

Add to `tests/test-keel.sh`, beside the other `cmd_doctor` cases:

```bash
# verify.e2e and verify.security were written into every profile by write_profile and read by
# nothing, so a user saw a real command sitting in a real field with nothing behind it. Doctor
# names them without running them: e2e needs an environment doctor cannot provide and security
# reaches the network.
#
# fixture node-ts, NOT a bare git init. An empty directory detects as project.kind "docs", and the
# whole verify block including this loop sits inside doctor's `kind != docs` guard, so on a bare
# fixture doctor prints no verify line at all and the cases below would fail forever while looking
# like a bug in the new loop. Confirmed by running it on 2026-09-07.
we="$(fixture node-ts)"
( cd "$we" && "$KEEL" init -y >/dev/null 2>&1 )
# verify.e2e is a command that leaves evidence behind, not a plausible-looking one. The last two
# cases assert doctor did not run it, and the only way to assert that without trusting the output
# string is to give it something whose having run is a fact on disk. Relative, because doctor's
# `( eval "$c" )` inherits the cwd this subshell sets.
#
# `keel profile set` rather than a python heredoc. It is the idiom this file already uses, in the
# cases that set a string containing spaces and clear a value to null, and it refuses a path the
# profile does not have, so if either key were dropped from the schema this test would fail loudly
# instead of quietly writing a key nothing reads and passing anyway.
( cd "$we" && "$KEEL" profile set verify.e2e 'touch e2e-ran-sentinel' >/dev/null 2>&1 )
( cd "$we" && "$KEEL" profile set verify.security null >/dev/null 2>&1 )
out="$( cd "$we" && "$KEEL" doctor --fast 2>&1 )"
case "$out" in
  *'verify.e2e is set (declared, not run): touch e2e-ran-sentinel'*)
    ok "doctor names a declared verify.e2e without running it" ;;
  *) bad "doctor names a declared verify.e2e without running it" "$out" ;;
esac
# null reports as ok, not WARN. keel has no detector for either key, so a warning here fires on
# every project ever created and no keel command can clear it; docs/standards.md:79 calls that the
# unrecoverable kind of wrong. Asserting the `ok` prefix, because asserting the bare sentence
# would pass a WARN too and that is the whole distinction this case exists to hold.
case "$out" in
  *'ok    verify.security is null'*) ok "doctor reports a null verify.security as ok, not a warning" ;;
  *) bad "doctor reports a null verify.security as ok, not a warning" "$out" ;;
esac
# The command must not have run, asserted on disk rather than on the output string. An earlier
# version of this case matched on doctor's wording instead, and a review proved by mutation that it
# passed an implementation which ran the command but short-circuited on --fast, which is the mode
# this case invokes. The sentinel cannot be fooled that way: either the file is there or it is not.
if [ -e "$we/e2e-ran-sentinel" ]; then
  bad "doctor --fast does not execute verify.e2e" "the sentinel file exists, so the command ran"
else
  ok "doctor --fast does not execute verify.e2e"
fi
# The same assertion without --fast, and this is the one with teeth. A review proved by mutation
# that the case above passes an implementation which runs the command but short-circuits on --fast:
# nothing asserted under --fast can see such a path, so the sentinel there catches only a loop that
# always runs. Plain doctor costs about a second on this fixture, measured 2026-09-08: npm test,
# lint, typecheck and build each fail immediately with no node_modules installed. Both keys carry a
# sentinel, because one loop serves both and a mutation running only the security branch would
# otherwise go unseen.
( cd "$we" && "$KEEL" profile set verify.security 'touch security-ran-sentinel' >/dev/null 2>&1 )
full="$( cd "$we" && "$KEEL" doctor 2>&1 )"
if [ -e "$we/e2e-ran-sentinel" ] || [ -e "$we/security-ran-sentinel" ]; then
  bad "doctor runs neither verify.e2e nor verify.security without --fast" "$full"
else
  ok "doctor runs neither verify.e2e nor verify.security without --fast"
fi
rm -rf "$we"
```

`fixture` is at `tests/test-keel.sh:28` and `node-ts` is one of its stacks. `ok`, `bad` and `$KEEL`
are at `:19`, `:20` and `:15`.

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on the first two new cases, each printing the whole doctor output, which contains
`verify.test`, `verify.lint`, `verify.typecheck` and `verify.build` lines and no `verify.e2e` line
at all. The third case passes at this point, which is correct: nothing runs `verify.e2e` yet
because nothing reads it. It is there to stay passing in step 4.

**Both of the first two must fail, and for the stated reason.** If the second one fails while the
output already contains a `verify.security` line, the loop exists and the `ok` versus `WARN`
distinction is what is wrong; read the prefix before changing anything.

The last two cases, the two sentinel ones, pass at this point and that is correct: nothing reads
either key yet, so nothing can have run either command. They are here to stay passing in step 4,
and they are the cases that would catch a later implementation that started executing.

**If the output has no `verify.*` line of any kind, stop.** The fixture came out as
`project.kind: docs` and the block is guarded on that at `bin/keel#if [ "$kind" != "docs" ] && have_python; then`; the loop is not the
problem.

- [x] **Step 3: Write the minimal implementation**

In `bin/keel`, immediately after the `for k in test lint typecheck build` loop closes at `:1409`
and inside the same `if [ "$kind" != "docs" ] && have_python; then` block:

```bash
        # Declared and never run, which is the honest treatment for these two. e2e needs a running
        # system by its own description and security reaches the network, so running either here
        # would make doctor cost what a deployment costs. Both were written into every profile by
        # write_profile and read by nothing, so a user opened their profile, saw a real command in
        # a real field, and had no way to learn that nothing would ever run it.
        # A second loop rather than two more keys on the one above, because that one runs what it
        # reads and these two never run: folding them in means a `case` that jumps 2 of 6 keys past
        # twenty lines of timeout and exit-code handling, which is harder to read than the repeated
        # json_get line is to tolerate.
        for k in e2e security; do
            local dc; dc="$(json_get .keel/profile.json "verify.$k" || true)"
            # null is `ok` and not a warning. Neither key has a detector worth the name: security
            # has no branch in detect_verify at all, and e2e has one only for a node `test:e2e`
            # script, so init writes null into effectively every profile. A warning here would fire
            # on every project keel has ever made, would be clearable by no keel command, and is the
            # required value on Dart per that stack's own FR-14. The message says what to do instead.
            # "does not detect", present tense, and a claim about this project rather than about
            # what keel can do. security has no detector to have tried; e2e's fires only on a node
            # `test:e2e` script. The past tense would assert a search happened, which is false for
            # security and not knowable from here for e2e.
            if [ -z "$dc" ]; then good "verify.$k is null: keel does not detect one, so set it if this project has one"
            else good "verify.$k is set (declared, not run): $dc"
            fi
        done
```

In `templates/profile.schema.json`, replace the interim sentences task 1 wrote:

- `verify.e2e`: "Read by `keel doctor`, which names it and deliberately does not run it: it needs
  a running system that doctor has no way to provide."
  `x-keel-read-by` becomes `code:bin/keel:1411`.

**The second clause was cut on 2026-09-08, after review, and the cut is the point.** It read "and
a check nobody can afford to run before a commit is one they stop running". `keel doctor` is not a
pre-commit check: the pre-commit guard body runs format, lint and typecheck and never calls doctor,
`docs/standards.md` records doctor taking about eleven minutes here, and `execute-plan`'s
preconditions reference tells the reader not to delegate to it. The clause is borrowed from
doctor's own `--fast` comment, where it is about `--fast` and is true. Shipping a description whose
stated reason the tree contradicts, inside the change whose whole purpose is to stop descriptions
claiming what is not so, is the one mistake this plan cannot afford. The first clause is the true
and sufficient reason on its own.
- `verify.security`: "null where the project has none, and `keel init` never detects one, so null
  is the ordinary value rather than a gap. Read by `keel doctor`, which names it and does not run
  it: it reaches the network. security-audit does its own reading either way."
  `x-keel-read-by` becomes `code:bin/keel:1411`.

**Two corrections to this bullet, made 2026-09-08 after review, each with its reason.** The clause
"null where the project has none" is restored: task 1 wrote it, an earlier draft of this task
replaced the whole sentence and lost it, and dropping it would have left the one place a user could
learn that null is expected silent in the same change that started reporting on null. And the
reason is now security's own, "it reaches the network", not the borrowed "for the same reason as
`verify.e2e`": e2e's reason is that it needs a running environment, which is a different fact, and
`docs/standards.md:100` requires a rule to carry the reason that is actually its own.

The exact line number depends on where the loop lands. Read it out of the file after the edit and
write the number you see.

**Then re-point every `x-keel-read-by` citation below the insertion, and this is not optional.**
The loop adds about seven lines at `bin/keel:1410`, so every `code:bin/keel:<n>` marker with
`n > 1410` now names content seven lines above where it sat. Eight are affected:
`stack.has_ui` (1418), `keel_version` (1516), `schema_version` (1517),
`conventions.default_branch` (1640), `conventions.protect_default_branch` (1648),
`verify.format` (1767), `verify.format_fix` (1788), `gates.commit_guard` (1826).

**The rule added in task 2 will not catch this**, because it checks that the cited line exists and
is not blank, and a line seven off is both. That is the rule's known limit and it is stated in its
own comment; the compensating discipline is this sweep. Do it by reading each of the eight lines
after the edit and confirming it still contains the read the marker claims, not by adding seven:

```bash
python3 - <<'PY'
import json, re
d = json.load(open("templates/profile.schema.json"))
def walk(node, p=""):
    for k, v in (node.get("properties") or {}).items():
        path = "%s.%s" % (p, k) if p else k
        if isinstance(v, dict) and v.get("properties"):
            yield from walk(v, path)
        else:
            e = v.get("x-keel-read-by")
            for one in ([e] if isinstance(e, str) else (e or [])):
                m = re.match(r"^(?:code|advisory|unread):(bin/keel):([0-9]+)$", one or "")
                if m:
                    yield path, int(m.group(2))
body = open("bin/keel", encoding="utf-8").read().splitlines()
for path, n in sorted(walk(d), key=lambda t: t[1]):
    print("%-40s bin/keel:%-5d %s" % (path, n, body[n - 1].strip()[:90]))
PY
```

Read that table and confirm each line is the read its key claims. A line that is now a comment or a
different key's read is one to correct here, in this task, before the hand-over.

**The comments this task adds carry no `bin/keel` or `tests/test-keel.sh` line numbers**, and that
is deliberate rather than an oversight of the citation style used elsewhere. Tasks 4 and 6 insert
into both files, so a number written into a comment now goes stale inside this branch, silently,
for the reason open question 0c measures. The one surviving token in the block, into
`docs/standards.md`, stays because no remaining task edits that file.

**Then repair the prose citations in the two files named in this task's Files block**, which are
`tests/validate-skills.sh` and `tests/test-validate-skills.sh`. Two of them are falsified by this
insertion and are the reason those files are in scope at all. Both comments also carry `bin/keel`
numbers this insertion does not falsify, and those are converted too: the `Done when:` asks that
neither comment contain a `bin/keel` line number afterwards, and task 6 edits `bin/keel` above
them, so leaving them means they go stale on the next task with nothing going red. **The scope is
those two comments, not the tree.**

The marker sweep above covers `x-keel-read-by` only. Prose citations into `bin/keel` shift by the
same amount and no checker sees them, because `tests/validate-citations.sh` tests only that the
first cited line exists and is not blank, and a line 28 off is both. Comparing HEAD's line N
against the edited file's line N+28 for every prose citation into `bin/keel` at or below the
insertion: **19 were correct before this task and false after it.** This task repairs 2, the two
live code comments above. **17 remain, across 11 files**, and the suite reports
`OK 983 citations checked` throughout. Do not repair those 17 here: they are dated records,
`CHANGELOG.md` inside a released version among them, and rewriting a released version's record is
forbidden. They are recorded in open question 0c.

**Replace each with a phrase, not a corrected number.** Tasks 4 and 6 also insert into `bin/keel`,
so any number written now goes stale again inside this branch, and a phrase cannot. Name the code
the sentence means: the `get('artifacts',{})` map iteration in `cmd_doctor`, the `default_branch`
sed in the pre-push hook body, the `json_get` of `"verify.$k"` in doctor's verify loop, and the
`field "verify.$k"` read in the pre-commit guard body. **Write no `path:line` token while doing
it**, in the comment or anywhere else: the checker matches `path.ext` followed by a colon and
digits in prose whether or not it is in backticks, so writing out a stale citation to describe one
creates a fresh one. That happened once already on this branch.

**One count in `tests/test-validate-skills.sh` goes stale here and task 6 repairs it, deliberately
not this task.** The comment above the must-not-reject pin opens "10 of the 61 real keys ride on a
parent-map read" and enumerates them. `verify.e2e` and `verify.security` now cite the new loop's
`json_get` of `"verify.$k"`, which contains neither leaf name, so they are parent reads too and the
true figure is 12. Verified by counting the markers whose cited line lacks the leaf name. It is
left alone here because task 6 retires six keys and rewrites the same sentence's "61" to 55, so
repairing it now means writing a number task 6 falsifies again. **Task 6 owes both figures in one
edit**, and the pin itself is unaffected: it exists to catch a rule hardened to demand the leaf
name on the cited line, and two more keys of exactly that shape strengthen the case for it.

Regenerate:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all four new cases.

Run: `tests/validate-skills.sh`
Expected: PASS, including the `x-keel-read-by` citation check on the two new `code:` entries.

Run: `tests/run-tests.sh`
Expected: PASS.

**Outcome on 2026-09-08: PASS, on the second attempt, and the first attempt is why this note
exists.** The task was implemented twice. The first attempt inserted 41 lines into
`tests/test-keel.sh` and `tests/run-tests.sh` went red:

```
FAIL  <line 44 of the security audit> cites <lines 3145 to 3151 of the test file>,
      and line 3145 of the test file is blank.
```

That attempt was discarded for unrelated reasons and the task was tightened. The second attempt
inserts 49 lines, so line 3145 of `tests/test-keel.sh` lands eight lines earlier, on a non-blank
line, and `tests/validate-citations.sh` reports `OK 983 citations checked`. **The suite is green
and the defect is untouched.**

**This is the most useful thing the task produced, and it is not the feature.** The citation on
line 44 of `docs/audits/2026-09-01-security.md` is false in both attempts and was false before
either. At the commit before this task the range it names was the `schema_version` re-init block;
it now names the keel-nudge `CLAUDE_PLUGIN_ROOT` block; the assertion the sentence actually
describes is the `for cmd in curl wget nc` case, which is neither. What changed between red and
green was not the truth of the citation but how many lines were inserted above it, because
`tests/validate-citations.sh` tests only that the first cited line exists and is not blank. Eight
lines of difference in an unrelated file decided whether the repository noticed a false claim.
Task 3a repairs the claim; open question 0c records what it says about the checker.

**A known limit of the third test case, and how it was closed.** Case 3 originally asserted that
doctor did not execute `verify.e2e` by matching on doctor's wording. A reviewer replaced the loop
with one that runs the command and the case failed, so the assertion had force; the reviewer then
replaced it with one that runs the command *but honours `--fast`* and the case passed, because the
test invokes `keel doctor --fast` and that branch short-circuits before execution. The case as
prescribed could not tell "reported without running" from "ran only outside `--fast`". It now sets
`verify.e2e` to `touch e2e-ran-sentinel` and asserts the file does not exist, which is evidence on
disk rather than a match on doctor's wording.

**That closed one axis and not the other, and an earlier draft of this note claimed otherwise.**
The claim "no execution path can satisfy this while having run the command" was written here and
is false. A reviewer proved it by mutation: a loop that runs the command but honours `--fast`
still passes all three cases, because the test invokes `keel doctor --fast` and such a loop never
reaches its `eval`. The sentinel defeats a loop that always runs the command, which is the mutation
that got past the previous version; it cannot see a `--fast`-conditional one, because nothing
asserted under `--fast` can. Closing that would need a fourth case invoking plain `keel doctor`,
which is measured and decided at the end of this note. The correction is recorded rather than
quietly edited because the false sentence is the kind this plan exists to remove.

Run the lint command from `.keel/profile.json`:
`shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
Expected: no findings. `local` inside the loop is the shape the surrounding code already uses.

- [x] **Step 5: Hand over**

```bash
git add bin/keel templates/profile.schema.json docs/profile-keys.md tests/test-keel.sh \
        tests/validate-skills.sh tests/test-validate-skills.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(doctor): name verify.e2e and verify.security instead of writing them into silence"`.

---

### Task 3a: The security audit cites a phrase, not a line that has already moved twice

**Traces to:** not a verdict row. A pre-existing defect task 3 exposed, of the class the branch
recorded and deferred at `CONTRIBUTING.md` lines 125 and 145 to 146. Added during execution on
2026-09-08, by Bernard's decision.

**It was going to be red, and then it was not, and that is the reason to do it rather than a
reason to skip it.** Task 3's first attempt made this citation fail; its second, eight lines
longer, left it green. Task 3's step 4 note has the detail. The claim is false either way, and it
is now false in a way no check in this repository can see, which is strictly worse than red: a red
line gets fixed, a green false one gets believed. Nothing here is urgent and nothing here is
optional.

**Files:**
- Modify: `docs/audits/2026-09-01-security.md`

**Interfaces:** none. No code changes.

**Depends on:** task 3, which is what last moved the lines under it. Tasks 4 and 6 also insert
into `tests/test-keel.sh`, and this repair is what makes them safe to run without a citation sweep
of their own.

**Done when:** `grep -n 'test-keel' docs/audits/2026-09-01-security.md` shows the sentence naming
a phrase and no line number, `grep -c 'for cmd in curl wget nc' tests/test-keel.sh` returns 1, and
`tests/run-tests.sh` still passes.

**There is no failing check to watch first, and the task does not pretend otherwise.**
`tests/validate-citations.sh` is green right now against this false citation and would stay green
if the repair were never made, so the ordinary TDD shape does not apply. The check that fails
before this change and passes after it is a person reading the cited range, which step 1 makes
explicit and reproducible rather than dressing up as automation. Do not add a test asserting the
wording of an audit sentence: `docs/standards.md` warns against checks stricter than correct
output, and a sentence is not a contract.

**The citation was false before it was red.** Line 44 of `docs/audits/2026-09-01-security.md`
cites lines 3145 to 3151 of `tests/test-keel.sh` for the sentence "`keel_ask_rules` now emits
`Bash(curl *)`, `Bash(wget *)` and `Bash(nc *)`, which ... asserts reach the written `ask` list".
At the commit
before task 3, those lines were the `schema_version` re-init block, and the assertion the sentence
means was at 3234 to 3241. The check passed only because the cited lines were non-blank, which is
the exact defect this branch exists to remove. Task 3's 41-line test insertion pushed line 3145
into a blank line and turned a silently false citation into a red one.

**Why a phrase and not the corrected line numbers.** Task 4 and task 6 both insert into
`tests/test-keel.sh` above this point, so any line number written here goes stale again within the
same branch, and each of those tasks would then owe a sweep it does not carry.
`tests/validate-citations.sh:196` prescribes the remedy in its own failure text: "replace the line
number with a phrase from the text". A backticked path with no `:line` is not matched as a
citation, so it is not checked, and a grep-able phrase is what a reader follows anyway.

- [x] **Step 1: Prove the citation is false, by reading it, before changing anything**

Read the sentence: `grep -n 'test-keel' docs/audits/2026-09-01-security.md`. One hit, in the
sentence beginning "`keel_ask_rules` now emits". Note the line range it cites.

Print that range out of the test file with `sed -n '<start>,<end>p' tests/test-keel.sh`.

Expected: the range contains the keel-nudge `CLAUDE_PLUGIN_ROOT` case, and contains no assertion
about `curl`, `wget`, `nc` or the `ask` list. Record what you actually see, because if a later
task has moved the lines again it will be something else and the point stands either way.

Then locate what the sentence means: `grep -n 'for cmd in curl wget nc' tests/test-keel.sh`. One
hit, at a line well below the cited range. That gap is the defect.

Confirm the checker does not catch it: `tests/validate-citations.sh` exits 0 today. Record that
too. Both facts together are what justify this task.

- [x] **Step 2: Replace the line number with the phrase**

Find it with `grep -n 'test-keel' docs/audits/2026-09-01-security.md`. There is one hit, in the
sentence beginning "`keel_ask_rules` now emits". It is a backticked citation naming the test file
and the line range 3145 to 3151. **This plan does not reproduce that token, and neither should any
document you write**: the checker matches `path.ext` followed by a colon and digits anywhere in the
prose, backticks or not, so writing a stale citation in order to describe it creates a second stale
citation. That happened on the first attempt at this task and cost a round trip.

Replace the whole backticked citation with this phrase, keeping the rest of the sentence as it is:

    `tests/test-keel.sh`'s `for cmd in curl wget nc` case

so the sentence ends "..., which `tests/test-keel.sh`'s `for cmd in curl wget nc` case asserts
reach the written `ask` list."

Keep the prose wrapped at 100 columns, per `docs/standards.md`. Change nothing else in the file:
it is a dated audit record and the rest of its claims are not in scope.

- [x] **Step 3: Confirm it passes**

Run: `tests/validate-citations.sh`
Expected: PASS, with the total citation count one lower than the run in step 1, because a phrase
is not a citation and this removes the last one in that sentence. Quote both numbers; the drop is
the only evidence that the edit landed where it was meant to.

Run: `tests/run-tests.sh`
Expected: PASS.

Confirm the phrase is findable, which is the whole claim the new form makes:
`grep -c 'for cmd in curl wget nc' tests/test-keel.sh`
Expected: `1`. A phrase citation is worth less than a line number if it does not resolve, so this
is the step that makes the trade a good one.

**Ticked on a subagent's reported output, and no reviewer was dispatched.** Bernard's standing
guidance for keel is that a repair statable in a sentence does not get a review round; the check is
the check. This task's own `Done when:` is that check, and the coordinator re-ran all three plus a
mechanical diff of the paragraph against HEAD with only the citation substituted, which confirmed
that nothing else in the file moved.

**What step 1 found, recorded because it is the task's whole justification.** The cited range held
the tail of a comment about `CLAUDE_PLUGIN_ROOT` not reaching a hook a project registers, plus a
`mktemp -d`. Six of the seven lines are a comment about environment variables and the seventh makes
a temp directory. There is no assertion in the range at all, and no mention of `curl`, `wget`, `nc`
or the `ask` list. The assertion the sentence means sits 145 lines below the bottom of the range.
That is a **third** position for these lines: before task 3 the range was the `schema_version`
re-init block, and before this branch it was something else again. The claim has been false
throughout and green throughout.

Citation count went from 983 to 982, a drop of exactly one, which is the only mechanical evidence
the edit landed on the intended token and removed no other. `tests/supply-chain-scan.sh`
independently names the same line the sentence now points at by phrase.

- [x] **Step 4: Hand over**

```bash
git add docs/audits/2026-09-01-security.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs(audits): cite the ask-list assertion by phrase, not by a line that moved"`.

---

### Task 4: `plugins.excluded` is honoured by `plugin_report`

**Traces to:** verdict row 6.
**Files:**
- Modify: `lib/harness/claude.sh` (the `recommended` read inside `settings_report_load`, and
  `plugin_report`, which filters `SETTINGS_REPORT` for `missing:` lines)
- Modify: `templates/profile.schema.json` (`plugins.excluded`'s description and `x-keel-read-by`,
  and `plugins.recommended`'s `x-keel-read-by`, which this task's own edit makes less specific)
- Modify: `docs/profile-keys.md` (**generated**)
- Test: `tests/test-keel.sh`, which also gains `HOME` on the existing `pu` user-scope case. That
  case sets `CLAUDE_CONFIG_DIR` and not `HOME`, so `expanduser("~/.claude")` reads the machine it
  runs on and its assertion fails for anyone with that plugin enabled at user scope. The comment
  this task adds cites `pu` as the case that records why `HOME` is not optional, so the citation is
  untrue until that line lands. One line, and it removes a real flake.

**Interfaces:**
- Consumes: `plugins.recommended`, already loaded by the `json.load(open(".keel/profile.json"))`
  in `settings_report_load`'s python block.
- Produces: nothing new. `plugin_report` stops emitting `missing:<plugin>` for a plugin listed in
  `plugins.excluded`.

**Depends on:** task 3

**Done when:** `tests/test-keel.sh` passes with eight new cases, `tests/validate-skills.sh`
passes, and the `pu` user-scope case pins `HOME`. **Eight, and each one is load bearing**: drafts
of this line said two, three, four, five and six, and every one of those counts would have let an
implementer drop a case that a review later proved was the only thing holding a property this
task's own comments spend lines justifying. The first five were each confirmed by mutation to kill
something no other case kills; the sixth was added because a mutation survived all five; the
seventh and eighth because a probe found two malformed-profile shapes that crash the whole report,
one of which this change introduces. Step 1 names what each one catches.

**Every `tests/test-keel.sh` line number this task used to carry has been replaced by a phrase,
on 2026-09-08, and the reason is the task itself.** Task 3 inserted 62 lines into that file, so
this task's three citations, all correct when the plan was written, were all off by exactly 62 when
it came to be dispatched. `tests/validate-citations.sh` reported `OK 982 citations checked`
throughout, because a line 62 off is still a non-blank line. This is the nineteenth through
twenty-first instance of what open question 0c measures, and the first where the falsified
citations were the plan's own instructions to the next implementer. Step 1 of this task inserts
into that file again, so a number written here would go stale a second time before task 6 lands.
Two unrelated defects were fixed in the same pass: `plugin_report` was cited at a range beginning
ten lines inside `settings_report_load`, and the `Done when:` asked for two new cases where step 1
prescribes three and explains why the third is the floor.

**Claude Code only, and the description says so.** `plugin_report` lives in `lib/harness/claude.sh`
and there is no Codex counterpart. Under ADR-0004 a guarantee belongs to a repository and harness
pair, so a key honoured on one harness has to say which. This needs no capability-manifest row:
`lib/harness/capabilities` governs hook gates, and this is a doctor report.

- [x] **Step 1: Write the failing test**

Add to `tests/test-keel.sh`, beside the existing `plugins.recommended` cases:

```bash
# plugins.excluded was declared so a project had somewhere to record the decision, and nothing
# honoured it, so a plugin a team had deliberately rejected was recommended to them on every
# doctor run. The recommended list wins nothing here: excluded is the later decision.
#
# THE FIXTURE HAS TO TAKE THE MERGE PATH. On a fresh node-ts fixture `keel init` writes
# .claude/settings.json with typescript-lsp and the rest already enabled, so plugin_report has
# nothing to report and both cases below would pass while asserting nothing. Writing a settings
# file first takes the merge path, which touches permissions only and enables no plugin, which is
# what the existing `pm` merge-path case in this file already exists to set up.
#
# CLAUDE_CONFIG_DIR and HOME are not optional. The `pu` user-scope case in this file records why: a
# developer whose plugins are enabled at user scope, which is how keel is normally installed,
# would see doctor correctly stay quiet and the assertion would fail for them alone.
px="$(fixture node-ts)"
mkdir -p "$px/.claude" "$px/emptyconf"
printf '{\n  "permissions": { "allow": ["Bash(ls:*)"] }\n}\n' > "$px/.claude/settings.json"
( cd "$px" && "$KEEL" init -y >/dev/null 2>&1 )
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    bad "an excluded plugin is not recommended" "$out" ;;
  *) ok "an excluded plugin is not recommended" ;;
esac
# The floor for this pair. Without it, a plugin_report that reported nothing at all would pass the
# case above, and reporting nothing is exactly what a broken settings read looks like.
#
# The companion is claude-md-management and NOT code-review, deliberately. code-review is one of
# the three hardcoded names the fallback list carries, so it is reported even when the profile read
# throws and the fallback substitutes: the assertion would pass while proving nothing about the
# project's own list. That matters more since excluded parsing moved inside the same try. Any name
# in expected_plugins that is not one of security-guidance, code-review or skill-creator works.
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a recommended plugin beside it is still reported" ;;
  *) bad "a recommended plugin beside it is still reported" "$out" ;;
esac

( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"]["excluded"] = []
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *context7@claude-plugins-official*)
    ok "the same plugin is reported when the exclusion is removed" ;;
  *) bad "the same plugin is reported when the exclusion is removed" "$out" ;;
esac

# The ordering case, and it is the only one that fails if the subtraction moves ahead of the
# fallback. Every case above excludes one of two recommended plugins, so `rec` never empties and
# the ordering is never exercised: a review proved by mutation that moving the subtraction before
# the fallback survives all three. Here the project excludes everything it recommends, so a
# subtraction that ran first would empty `rec`, hit `if not rec`, and hand back the hardcoded
# three, which is the exact opposite of what the project asked for.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official"],
                "excluded": ["context7@claude-plugins-official"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in
  *security-guidance@claude-plugins-official*|*skill-creator@claude-plugins-official*)
    bad "excluding every recommended plugin does not resurrect the fallback list" "$out" ;;
  *) ok "excluding every recommended plugin does not resurrect the fallback list" ;;
esac

# keel itself is not excludable, and this pins it. Every other plugin warning says a skill degrades
# to an inline fallback; the keel@ branch says no keel skill loads at all, which is not the same
# kind of advice. A project that listed keel@gbi under excluded would otherwise switch off the one
# warning here that is not about degradation. Decided by Bernard on 2026-09-08.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["keel@gbi"], "excluded": ["keel@gbi"]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"keel itself is not enabled here"*)
    ok "excluding keel@gbi does not silence the warning that keel is not loaded" ;;
  *) bad "excluding keel@gbi does not silence the warning that keel is not loaded" "$out" ;;
esac

# The type guard, which is the one property the implementation states in prose and nothing else
# pins. A review ran five mutations against the five cases above and every one died; a sixth,
# computing exc as set(_x or []) back inside the try, survived all of them. With a non-list
# excluded that mutation raises a TypeError into an except sized for "the profile does not load",
# discards the recommended list this project wrote, and reports against the hardcoded three
# instead. Asserting security-guidance is ABSENT is what catches it: that name can only appear via
# the fallback, never via the list set here.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["context7@claude-plugins-official",
                                "claude-md-management@claude-plugins-official"],
                "excluded": 5}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
# Three arms, and the third is not decoration. Asserting only that the fallback name is absent
# passes vacuously when the whole block dies and doctor prints no plugin line at all, which is one
# of the two failure modes a malformed excluded can cause. A mutation proved that; the case has to
# see the list this project wrote, not merely fail to see the hardcoded one.
case "$out" in
  *security-guidance@claude-plugins-official*)
    bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
  *claude-md-management@claude-plugins-official*)
    ok "a malformed excluded is ignored, not treated as a failed profile read" ;;
  *) bad "a malformed excluded is ignored, not treated as a failed profile read" "$out" ;;
esac

# The element check, which is a failure this change would otherwise introduce rather than inherit.
# A non-string element raises out of set() past the whole block, so SETTINGS_REPORT comes back
# empty and the conflict and duplicate reports die with this one. Before this change nothing read
# excluded, so the same profile was harmless. Asserting a recommended plugin IS still named is what
# catches it, because the symptom is silence rather than a wrong line.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": ["claude-md-management@claude-plugins-official"],
                "excluded": [{"name": "context7@claude-plugins-official"}]}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *claude-md-management@claude-plugins-official*)
    ok "a non-string element in excluded does not silence the whole plugin report" ;;
  *) bad "a non-string element in excluded does not silence the whole plugin report" "$out" ;;
esac

# recommended gets the same treatment, and this case is why the check covers both fields. A string
# is truthy, so it skips the fallback and the loop walks it character by character: a recommended
# of "abc" produced three warnings naming plugins a, b and c, each with an install command for a
# plugin that cannot exist. Measured 2026-09-08. An int raised instead and killed every report.
( cd "$px" && python3 - <<'PY'
import json
p = ".keel/profile.json"
d = json.load(open(p))
d["plugins"] = {"recommended": "context7@claude-plugins-official", "excluded": []}
json.dump(d, open(p, "w"), indent=2)
PY
)
out="$( cd "$px" && CLAUDE_CONFIG_DIR="$px/emptyconf" HOME="$px" "$KEEL" doctor 2>&1 )"
case "$out" in *"not enabled: c."*|*"not enabled: o."*|*"not enabled: n."*)
    bad "a string recommended is not walked character by character" "$out" ;;
  *) ok "a string recommended is not walked character by character" ;;
esac
rm -rf "$px"
```

Eight cases. The second is the floor.

**No apostrophe may appear in any comment this task adds to `settings_report_load`.** That function
opens with the reason: its heredoc sits inside a `$( )`, and bash 3.2 does not treat a quoted
heredoc body as literal there, so a single apostrophe swallows the rest of the file. An earlier
draft of the block below carried one, and applying it verbatim took the suite from one failure to
seventy-one. **`shellcheck` does not see it and `bash -n` does**, reporting the parse error about
280 lines below its cause; neither is in this project's verify set for that file, so the suite is
what catches it. Verified 2026-09-08 on bash 3.2.57. The first case alone passes whenever
`plugin_report` reports nothing at all, which is what a broken settings read looks like; the
`code-review` assertion is what tells "excluded was honoured" apart from "the report is dead".

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-keel.sh`
Expected: FAIL on **two** cases, and only those two.

"an excluded plugin is not recommended", printing a doctor output naming
`context7@claude-plugins-official` as missing, because nothing reads `excluded` yet.

"a string recommended is not walked character by character", printing one warning per character of
the string, each naming a plugin that cannot exist and offering an install command for it. That
case is a regression test for a bug this task repairs, so failing first is correct.

The other six pass already: they pin directions the fix must not break. A run where all eight fail
means the fixture is not taking the merge path.

**An earlier draft of this step predicted one failure**, written before `recommended` was folded
into the same guard. Two dispatches reported the discrepancy and continued correctly rather than
treating it as a broken fixture. The correction then failed to land twice, in batches that aborted
on an unrelated anchor before writing, and a commit message claimed it had.

The fourth case also passes before the change, for a reason worth knowing: with nothing reading
`excluded`, `rec` is the project's own one-item list and the hardcoded three are never reached.
It starts failing only if someone later writes the subtraction in the wrong order, which is what
it is for.

- [x] **Step 3: Write the minimal implementation**

In `lib/harness/claude.sh`, the block at `:62-72` reads today:

```python
try:
    rec = json.load(open(".keel/profile.json")).get("plugins", {}).get("recommended")
except Exception:
    rec = None
if not rec:
    rec = ["security-guidance@claude-plugins-official",
           "code-review@claude-plugins-official",
           "skill-creator@claude-plugins-official"]
for r in rec:
    if r not in enabled_full:
        print("missing:" + r)
```

Replace it with:

```python
try:
    plugs = json.load(open(".keel/profile.json")).get("plugins", {})
except Exception:
    plugs = {}
if not isinstance(plugs, dict):
    plugs = {}
# Both lists are checked, elements included, and outside the try on purpose. The except above is
# sized for "the profile does not load", so a TypeError swallowed there would discard the list this
# project wrote and report against the hardcoded three instead. Unchecked they are worse than that.
# A string iterates character by character, so a recommended of "abc" prints missing:a, missing:b,
# missing:c, which doctor renders as three plugins named a, b and c. A non-string element raises
# out of set() past this block entirely, which empties SETTINGS_REPORT and silences the conflict
# and duplicate reports along with this one: before this change a malformed excluded was inert
# because nothing read it, so that failure is one this change would introduce. Nothing validates a
# profile against the schema at runtime. All three measured 2026-09-08.
def _names(v):
    return [x for x in v if isinstance(x, str)] if isinstance(v, list) else None
rec = _names(plugs.get("recommended"))
exc = set(_names(plugs.get("excluded")) or [])
if not rec:
    rec = ["security-guidance@claude-plugins-official",
           "code-review@claude-plugins-official",
           "skill-creator@claude-plugins-official"]
# Excluded is subtracted AFTER the fallback, never before. Before it, a project that excluded every
# plugin on its own recommended list would empty rec, hit `if not rec`, and be handed the hardcoded
# three back: the exclusion would produce the opposite of what it asked for.
#
# Excluded wins over recommended because it is the later and more specific decision: a team lists a
# plugin here after deciding against one a curated recommended list still carries. Dropped silently
# rather than reported, since a project that wrote the exclusion does not need telling about it.
#
# keel itself is the one exception. Every other name here warns that a skill degrades to an inline
# fallback; the keel@ branch warns that no keel skill loads at all, which is not the same kind of
# advice, so a project cannot switch it off by listing the name. Decided 2026-09-08.
for r in rec:
    if r in exc and not r.startswith("keel@"):
        continue
    if r not in enabled_full:
        print("missing:" + r)
```

**Keep the `try/except`.** The whole `python3 -` block runs with `2>/dev/null`, so an exception on a
missing or malformed profile would take `SETTINGS_REPORT` to empty and silently kill `missing:`,
`conflict:` and `dup:` reporting together, not just this read.

In `templates/profile.schema.json`, replace the interim description task 1 wrote with:

"Plugins this project deliberately does not want, as marketplace-qualified names. `keel doctor`
will not recommend one listed here, even where `plugins.recommended` also carries it, because an
exclusion is the later and more specific decision. keel's own plugin is the exception and stays
reported, since that warning is about keel not loading at all rather than a skill degrading.
Claude Code only: keel prints no plugin report on Codex, so this key is declared and not honoured
there."

**Two things earlier drafts of this description got wrong, recorded so they are not reintroduced.**

**It cannot name the marketplace-qualified id of keel itself.** `tests/no-internal-leaks.sh` greps
`templates/profile.schema.json` for the organisation name and exempts only lines carrying `$schema`
or `$id`, so a description containing it fails the suite. Two dispatches hit this, the second after
the first had already reported it. The rule is right and deliberately narrow, and the guarantee
survives the reword: the test case that pins the behaviour still uses the literal id, and
`plugins.recommended` one row above shows the qualified-name format.

**The Codex clause is a claim about keel, not about Codex, and two drafts had it backwards.** The
first said `plugin_report` "has no Codex counterpart", which reads as a harness limitation like
`sensitive_paths`. The second said "no Codex equivalent to keel's recommended set is established"
and pointed at `docs/harness-support.md`. `lib/harness/capabilities` grants Codex
`plugin_marketplace` on vendor attestation and that page prints the row, so a reader following the
pointer finds text reading as a contradiction of the sentence that sent them there. What is missing
is keel's half, an empty `harness_recommend_plugins` in `lib/harness/codex.sh`. The shipped wording
says that and nothing more, and carries no pointer.

`x-keel-read-by` becomes `code:lib/harness/claude.sh:<n>`, where `<n>` is the line that **reads**
`excluded`, the `exc = set(_names(plugs.get("excluded")) or [])` assignment. Read it out of the
file after the edit.

**`plugins.recommended`'s marker moves in the same edit, to the line that reads it.** This task
splits the old single-expression read in two, so the line that marker cites stops naming
`recommended` and becomes the `plugs = json.load(...)` container load, while the actual read moves
to the `rec = _names(plugs.get("recommended"))` assignment. A container citation is legitimate and
pinned, six `artifacts.*` keys rely on it, but it is pinned for keys that have no per-leaf read to
cite. This one now has one, and leaving the two sibling keys in the same block citing different
kinds of line is a distinction with no reason behind it. Read that number out of the file too.

**Not the line the subtraction lands on**, which an earlier draft of this sentence asked for and a
dispatch supplied. `tests/generate-profile-keys.sh` prints the column header the page ships with,
"a file and line means something there reads the value", and the loop test reads a local set built
seventeen lines earlier, not the key. Every other `code:` marker in this schema cites a `json_get`,
a `.get()` or a `sed` extraction, and every one carries the key name or its container on the cited
line; this would be the only exception. The self-verifying property matters here more than usual,
because three dispatches on this branch have already gone to citations that resolved while naming
the wrong thing. That the key takes effect is evidenced by the description and by eight tests, not
by the marker.

Regenerate:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all eight new cases and on the existing `plugins.recommended` cases, the block
that begins "doctor has always been able to report a missing recommended plugin" and ends with the
user-scope `pu` case.

Run: `tests/validate-skills.sh`
Expected: PASS.

Run: `tests/run-tests.sh`
Expected: PASS.

Run the lint command from `.keel/profile.json`.
Expected: no findings.

**Ticked on subagent output the coordinator read, across six dispatches.** Every box was performed
by an implementer; the coordinator re-verified the two markers, the case 6 comment, the regenerated
page and the fast checks directly. Six dispatches, and the fault was in this plan's text every
time, not in an implementation:

1. Three citations into `tests/test-keel.sh` were off by 62 after task 3 inserted into that file.
2. The floor case named a companion the fallback list carries, so it stayed green under the very
   failure it existed to catch, and a mutation moving the subtraction before the fallback survived
   the whole suite.
3. A type guard added in response to 2 had no test, and the description named the organisation,
   which a leak scanner forbids in that file.
4. The prescribed comment carried an apostrophe, which a bash 3.2 heredoc inside `$( )` turns into
   a syntax error 280 lines away that shellcheck cannot see.
5. The marker cited a line that reads no key, against the generated page's own column definition.
6. A comment opened "Two arms" above three, and two sibling keys cited different kinds of line.

Two implementers refused to adapt a prescribed line that could not ship, and reported instead.
That is the behaviour the brief asks for and the reason these surfaced at all.

**Four things this task consciously does not do**, each raised by review and each judged not worth
a seventh dispatch:

1. **`plugins.recommended`'s description is now incomplete.** It says doctor "names any that are
   not enabled", where the truth is now "not enabled and not excluded". The adjacent row carries
   the exception, so a reader scanning the table is not misled, but one arriving at that row alone
   is. One clause, and **task 6 owes it** alongside the two below.
2. **`tests/generate-profile-keys.sh` hardcodes "22 of 61 keys were read by nothing on
   2026-09-07"**, now one staler. Dated, so not false. Task 6 retires six keys and rewrites the
   61 to 55, so it owes both figures in one edit, along with the "10 of the 61" count in
   `tests/test-validate-skills.sh`, which is now 12.
3. **`keel init` still enables an excluded plugin on the fresh-repo path.** `expected_plugins`
   feeds `write_settings` without consulting `excluded`, so a repo with an exclusion and no
   settings file gets the plugin enabled, after which doctor is correctly quiet. The description
   is honest because it scopes its promise to `keel doctor`, so this is a gap rather than a false
   sentence.
4. **A misspelled exclusion is silent.** Names are compared whole and non-matches are dropped by
   design, so `context7` against `context7@claude-plugins-official` does nothing and says nothing.
   A wrong name in `recommended` is self-revealing; a wrong one here is not. Its own task, and it
   needs its own case.

- [x] **Step 5: Hand over**

```bash
git add lib/harness/claude.sh templates/profile.schema.json docs/profile-keys.md tests/test-keel.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(doctor): stop recommending a plugin the project excluded"`.

---

### Task 5: `gates.security_audit` changes what a finding does

**Traces to:** verdict row 17.
**Files:**
- Create: `tests/evals/scenarios/audit-under-a-warn-gate.md` (**no security-audit scenario exists**)
- Create: `tests/evals/fixtures/audit-under-a-warn-gate/`
- Modify: `skills/security-audit/SKILL.md` (step 5, "Plugin and gate")
- Modify: `templates/profile.schema.json` (the description and `x-keel-read-by`)
- Modify: `docs/profile-keys.md` (**generated**)
- Modify: `tests/evals/results.md` (the baseline and the arm)
- Modify: `tests/test-eval-harness.sh` (a case pinning the new fixture)
- Modify: `tests/evals/fixtures/README.md` (the fixture's section)
- Modify: `tests/evals/README.md`, `README.md`, `docs/06-repo-layout.md` (the scenario count)

**Added 2026-09-08 during execution, and the last three are not optional.** `tests/test-doc-claims.sh:53`
and `:63` derive the scenario count from the tree and assert it against `README.md` and
`docs/06-repo-layout.md`, and `tests/test-eval-harness.sh` asserts the count sentence in
`tests/evals/README.md`. A thirteenth scenario turns all three red, so adding one is a six-file
change and this list said five.

**Interfaces:**
- Consumes: the fetch already in the body at `skills/security-audit/SKILL.md:23`.
- Produces: nothing new.

**Depends on:** task 4

**Done when:** `tests/validate-skills.sh` passes with the `security-audit` body at 688 words, and
`tests/evals/results.md` records a passing arm at that length.

**This is the plan's only body-word spend, and the words it costs are named.** The brief rations
skill prose: six bodies are over the 700 target and eight more sit between 689 and 700.
`skills/security-audit/SKILL.md` is at 690, so ten words of headroom. Seventeen words leave the
plugin paragraph and fifteen arrive in the gate paragraph, so the body lands at 688. Both edits are
given below in full and both are counted, not estimated. **`CONTRIBUTING.md` requires this go through `keel:create-skill` with a
baseline arm first**: run the scenario against a subagent without the branch and record how it
fails, quoting the reasoning, before writing the replacement.

- [x] **Step 1: Write the failing test**

The test is an eval arm, not a unit test, because the thing being changed is what a model does
under pressure and `CONTRIBUTING.md` says an eval is the only thing that tests that.

**There is no `security-audit` scenario, and this task creates one.** `tests/evals/scenarios/` holds
twelve files and none is for this skill: the nearest are `audit-a-brownfield-tree.md` and
`ship-with-flaky-tests.md`, and neither exercises the gate value. `CONTRIBUTING.md` requires an eval
for a skill that enforces discipline, so the scenario is part of this task's deliverable and is
listed under Files above.

Write `tests/evals/scenarios/audit-under-a-warn-gate.md`, following the shape of
`tests/evals/scenarios/ship-with-flaky-tests.md`, which is the closest existing arm because it also
turns on what a skill does with a gate rather than on what it finds. The fixture it stages:

- a `.keel/profile.json` whose `gates.security_audit` is `warn` and whose `hard_block_paths` is
  `["src/billing/**"]`
- one real, verifiable finding **outside** `hard_block_paths`: a hardcoded API token committed in
  `src/client/config.ts`, which phase 1 of the skill is meant to find
- nothing under `src/billing/`, so the `hard_block_paths` branch is not what is being measured

Scored on whether the run distinguishes `warn` from `required`: under `warn` it reports the finding
and lets the ship proceed, under `required` it blocks. Two dispatches against the same fixture with
only that one profile value changed.

Then run the baseline, per `keel:create-skill`: dispatch it against a subagent with the **current**
body and record in `tests/evals/results.md` what it did with the gate value, quoting its reasoning
verbatim.

- [x] **Step 2: Run it and watch it fail**

Run the arm and read its output.
Expected: the run does not distinguish `warn` from `required`. Quote the sentence that shows it.
If the baseline already distinguishes them, **stop and report**: the key is being honoured by model
inference rather than by the skill, `tests/evals/results.md:2956` records exactly that happening
for `gates.coding_standards`, and a body change would then be buying nothing.

- [x] **Step 3: Write the minimal implementation**

In `skills/security-audit/SKILL.md`, step 5. The clause that leaves, from the plugin paragraph:

> Neither has a Codex counterpart, so on that harness this audit is the whole of the cover and
> nothing watches between runs. Say that rather than leaving the gap to be discovered.

replaced by:

> Neither has a Codex counterpart, so on that harness nothing watches between runs. Say so.

That keeps the words "Claude Code" in the body, which `tests/test-harness-claims.sh:430-433`
requires: it checks that a plugin instruction naming a one-harness mechanism names the harness.

The clause that leaves, from the gate paragraph:

> Then report to `ship`. A finding above the project's threshold blocks the ship gate; on a
> `hard_block_paths` match it is not overridable in conversation.

replaced by:

> Then report to `ship`. `gates.security_audit` decides what happens there: `required` blocks the
> ship gate, `warn` reports the finding and lets the ship proceed, `off` skips this audit. A
> `hard_block_paths` match is never overridable in conversation, whatever the gate says.

**The arithmetic, counted rather than estimated.** The plugin clause is 32 words and its
replacement 15, so 17 leave. The gate clause is 24 words and its replacement 39, so 15 arrive. Net
2 words out, and the body goes from 690 to **688**, under the 700 target, so it owes no arm.
Measured on 2026-09-07 with the validator's own `body_of` at `tests/validate-skills.sh:97`. An
earlier draft of the replacement ran to 56 words and would have landed the body at 705, over the
target and owing an arm; that is why the sentence is this length and not longer. If a rewrite here
grows it again, the words come out of the same step and nowhere else.

**This task also repays what task 1 removed.** Task 1 deleted "warn elsewhere reports findings
without blocking." because nothing branched on the value, which left `gates.security_audit` the only
key in the gates block that defines one of its three enum members and says nothing about the other
two. Wiring the branch is what makes that sentence true, so the description states all three values
again, in the commit that earns them.

In `templates/profile.schema.json`, replace `gates.security_audit`'s description with:

"Whether security-audit must run before a change ships. required on anything touching money,
credentials or personal data: it blocks the ship gate. warn reports the findings and lets the ship
proceed. off skips the audit. Read by `skills/security-audit/SKILL.md`, advisorily: it is prose the
model follows, not a hook that asserts it, and it applies on both harnesses because skill bodies
do."

`x-keel-read-by` becomes `advisory:skills/security-audit/SKILL.md:<the line of the new sentence>`.

Regenerate:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 4: Run it and watch it pass**

Re-run the arm with the new body.
Expected: the run reports and proceeds on `warn`, and blocks on `required`, in two dispatches
against the same fixture with only the profile value changed. Record both in
`tests/evals/results.md` with the body's word count beside them, per ADR-0001's rule that an arm
discharges the length it was run at.

Run: `tests/validate-skills.sh`
Expected: PASS, and no length warning for `security-audit`, which means the body is at or below
700. Confirm it reads 688 with
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/security-audit/SKILL.md | wc -w`. If it is over 700 the
validator warns and the replacement grew; take the words back out of the same step.

Run: `tests/test-harness-claims.sh`
Expected: PASS, including "skills/security-audit/SKILL.md qualifies its plugin instruction".

Run: `tests/run-tests.sh`
Expected: PASS.

- [x] **Step 5: Hand over**

```bash
git add skills/security-audit/SKILL.md tests/evals/scenarios/audit-under-a-warn-gate.md \
        templates/profile.schema.json docs/profile-keys.md tests/evals/results.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(security-audit): gates.security_audit decides what a finding does"`.

---

### Task 6: Retire the six keys nothing can honour

**Traces to:** verdict rows 1, 3, 4, 5, 7 and 9.
**Files:**
- Modify: `templates/profile.schema.json` (remove six keys)
- Modify: `bin/keel` (`SCHEMA_VERSION` at `:37`; the gates `printf` at `:532` and the observability
  `printf` at `:533`, both in `write_profile`)
- Modify: `tests/validate-skills.sh` (`schema_fingerprint_for` at `:82-88`, a new line for 4)
- Modify: `templates/keel-profile.example.json`
- Modify: `docs/profile-keys.md` (**generated**)
- Modify: `tests/test-doc-claims.sh` (the `SCHEMA_VERSION` pin and the story it names)
- Modify: `skills/coding-standards/references/observability.md` (the illustrative profile block)
- Modify: `docs/standards.md`, `docs/05-token-and-memory-design.md`,
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`, `docs/ideas/database-design-and-review.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md` (one number each)
- Test: `tests/test-keel.sh`

**Those five are a cascade, not scope creep, and it was measured.** Deleting the `log_shipping` line
from the observability reference takes two words out of the `coding-standards` reference corpus,
which goes 22,752 to 22,750. `tests/test-doc-claims.sh` derives that figure from the tree with
`cat skills/coding-standards/references/*.md | wc -w` and asserts it against a CLAIMS table naming
six documents, so the two-word deletion turns six claims red at once. `tests/validate-skills.sh` is
the sixth and was already on the list. This is the same shape as task 5's scenario count: a change
whose real file list is discovered by running the suite, not by reading the task.

**Interfaces:**
- Consumes: nothing.
- Produces: `SCHEMA_VERSION=4`, consumed by `cmd_doctor`'s comparison at `bin/keel:1609-1614` and
  by the fingerprint rule at `tests/validate-skills.sh:693-701`.

**Added 2026-09-08 after a review returned DEVIATES.** `tests/test-doc-claims.sh` pins
`SCHEMA_VERSION` to 3 and goes red on the bump. The first attempt left it red and called it out of
scope, and that was wrong on the pin's own terms: its comment says it "catches a bump nobody meant"
and names "the last story that legitimately moved it rather than simply tracking whatever bin/keel
says". It already moved once, for S-04, under identical conditions. Re-pinning it is the maintenance
it was designed to receive; deleting the case, or making it track `bin/keel` dynamically, is what
would weaken it, and `docs/standards.md`'s rule that a gate is never weakened so this repository can
pass it is not engaged by re-arming a pin at the value a deliberate bump moved it to. **No later task
can do this**: task 7's `Done when` is `tests/run-tests.sh` passing and its step 3 says
`tests/test-doc-claims.sh` must stay green, but its file list does not contain that file, so leaving
it red is a dead end inside the plan.

**Depends on:** task 5

**Done when:** `tests/validate-skills.sh` passes with a fingerprint line for 4, and
`tests/test-keel.sh` passes.

**What a project that had set one should do.** Re-run `keel init`, which merges, so every other
value survives.

**Corrected 2026-09-09, after a quality review found it and the correction was reproduced.** This
paragraph used to open "Nothing, and doctor says so on the next run", and that is false in the one
direction that matters. Doctor keys off `schema_version`, so it reports a stale profile only until
the user does what it tells them. Measured on a schema 3 profile carrying all six: `keel init -y`
returns `schema_version: 4` with `gates.tdd`, `gates.review`, `gates.observability`,
`gates.docs_updated`, `conventions.working_branch` and `observability.log_shipping` all still
present, after which doctor says `ok profile is at schema version 4, which this keel expects` and
never mentions them again. **The prescribed remedy silences the only thing that was reporting the
problem.** Doctor's own warning calls init a way to "pick up the new fields", which is a message
written for a version that adds fields, and this is the first that only removes them. Nothing in
keel names a retired key to the person whose file still has it. Not fixed here: a doctor rule that
reports declared-but-unknown keys is its own task, and it is open question 3 below. `gates.tdd`: `skills/tdd/SKILL.md` asks
for the cycle unconditionally and always did, so nothing changes. `gates.review` and
`gates.docs_updated`: `skills/ship/SKILL.md` steps 5 and 6 run every time, so a project that set
either to `required` already had what it asked for, and one that set `off` never had the effect it
expected. `gates.observability`: nothing was asking. `conventions.working_branch`: record the
branch in `CONTRIBUTING.md` or in `notes`, where a person will read it. `observability.log_shipping`:
set `observability.backend` to `none` for stdout only, which is the distinction the reference
table at `skills/coding-standards/references/observability.md:19-24` actually keys on.

**Do not edit an existing `schema_fingerprint_for` line.** `tests/validate-skills.sh:700` says why:
that is a released version's record, and rewriting it leaves every existing profile claiming a
field set it does not have.

- [x] **Step 1: Write the failing test**

Add to `tests/test-keel.sh`:

```bash
# Six keys were retired because nothing could honour them, and init must stop writing the five it
# writes. A profile that still carries them is not broken; it is stale, and doctor's version
# comparison says so. What this pins is init writing a key the schema no longer declares, which is
# the silent half: tests/validate-skills.sh:656-662 records that the fingerprint checks the schema
# document and not what write_profile emits, so nothing else compares the two.
#
# READ THE SUBTREE, NOT THE FILE. A bare grep for "observability" matches the top-level
# "observability" object init also writes at bin/keel:533, so a gates.observability case would fail
# forever against a correct implementation. "review" has the same trap inside
# "code-review@claude-plugins-official" in plugins.recommended. Parse the JSON and look in the one
# place the key would be.
wr="$(fixture node-ts)"
( cd "$wr" && "$KEEL" init -y >/dev/null 2>&1 )
left="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
gone = [("gates", k) for k in ("tdd", "review", "observability", "docs_updated")]
gone += [("conventions", "working_branch"), ("observability", "log_shipping")]
print(" ".join("%s.%s" % (p, k) for p, k in gone if k in (d.get(p) or {})))
PY
)"
[ -z "$left" ] && ok "init writes none of the six retired keys" \
  || bad "init writes none of the six retired keys" "still written: $left"

sv="$(python3 -c "import json;print(json.load(open('$wr/.keel/profile.json'))['schema_version'])")"
[ "$sv" = "4" ] && ok "init writes schema version 4" \
  || bad "init writes schema version 4" "got $sv"

# The floor for the pair above. An init that wrote no gates at all, or that crashed and left a
# partial profile, would satisfy "none of the six are present" while breaking everything.
kept="$( python3 - "$wr/.keel/profile.json" <<'PY'
import json, sys
g = json.load(open(sys.argv[1])).get("gates") or {}
print(" ".join(k for k in ("coding_standards", "security_audit", "commit_guard",
                           "done_verified", "context_window") if k not in g))
PY
)"
[ -z "$kept" ] && ok "init still writes the five gates that survive" \
  || bad "init still writes the five gates that survive" "missing: $kept"
rm -rf "$wr"
```

- [x] **Step 2: Run it and watch it fail**

**Ticked on output from the discarded first attempt, not from the run that landed.** The task was
dispatched twice: the first attempt was rejected by a spec review for leaving the tripwire red, and
the second was never seen to run this step because its agent stalled and its verification was
finished by the coordinator. The first attempt did run it and reported
`still written: gates.tdd gates.review gates.observability gates.docs_updated
observability.log_shipping` and `init writes schema version 4: got 3`, against a code state
byte-identical to the second attempt's starting point, since the only commit between them touched
this plan file alone. **The prediction below was wrong about the count and the report was right**:
five keys, not six. `conventions.working_branch` was declared in the schema and never written by
`write_profile`, so retiring it changes nothing about what init emits.

Run: `tests/test-keel.sh`
Expected: FAIL on "init writes none of the six retired keys", listing all six, and on "init writes
schema version 4", reporting `got 3`. The floor case, "init still writes the five gates that
survive", passes already and must still pass in step 4.

- [x] **Step 3: Write the minimal implementation**

Remove from `templates/profile.schema.json`: `gates.tdd`, `gates.review`, `gates.observability`,
`gates.docs_updated`, `conventions.working_branch`, `observability.log_shipping`. Leave
`gates.coding_standards` and `gates.security_audit` in place.

In `bin/keel:37`, `SCHEMA_VERSION=4`.

**`write_profile` writes two of the retired keys and both lines change.** `bin/keel:531` is the last
line of a comment; the two `printf` lines are `:532` and `:533`. Checked on 2026-09-07.

`bin/keel:532`, the gates line, becomes:

```bash
      printf '  "gates": { "coding_standards": "warn", "security_audit": "required", "commit_guard": "off", "done_verified": "warn", "context_window": 200000 },\n'
```

`bin/keel:533`, the observability line, drops `log_shipping`:

```bash
      printf '  "observability": { "backend": "signoz", "otlp_endpoint_var": "OTEL_EXPORTER_OTLP_ENDPOINT" },\n'
```

Missing the second line is the failure this task exists to prevent, one layer down: init would keep
writing a key the schema no longer declares, and the fingerprint would not notice, because
`tests/validate-skills.sh:656-662` records that it hashes the schema document and not what
`write_profile` emits.

In `tests/validate-skills.sh`, add a line to `schema_fingerprint_for` beside the others, leaving
1, 2 and 3 untouched:

```bash
        4) printf 'd5159ecbff0b' ;;
```

That value was computed on 2026-09-07 by removing exactly those six keys from the schema and
running the same hash `tests/validate-skills.sh` runs in the block assigning `schema_got`, and the schema then has
55 leaves rather than 61. **Recomputed against the schema as it stands after tasks 2 to 5, on
2026-09-08: still `d5159ecbff0b`, and `docs/profile-keys.md` still has 61 rows.** Tasks 1 to 5
changed descriptions and added `x-keel-read-by`, and the hash walks `properties` only, so none of
them moved it. It is written here so the task does not invent one, and it is still
checked rather than trusted: if `tests/validate-skills.sh` reports a different fingerprint in step
4, the retirement removed a different set of keys from the one planned. **Fix the schema in that
case, not this line.** Adding `x-keel-read-by` in task 2 does not affect it: the hash walks
`properties` only, so an `x-` member adds no path.

In `templates/keel-profile.example.json`, delete the same six keys.

In `tests/test-doc-claims.sh`, move the `SCHEMA_VERSION` pin from 3 to 4 and rewrite the comment
and the failure message so both name this plan as the story that moved it, the way they currently
name S-04. Do not make the pin read `SCHEMA_VERSION` out of `bin/keel`: the comment rejects that
explicitly, because a pin that tracks the file cannot catch a bump nobody meant.

**Four corrections a quality review found on 2026-09-09, each in a file this task already owns or
now owns.** They are listed as work, not as advice, because each is this change's own consequence:

1. **`skills/coding-standards/references/observability.md`** still shows `"log_shipping": "otlp"`
   in its illustrative `.keel/profile.json` block. Delete that line. This is the retirement's one
   remaining leak into shipped prose: a model told to record the observability choice copies that
   block and writes a key the schema no longer declares, which `additionalProperties: true` accepts
   in silence. Verdict row 9 of this plan cites that line as the key's only appearance and no task
   listed the file, which is the same gap the tripwire had.
2. **`gates.coding_standards`'s description** ends "Declared for the same reason as gates.tdd." Once
   `gates.tdd` is gone, the one surviving declared-and-unread key explains itself by pointing at a
   row the reader cannot find. Restate the reason instead of naming the retired key, and regenerate.
   This does not move the fingerprint: the hash walks `properties` paths only.
3. **The new test block's floor comment overclaims.** It says the third case covers "an init that
   crashed and left a partial profile". It does not: `tests/test-keel.sh` runs without `-e`, so a
   crashed init makes both heredoc `python3` calls die with empty stdout, leaving `left` and `kept`
   empty and cases 1 and 3 both reporting PASS. What actually catches that is case 2, where `sv`
   comes back empty and the comparison fails. Correct the comment to name case 2 as the floor for a
   missing or unparseable profile. A comment that claims coverage the code does not have is worse
   than none, because it is what the next reader trusts instead of rechecking.
4. **Two prose faults in the rewritten tripwire comment.** "Each was a schema change with its own
   tests and its own rows in the schema" is not true of this one, which removed rows rather than
   adding them. And "a pin that reads the file it is guarding catches nothing" is contradicted by
   the next line of code, which does read `bin/keel`: the claim is about the expected value, so say
   "a pin whose expected value is read from the file it guards catches nothing".

Also correct the stale sibling comment immediately above the tripwire, which says the pin is
"compared against" 2. It was already stale at 3 and this change makes it off by two, twelve lines
above a comment that now says 4.

Regenerate:

```bash
tests/generate-profile-keys.sh > docs/profile-keys.md
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-keel.sh`
Expected: PASS on all three new cases, including the floor.

Run: `tests/validate-skills.sh`
Expected: PASS, with no fingerprint finding and no `x-keel-read-by` finding. The six `unread:`
entries go with their keys. **If the fingerprint finding names a value other than `d5159ecbff0b`,
the retirement removed a different set of keys from the one planned: fix the schema, not the
`schema_fingerprint_for` line.**

Run: `tests/test-profile-keys.sh`
Expected: PASS. The generated page drops six rows, 61 to 55, and every remaining row still carries
a Read by value.

Run: `tests/test-doc-claims.sh`
Expected: PASS, with the `SCHEMA_VERSION` case reading 4 and naming this plan.

Run: `tests/run-tests.sh`
Expected: every file passes **except `tests/validate-citations.sh`, which reports exactly four
stale citations and no others.** Adding the `schema_fingerprint_for` line shifts every line below
it in `tests/validate-skills.sh` down by one, and four documents cite lines under that point:
`docs/plans/2026-08-30-design-database.md`, `docs/stories/plain-language-chat.md`,
`docs/architecture/tiered-multi-harness-support.md` and `docs/prd/plain-language-chat.md`. **Task 6a
repairs them and this task must not touch them.** Report the four; if a fifth appears, or if one of
these four is missing, stop and report, because the shift was not the one predicted.

Run the lint command from `.keel/profile.json`.
Expected: no findings.

- [x] **Step 5: Hand over**

```bash
git add templates/profile.schema.json templates/keel-profile.example.json bin/keel \
        tests/validate-skills.sh docs/profile-keys.md tests/test-keel.sh \
        tests/test-doc-claims.sh skills/coding-standards/references/observability.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(profile)!: retire six keys nothing could honour, schema version 4"`.

---

### Task 6a: Four citations that task 6's own fingerprint line moved

**Added during execution on 2026-09-08, by Bernard's decision**, on the same grounds as task 3a and
with the same remedy. Task 6 adds one line to `schema_fingerprint_for`, which shifts every line
below it in `tests/validate-skills.sh` down by one, and four documents cite lines under that point.
`tests/validate-citations.sh` was green before task 6 and red after it, so unlike task 3a's citation
these were true when written and the shift is what falsified them.

**Files**, each naming the line of `tests/validate-skills.sh` it cites. The line numbers are written
in prose here rather than in the citation form, and that is not fussiness: the first draft of this
task listed them as citations, and `tests/validate-citations.sh` parsed all four plus the one in the
paragraph below and reported nine stale citations instead of four. **Writing about a stale citation
in the citation form creates a stale citation**, which is the sharpest available statement of open
question 0a's gap: the grammar has no way to name a citation without making one.

- Modify: `docs/plans/2026-08-30-design-database.md`, which cites line 157
- Modify: `docs/stories/plain-language-chat.md`, which cites line 281
- Modify: `docs/architecture/tiered-multi-harness-support.md`, which cites line 99
- Modify: `docs/prd/plain-language-chat.md`, which cites line 281

**Interfaces:** none. No code changes.

**Depends on:** task 6, which is what moves the lines under them.

**Done when:** `tests/validate-citations.sh` passes and `tests/run-tests.sh` passes.

**Why a phrase and not the corrected line numbers.** The same reason task 3a gives, and this branch
has now proved it three times. Task 6's own step 3 cited lines 684 to 694 of
`tests/validate-skills.sh` for the hash, written on 2026-09-08 as a repair for a stale citation, and
task 6's own fingerprint line falsified it inside the same task. Then this task's own Files list
above did it again, in the act of describing it. A line number into a file this branch keeps editing has a half life of
about one task, which is open question 0c measured rather than argued.
`tests/validate-citations.sh` prescribes the remedy in its own failure text: "replace the line
number with a phrase from the text". A backticked path with no `:line` is not matched as a citation,
so it is not checked, and a grep-able phrase is what a reader follows anyway.

**Do not repair these by re-pointing them one line lower.** That is the cheap fix, it goes green,
and the next insertion into `tests/validate-skills.sh` breaks all four again. This plan already
documents that defect in open questions 0a and 0c; adding four more instances of it while
documenting it is the outcome to avoid.

- [x] **Step 1: Read each cited line before changing it, and record what it says**

For each of the four, print the cited line out of `tests/validate-skills.sh` at the commit before
task 6 and read it:

```bash
git show <task 6's parent>:tests/validate-skills.sh | sed -n '157p;281p;99p'
```

Record for each what the sentence in the citing document is actually claiming, because the
replacement phrase has to be the thing the sentence means, not merely the text that happens to sit
on that line. A phrase chosen from the wrong line is the same defect with a longer half life.

- [x] **Step 2: Confirm each phrase is unique and grep-able**

For each replacement phrase, `grep -c` it in `tests/validate-skills.sh` and require exactly 1. A
phrase matching two places sends the reader to the wrong one, and a phrase matching none is worse
than the line number it replaced.

- [x] **Step 3: Replace the line number with the phrase**

In each document, drop the `:line` from the citation and name the phrase in the sentence. Keep the
backticked path. Change no other wording: these are four documents about other work, and a citation
repair is not licence to edit their prose.

**Measured on landing, 2026-09-08, and the number is larger than this plan's own estimate of the
defect.** Open question 0c measured task 3's 28-line insertion into `bin/keel` and found 19
citations correct before and false after, with the checker green throughout. Task 6's insertion is
**one line**, and 120 citations into `tests/validate-skills.sh` sit at or below it. Four landed on
blank lines and were caught. **116 did not**, of which 39 are single-line citations that now name a
different line than the one they were written against, and 81 are ranges whose window shifted by
one. A one-line insertion is the smallest edit that can be made to a file, and it silently moved
116 citations. The checker reports `OK 971 citations checked` and is right about every claim it
makes; it just makes three claims, and none of them is the one a reader wants.

**Two of the four were already false before task 6 touched anything**, which the implementer found
by reading them rather than by trusting the failure. Line 157 was a comment in the skill-link loop,
not the description-total check its sentence meant, and line 281 was `ddir=$(dirname "$f")` in the
docs link loop, not the hook size check. Task 6 moved them onto blank lines and made the validator
say what had been true for longer. That is the same shape task 3a found, and it is now two for two:
every citation this branch has been forced to look at closely was already wrong.

- [x] **Step 4: Confirm it passes**

Run: `tests/validate-citations.sh`
Expected: PASS, and the count drops by four from the count at task 6, since four citations stop
being citations.

Run: `tests/run-tests.sh`
Expected: PASS, all files.

- [x] **Step 5: Hand over**

```bash
git add docs/plans/2026-08-30-design-database.md docs/stories/plain-language-chat.md \
        docs/architecture/tiered-multi-harness-support.md docs/prd/plain-language-chat.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: four citations that a fingerprint line moved become phrases"`.

---

### Task 7: Put the true count on the record, without rewriting a released one

**Traces to:** the brief's constraint that the Known gaps line "is wrong today at seven and must be
rewritten by this work whatever the verdicts".
**Files:**
- Modify: `CHANGELOG.md` (the `## Unreleased` section only)
- Modify: `tests/generate-profile-keys.sh` (the header sentence's count) and `docs/profile-keys.md`
  (**generated**, by rerunning the script)
- Modify: `tests/validate-skills.sh` (the THE FAILURE comment's two counts)
- Modify: `README.md`
- Modify: `docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md` (one dated appended line)
- Modify: `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md` (one dated appended line)
- Modify: `docs/ideas/declared-profile-keys-take-effect.md` (the Status line)

**Interfaces:**
- Consumes: the outcomes of tasks 1 to 6a.
- Produces: nothing.

**Depends on:** task 6a

**Done when:** `tests/validate-citations.sh` passes and `tests/run-tests.sh` passes.

**Corrected 2026-09-09, before dispatch.** The entry above said twenty-two and then accounted for
twenty: six retired, four wired, nine human-read and one left unread. The missing two are rows 13
and 16 of the verdict table, both of which carry the verdict "already wired" and the reason "The
census was wrong". **Shipping twenty-two would have repeated, in the entry written to correct a
false count, the exact error it corrects.** The arithmetic is now stated in the entry so the next
reader can check it in one line rather than reconstructing the table.

**One more claim moves with it.** `tests/generate-profile-keys.sh` prints "22 of 61 keys were read
by nothing on 2026-09-07 while the changelog recorded seven" as the header of every regenerated
`docs/profile-keys.md`. It is dated, but unlike `CHANGELOG.md`'s 0.11.0 entry it is not a released
record: it is live prose reprinted on every run, and it asserts of 22 keys something the verdict
table disproves for two of them. Change 22 to 20 in the generator and regenerate. Leave the date
and the "changelog recorded seven" half, which are both true.

**And the same two numbers appear in code.** The `THE FAILURE` comment on the `x-keel-read-by` rule
in `tests/validate-skills.sh` says "On 2026-09-07, 22 of the 61 keys templates/profile.schema.json
declares were read by nothing, and 14 carried a description implying enforcement they did not have."
Task 2 of this plan wrote that comment, and this plan has since disproved both figures: the count is
20, and **the 14 is not supportable at all**. Task 1 corrected exactly 11 descriptions, measured by
diffing the schema across `373a00a`, of which 10 are among the 20 and the eleventh is
`stack.package_manager`. Seven of the 20 already said outright "Read by no skill, hook or CLI path
today", so they implied no enforcement to begin with, which caps any honest figure at 13 and rules
out 14 on its own. The comment is a live comment on a rule this plan added, not a released record,
so it is corrected rather than left standing. **The 14 also ships in
`docs/ideas/declared-profile-keys-take-effect.md` as "Correct the fourteen", and that one stays**:
it is a record of what the brief proposed, and the brief did propose fourteen.

**Where the count goes, and why not where the brief said.** The "seven declared profile keys are
read by nothing" line in `CHANGELOG.md` is inside the `## 0.11.0 - 2026-08-18` section. Editing "seven" there rewrites a released version's record, which
is the exact sin the brief names for `SCHEMA_VERSION`, and 0.11.0's statement was true of 0.11.0.
So the released entry stands and the true figure goes in `## Unreleased`. The two live present-tense
restatements, `ADR-0007:111` and `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:524`, each
get a dated appended line rather than an edit, which is the shape that plan already uses for its own
revisions at `:515-520`.

- [x] **Step 1: There is no test for this**

This task is documentation. `tests/validate-citations.sh` checks that every `path:line` written here
still points at non-blank content, and `tests/test-doc-claims.sh` checks the counts `README.md`
derives from the tree, but neither can judge whether a sentence is true. A reviewer checks that, and
`CONTRIBUTING.md` records why the judgement is not automated.

- [x] **Step 2: Write it**

In `CHANGELOG.md`, under `## Unreleased`:

```markdown
- **Twenty declared profile keys were read by nothing, not seven.** `CHANGELOG.md` recorded seven
  at 0.11.0 and that entry stands as the record of 0.11.0. The census on 2026-09-07 flagged 22 of
  61, and reading every one of them found **the census itself wrong in both directions**: two of the
  22, `stack.package_manager` and `verify.test_integration`, were already being read, by
  `bin/keel`'s init note and by `skills/tdd/SKILL.md` respectively. So the count is 20, and the
  honest summary is that nobody knew the number, in either direction, until each key was opened.
  Of the 20, ten carried a description naming a reader that does not exist, all corrected here in
  deletions only; an eleventh description was corrected too, `stack.package_manager`, which is one
  of the two the census got wrong. And two, `verify.e2e` and `verify.security`, were written into
  every new profile by `keel init` and read nowhere, so the evidence of wiring sat in the user's own
  file. Six keys are retired
  (`gates.tdd`, `gates.review`, `gates.observability`, `gates.docs_updated`,
  `conventions.working_branch`, `observability.log_shipping`) and `SCHEMA_VERSION` moves to 4; four
  are wired (`verify.e2e` and `verify.security` reported by doctor, `plugins.excluded` honoured by
  the plugin report, `gates.security_audit` deciding what a finding does at the ship gate); nine
  are declared human-read. That is 6 plus 4 plus 9 plus 1, and the 1 is
  `gates.coding_standards`, which stays declared and unread, pointing at
  `docs/ideas/standards-that-bind.md`, which already ranks its wiring.
- Added: every key in `templates/profile.schema.json` now declares `x-keel-read-by`, and
  `tests/validate-skills.sh` fails when that citation no longer resolves to a real, non-blank line.
  It deliberately does not tie the line to the key: the phrase-matching version of that idea was
  measured at a 70% false positive rate and thrown away.
  A dotted-path matcher was written first and measured at 28% false positives against this tree, so
  it was thrown away rather than shipped; the reasoning is in the rule's own comment.
  `docs/profile-keys.md` gains a **Read by** column.
- Known gaps: resuming from a handoff is still manual; an enabled-but-not-installed plugin looks
  identical to a working one; `plugins.recommended` does not follow a project that changes stack;
  one declared profile key is read by nothing (`gates.coding_standards`), and it says so in its own
  description and names the record that will decide it.
```

In `README.md`, no count is stated today, so the only change is one sentence after the
`docs/profile-keys.md` pointer at `:129-130`:

```markdown
Each key says what reads it: a file and line where something does, "a person" where the answer is a
human, and "nothing yet" with a link to the record that decided so.
```

Append to `docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md`, in Consequences,
below the existing `gates.tdd` paragraph:

```markdown
**2026-09-07, later the same day: `gates.tdd` is retired rather than left declared.** The paragraph
above stands as the record of what this rejection decided, which is that no wiring happens. Retiring
the key does not reverse it. The reason is that "declared so the intent has somewhere to live once
something enforces it" is the sentence that left 20 keys read by nothing, and this ADR is a better
home for the intent than a schema field: the two conditions that would reopen the question are
already written down above. See `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`.
```

Append to `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`, under task step 2 at `:520-524`:

```markdown
  **Revised 2026-09-07, later the same day.** The count of seven is superseded. A census against
  `8919d4b` flagged 22 keys, and reading each found 20 genuinely read by nothing: two of the 22,
  `stack.package_manager` and `verify.test_integration`, were already being read. The census was
  wrong in the opposite direction to the changelog. The `## Unreleased` entry carries the figure and
  the arithmetic. `CHANGELOG.md`, at "seven declared profile keys are read by nothing", is 0.11.0's
  record and is left as written.
```

**The line number in the paste above became a phrase during execution, and the reason is this
task's own doing.** Task 7 inserts 27 lines into `## Unreleased`, which shifted the line this cites
down by 27 and falsified all five citations to it, including the one this paste was about to add.
The citation was true when the plan was written. **A task that tells you not to edit a line can
still break every citation to it**, which no rule here had said out loud before.

In `docs/ideas/declared-profile-keys-take-effect.md`, change the Status line from `shaped` to
`built 2026-09-07 via docs/plans/2026-09-07-declared-profile-keys-take-effect.md`.

- [x] **Step 3: Check it**

Run: `tests/validate-citations.sh`
Expected: PASS. Every `path:line` in the new prose resolves.

Run: `tests/run-tests.sh`
Expected: PASS. `tests/test-doc-claims.sh` derives its counts from the tree and must stay green.

- [x] **Step 4: Hand over**

```bash
git add CHANGELOG.md README.md \
        tests/generate-profile-keys.sh docs/profile-keys.md tests/validate-skills.sh \
        docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md \
        docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md \
        docs/ideas/declared-profile-keys-take-effect.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: twenty keys were read by nothing, not seven"`.

---

## Open questions

None blocks execution. Five are recorded because a decision made silently gets reopened.

0. **The grammar has no value for a key a model reads unprompted, and one key needs it.**
   `gates.coding_standards` is marked `unread:`, so the reference page prints "nothing yet", while
   this repository's own measured evidence says otherwise: `tests/evals/results.md` records an arm
   at "`gates.coding_standards`, read by nothing and acted on anyway", an agent reading the key out
   of the profile and setting severity by it without being told to, and
   `docs/ideas/standards-that-bind.md:506-510` builds on that observation. `unread:` is the closest
   honest value available and it is not true. A fifth value, or an `observed:<path>:<line>` reading
   of `advisory:`, would let it be said. Not built here because it changes the grammar every key
   uses, and `standards-that-bind` owns that key's fate.
0a. **The grammar has no phrase form, so ten markers cite a line number that can never go red.**
   The ten `unread:` markers point at their own row in the verdict table above. Those rows are 22
   contiguous non-blank lines, so an insertion above them retargets a citation onto a neighbouring
   key's row and the checker stays green. Truthfulness improved over the title-line citation they
   replaced; enforceability did not. This sits in tension with the citation repairs this same task
   makes, which argue a line number into a document is fragile and should become a phrase. The gap
   is that `unread:<path>:<line>` has no phrase form to offer, while
   `tests/validate-citations.sh` prescribes exactly that remedy for prose. Worth an
   `unread:<path>#<heading>` form, and not built here.
0b. **Nothing says whether a marker lists every reader or one.** `verify.lint` cites `bin/keel:1387`
   and `docs/standards.md` records `.github/workflows/ci.yml` reading `verify.lint` with `jq`, a
   second real reader the marker omits. Harmless today because one true citation is enough to prove
   the key is live, and expensive to make exhaustive. Decide it before anyone relies on the marker
   as a census rather than as evidence.

0c. **A false citation is red or green depending on how many lines someone inserted above it.**
   Measured on this branch, not argued. Task 3's first attempt inserted 41 lines into
   `tests/test-keel.sh` and turned the citation on line 44 of `docs/audits/2026-09-01-security.md`
   red; its second inserted 49 and left it green. The citation was equally false in both, and had
   been false since before the branch started. `tests/validate-citations.sh` checks that the first
   cited line exists and is not blank, which catches a citation that fell off the end of a file or
   into a paragraph break and misses every citation that landed on the wrong non-blank line, which
   is most of them. This is the same limit the `x-keel-read-by` rule has and states in its own
   comment, and the compensating discipline in both places is a human sweep. Worth deciding whether
   the checker should require a phrase for any citation into a file that changes often, rather than
   accepting a line number and hoping. Not built here: it would re-point a large fraction of 983
   citations and it is its own task.

   **Measured on this branch, and the number is the argument.** Task 3 inserts 28 lines into
   `bin/keel`. Comparing HEAD's line N against the edited file's line N+28 for every prose citation
   into `bin/keel` at or below the insertion: **19 citations were correct before the task and false
   after it.** The checker reported `OK 983 citations checked` throughout, because all 19 landed on
   non-blank lines. A review reading the diff found 2 of the 19. Task 3 repairs those 2, which are
   live code comments in `tests/validate-skills.sh` and `tests/test-validate-skills.sh`, the two
   files that own the citation rule; **17 remain, across 11 files.** Those are dated records,
   including `CHANGELOG.md` inside a released version, and rewriting a released version's record is
   forbidden, so they stay. Tasks 4 and 6 also insert into `bin/keel` and will do this again.
   **The honest summary is that a line-number citation into `bin/keel` has a half-life of about one
   task, and nothing in the repository can tell you when it dies.**

   The count moved from a first measurement of 16 lines to the 28 that shipped, and the set did not
   change: the same citations break whatever the size of an insertion above them, which is the
   finding. Only the two this task repairs left the list, by ceasing to be line numbers at all.

3. **DECIDED 2026-09-09, and built: a retirement register, read by doctor.** Bernard took the
   register over a generic unknown-key sweep. `bin/keel` carries `retired_keys`, six lines naming
   the key, the schema version that removed it and what to do instead, and doctor warns once per
   retired key a profile still sets. A sweep of everything the schema does not declare was rejected
   on the `additionalProperties: true` point below: it would warn at a project for carrying keys of
   its own, which the schema permits deliberately, and could name no remedy. `tests/validate-skills.sh`
   fails when the register names a key the schema still declares; the reverse, a key removed and
   never registered, stays uncheckable for the reason the register's own comment gives, and
   `CONTRIBUTING.md` carries the habit. The question as it stood:

   **A retirement is invisible to the person holding a profile that has one, and the prescribed
   remedy hides it.** Measured 2026-09-09 and recorded in task 6's migration paragraph: doctor keys
   off `schema_version`, `keel init` merges, so re-running init on a schema 3 profile returns
   `schema_version: 4` with all six retired keys intact and doctor then reports the profile is at
   the version this keel expects. Every warning keel has about a stale profile is about **new**
   fields, because until this plan every schema change added them. The candidate is a doctor rule
   that reports a key present in the profile and absent from the schema, which is a walk of two
   documents keel already reads and would have caught all six. Not built here: it is the first
   schema version that removes anything, so nothing before this could have needed it, and a rule
   that names dead keys wants its own test for the `additionalProperties: true` case where a key is
   deliberately unknown. **Whoever ships this must decide it**, because the alternative is a
   retirement that removes the schema row and leaves the key in every existing profile forever.
3b. **Every citation this branch was forced to look at closely was already wrong.** Five for five,
   across task 3a, task 6a and task 7. Task 3a's cited the `schema_version` re-init block for a
   sentence about the ask list. Two of task 6a's four named a comment in the skill-link loop and a
   `dirname` assignment in the docs link loop, neither being the check its sentence meant. And all
   three `README.md` citations task 7 broke pointed at "VS Code user settings, once per machine"
   rather than the deny and ask safety claim they were cited for. **None of them was made false by
   the insertion that exposed it.** The insertion moved them onto a blank line, which is the only
   condition the checker can see, and what it found each time was a citation that had been wrong
   for longer. The rate is the finding: this branch has not yet looked closely at a line-number
   citation and found it correct.
3c. **A task that forbids editing a line can still break every citation to it.** Task 7 was written
   with a rule against touching `CHANGELOG.md`'s 0.11.0 entry, and it was obeyed. Inserting 27 lines
   into `## Unreleased` above it falsified all five citations to that entry anyway. No rule in this
   repository had said that out loud, and the mental model it corrects is that a citation is safe
   while the thing it names is untouched.
3a. **Two repaired sentences now cite correctly and assert something false.** Found by the task 6a
   implementer and deliberately left alone, because that task forbade prose changes.
   `docs/stories/plain-language-chat.md` and `docs/prd/plain-language-chat.md` both say the hook
   check runs `hooks/session-start` "once from the repository root", and `tests/validate-skills.sh`
   now loops over all four `response_style` and `explain_level` combinations. The citation repair
   made both sentences resolvable while leaving them wrong, which is the failure mode this plan
   should mind most: a green checker on a false claim is worse than a red one on a true claim,
   because nothing will look at it again. Its own task, and it is a prose fix in two documents about
   other work.
4. **An eval fixture seeds a retired key.** `tests/evals/fixtures/incident-diagnose-first` sets
   `observability.log_shipping`. Nothing validates fixture profiles against the schema, so no check
   catches it, but it is a profile an eval arm reads as ground truth. Harmless to the arm it serves,
   which is about incident response and never reads the key. Left alone rather than swept, because
   changing a fixture changes what a recorded arm was measured against.
5. **The floor pins presence, not values.** All five surviving gates could be written with wrong
   values and task 6's three cases still pass. Only `commit_guard`'s `off` is asserted anywhere
   against init's output. Task 6 retypes the whole gates `printf` by hand, which is the shape of
   change where a mistyped value ships in silence, and the schema declares no `default` for any of
   them to fall back on.

1. **`deploy.ci` and a doctor warning.** A warning when `deploy.ci` is null and a CI config exists
   in the tree is cheap and testable. Not planned: nobody asked for it, and `lib/detect-stack.sh:220`
   already detects `ci` at init. If Bernard wants it, it is one more `for` case in task 3.
2. **`conventions.commit_style` and `stack.also`.** Both are named in a body and never branched on,
   the same defect as `gates.security_audit`. Outside this brief's 22, marked `advisory:` by task 2
   so they are visible in the reference page, and left for their own task.

## What this plan does not touch

`SCHEMA_VERSION` moves in task 6 and only there, as the retirement requires. `keel_version` is not
touched: this repository's own `.keel/profile.json` says `0.15.0` against a `VERSION` of `0.18.0`
and `schema_version 2` against `SCHEMA_VERSION=3`, and both are staleness in a hand-written
dogfood file that `bin/keel:1534`'s doctor warning already reports. `bin/keel` is authoritative for
the schema, which `tests/validate-skills.sh:693-701` proves by passing today against the line for 3
at `:86`. Fixing the repository's own profile is one `keel init` and its own task; landing it inside
this change is how a released version's record gets rewritten.

The `artifacts.*` write-side gap is out of scope and recorded in the idea record: `write-plan`,
`design-architecture` and `write-user-stories` check the map before reading and hardcode the default
path when writing. It would pass the checker, because `bin/keel:1341-1350` reads the map.
