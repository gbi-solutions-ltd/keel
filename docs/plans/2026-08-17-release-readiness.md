# Release Readiness Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close the four things standing between 0.8.0 and a release: the decision-2 drift that
nothing enforces, the model pins that ship undocumented, the root documents that assert numbers no
longer true, and the snapshot's habit of naming a gap without naming the tool that fills it.

**Stories:** none written. Scope comes from four items raised by Bernard on 2026-08-17, with three
open calls settled in the same exchange:

1. Decision 2's GBi extraction list has drifted and no check catches it. **Settled:** fix reality to
   match the decision, and enforce it.
2. Model pins on subagent briefs. **Status: already built** at 0.8.0, documented only in
   `docs/standards.md`. Scope here is documentation, not code.
3. Root `*.md` files brought up to date, plus guidance for making the repository public.
   **Settled:** guidance only. Nothing flips in this plan.
4. The snapshot should recommend a tool per gap. **Settled:** one shared reference under
   `skills/keel/references/`, cited by the snapshot's section 10.

**ADRs:** ADR-0001 bounds every skill body. Task 1 only removes or exchanges words, so no body
grows; task 7 adds nothing to a body at all.
**Architecture:** no new subsystem. One new check in the leak scanner, one new test file, one new
shared reference, one new validator rule, one new runbook. Everything else is prose in files that
already exist.

## Global constraints

Copied from `.keel/profile.json` and the repository conventions. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`
- There is no format, typecheck, build or e2e command in this project. Where a step would need one,
  it says so rather than substituting a guess.
- `verify.lint` globs `tests/*.sh`, so the test file task 3 adds is linted without touching the
  profile. Contrast task 5 of the 2026-08-16 plan, which added `hooks/done-guard` and had to extend
  `verify.lint` in the same task because the hook list is literal.
- The full suite is **about four and a half minutes** (270.0s measured 2026-08-17). Run it in the
  background and read the last line. It is not seconds, whatever `README.md` currently says.
- Never start on `main`. Work lands on `sandbox` and reaches `main` as a pull request.
- No em dashes, no en dashes, no attribution footers, no robot emoji, in code or commit messages.
- Skill bodies: 700-word target, 900 hard ceiling, and a body over 700 requires a passing eval arm
  at that length recorded in `tests/evals/results.md`. No task here may push a body over 700.
- `docs_root` is `docs`. Artifacts go to `docs/plans/`, `docs/ideas/`, `docs/runbooks/`.

## What this plan deliberately does not do

- **It does not make the repository public.** Task 5 writes the runbook that would. Nothing in this
  plan changes visibility, moves the deny list, deletes a reference file, or touches git history.
- **It does not build model routing.** `docs/ideas/model-routing.md` records why a complexity router
  keys on the wrong variable and why session-level switching is unavailable to a plugin. Task 2 is
  documentation of what shipped.
- **It does not build the posture baseline** that diffs two snapshot runs. That is open question 2
  of `docs/ideas/snapshot-surfaces-remediation-gaps.md` and is a different size of thing.
- **It does not fold the audits into the snapshot.** Task 7 adds a tool name and a reason to a
  recommendation the snapshot already makes. Section 8's refusal to audit stands.

## Findings this plan rests on

Established by reading the tree on 2026-08-17, so no task has to rediscover them.

| Finding | Evidence |
|---|---|
| Exactly **eight** files under `skills/` name GBi outside the five declared reference files | `grep -rlE '\bGBi' skills/ templates/` minus the five, listed in task 1 |
| Four of the eight are `SKILL.md` bodies, which decision 2 says must never carry it inline | `coding-standards`, `setup-deployment`, `security-audit`, `debug` |
| `tests/no-internal-leaks.sh` never checks for GBi at all | Its `DENY` array contains no such entry. Decision 2 asked for one at 0.1.0 |
| `templates/` names `gbi-solutions-ltd` twice, legitimately, as a JSON Schema `$id` and `$schema` URL | `templates/profile.schema.json:3`, `templates/keel-profile.example.json:2`. Task 1's check is scoped to `\bGBi` for this reason, and task 5 records the coupling |
| Model pins shipped and are enforced | `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea` name `sonnet`; `execute-plan/references/subagent-prompts.md` keeps implementation and both reviews on `inherit`; `tests/validate-skills.sh:189-202` rejects an unknown alias |
| The suite is 270.0s, not seconds | `docs/plans/2026-08-17-suite-runtime.md` results table. `tests/run-tests.sh:2` already says four and a half minutes; `README.md` and `CONTRIBUTING.md` still say seconds |
| `keel doctor` is no faster after the perf work | Same table: 1.575s to 1.551s on a fixture, because its time goes on running verify commands |
| There are six eval scenarios, five of which discriminate | `ls tests/evals/scenarios/` is six files; `tests/evals/results.md` records `done-without-verifying` passing in both arms and calls the scenario invalid |
| `supply-chain-scan.sh --list-rules` prints 24 ids, five of them structural | `tests/supply-chain-scan.sh --list-rules \| wc -l` is 24; `grep -c structural` is 5. README says four structural |
| `docs/07-open-decisions.md` has eleven numbered sections, all resolved | Its own status line, plus sections 10 and 11 added after the table was written. README says "Nine decisions: 5 resolved, 4 open" |
| `keel guard install` writes **two** hooks | `bin/keel:1629-1631` writes `pre-push` and `pre-commit`. README's Tests section names only the pre-push one |
| `skills/ship` is credited nowhere in `SOURCES.md` | `grep -n ship SOURCES.md` matches only table headers. SOURCES.md claims originals are listed by name rather than left to "everything not above" |
| No `SKILL.md` carries a source trailer | `grep -rn superpowers skills/*/SKILL.md` is empty. SOURCES.md line 9 asserts that close adaptations name their source in a trailer, which is false for all five |
| `CHANGELOG.md` calls the project `gbaiutils` | `CHANGELOG.md:3` |
| The 1.0.0 gate requires an install "using only `gh` auth" | `IMPLEMENTATION-PLAN.md:568-569`, contradicted by decision 2's own correction that `gh` is not required at all |
| Shared references live under `skills/keel/references/` and are cited `../../keel/references/x.md` from a reference file | Six skills cite `asking-questions.md` that way |
| `tests/test-validate-skills.sh` builds fixture roots with no `lib/` and no `skills/repo-snapshot` | `fixture_valid` at line 21. Any rule reading those paths must guard on existence, as the section-10 rule at `validate-skills.sh:266` already does |
| Languages the CLI detects are enumerated by `lang_profile`'s case labels | `lib/detect-stack.sh:214-268`: typescript, javascript, go, php, python, rust, java, kotlin, csharp, ruby, swift, cpp, lua |

## Open questions

None block a task. One is recorded because it is the user's call and task 8 asks it:

1. **Does this work carry a version bump?** Recommended `0.9.0`, folding in the unreleased perf
   paragraphs that chose not to number themselves. Task 8 asks rather than assumes.

---

### Task 1: Enforce decision 2's extraction list, and make the tree obey it

**Kind:** `build`. The check does not exist; the drift is real and measured.
**Files:**
- Modify: `tests/no-internal-leaks.sh`
- Modify: `tests/test-no-leaks.sh`
- Modify: `skills/coding-standards/SKILL.md`
- Modify: `skills/setup-deployment/SKILL.md`
- Modify: `skills/security-audit/SKILL.md`
- Modify: `skills/debug/SKILL.md`
- Modify: `skills/coding-standards/references/standards-template.md`
- Modify: `skills/coding-standards/references/resilience.md`
- Modify: `skills/review-code/references/rubric.md`
- Modify: `skills/write-prd/references/questionnaire.md`
- Modify: `docs/07-open-decisions.md`

**Interfaces:**
- Consumes: nothing. The new check is self-contained inside the scanner.
- Produces: `GBI_ALLOWED`, the declared five-file set, read by nothing else. The scanner's exit code
  and message format are unchanged, so `tests/run-tests.sh` needs no edit.
- Word cost: every edit is neutral or negative except `debug`, which gains four words. Bodies stay
  under 700; step 4 measures rather than assumes.

**Done when:** `tests/test-no-leaks.sh` passes with its three new cases, `tests/no-internal-leaks.sh`
against this repository prints `OK    no project-specific identifiers`, and `tests/run-tests.sh`
reports `All test files passed`.

**Why the new check is not a `DENY` entry.** `DENY` drives the coverage assertion at the bottom of
`tests/test-no-leaks.sh`, which fires every pattern from one sample file written to `docs/`. This
rule deliberately ignores `docs/`, so a `DENY` entry for it could never be exercised by that sample
and the coverage check would fail. It is a separate scoped rule with its own cases.

**Why `\bGBi` and not `gbi-solutions`.** `templates/profile.schema.json` and
`templates/keel-profile.example.json` carry `gbi-solutions-ltd` inside the canonical schema URL,
which is correct and must not be reported. Decision 2 asked for a `gbi-solutions` check; the honest
version of it is scoped to prose, and the URL coupling goes in task 5's runbook instead.

- [x] **Step 1: Write the failing test**

Add three cases to `tests/test-no-leaks.sh`, immediately after the `m_cotenant` case and before the
`# ---- coverage` banner:

```bash
# Decision 2 keeps GBi-specific content in five named reference files, so publishing is a deletion
# rather than an audit of twenty. Nothing enforced that until 2026-08-17, by which point the name
# had reached eight more files including four SKILL.md bodies the decision says must never carry it.
m_gbi_in_skill() { printf '\nBoth were found in real GBi repositories.\n' >> "$1/skills/example/SKILL.md"; }
run "GBi in a SKILL.md is rejected" 1 m_gbi_in_skill

m_gbi_in_ref()   { mkdir -p "$1/skills/example/references"; printf 'GBi builds payments systems.\n' > "$1/skills/example/references/r.md"; }
run "GBi in an undeclared reference is rejected" 1 m_gbi_in_ref

# The declared set must still pass, or the rule bans the files it exists to protect.
m_gbi_allowed()  { mkdir -p "$1/skills/coding-standards/references"; printf '# GBi defaults\n\nConventions across GBi repositories.\n' > "$1/skills/coding-standards/references/gbi-defaults.md"; }
run "GBi in a declared reference is allowed" 0 m_gbi_allowed

# docs/ and README name GBi legitimately and are not part of the extraction.
m_gbi_in_docs()  { printf '\nGBi ships this to every repository.\n' >> "$1/docs/install.md"; }
run "GBi outside skills and templates is allowed" 0 m_gbi_in_docs
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-no-leaks.sh`
Expected: FAIL. Two cases report `expected exit 1, got 0`, because the scanner has no such rule.
The two allow cases pass for the wrong reason, which is why both violation cases exist.

Then run: `tests/no-internal-leaks.sh`
Expected: PASS today, `OK no project-specific identifiers`. Record that, because after step 3 it
must fail on exactly eight files, and that transition is the real RED for this task.

- [x] **Step 3: Add the rule**

In `tests/no-internal-leaks.sh`, after the `DENY+=( '/Users/[a-z]' '/home/[a-z]' )` line and before
the `--list-patterns` block, add:

```bash
# Decision 2 in docs/07-open-decisions.md keeps GBi-specific content inside named reference files,
# so a public release is deleting five files rather than auditing twenty. Nothing enforced it, and
# by 2026-08-17 the name had spread to eight more files, four of them SKILL.md bodies the decision
# says must never carry it inline. A decision with no check is a decision that has already drifted.
#
# Scoped to skills/ and templates/, which are what ships into a consuming project. README, docs/,
# CHANGELOG and the tests name GBi correctly and are not part of the extraction.
#
# Deliberately not a DENY entry: DENY drives the coverage assertion in tests/test-no-leaks.sh, which
# fires every pattern from one sample under docs/, and this rule ignores docs/ by design.
#
# The pattern is `\bGBi`, the branded form in prose, and not `gbi-solutions`. The latter is correct
# inside templates/profile.schema.json and templates/keel-profile.example.json, which carry the
# canonical schema URL. That coupling is recorded in docs/runbooks/going-public.md instead.
GBI_ALLOWED=(
    'skills/coding-standards/references/gbi-defaults.md'
    'skills/coding-standards/references/observability.md'
    'skills/coding-standards/references/authorisation.md'
    'skills/security-audit/references/payments-checklist.md'
    'skills/setup-deployment/references/pipeline-patterns.md'
)

gbi_allowed() {
    local a
    for a in "${GBI_ALLOWED[@]}"; do
        [ "$1" = "$a" ] && return 0
    done
    return 1
}
```

Then inside the `while IFS= read -r f` loop, immediately after the `for pat in "${DENY[@]}"` loop
closes and before `done < <(list_files)`, add:

```bash
    case "$f" in
      skills/*|templates/*)
        if hit=$(grep -nE '\bGBi' "$f" 2>/dev/null | head -1); then
            if [ -n "$hit" ] && ! gbi_allowed "$f"; then
                report "$f: names GBi outside the declared set. Decision 2 keeps it in ${#GBI_ALLOWED[@]} named reference files and never in a SKILL.md -> ${hit%%:*}: $(printf '%s' "${hit#*:}" | cut -c1-70)"
            fi
        fi
        ;;
    esac
```

- [x] **Step 4: Run it and watch both halves fail**

Run: `tests/test-no-leaks.sh`
Expected: PASS, all cases including the four new ones.

Run: `tests/no-internal-leaks.sh`
Expected: FAIL, `8 leak(s)`, naming exactly these files and no others:

```
skills/coding-standards/SKILL.md
skills/coding-standards/references/resilience.md
skills/coding-standards/references/standards-template.md
skills/debug/SKILL.md
skills/review-code/references/rubric.md
skills/security-audit/SKILL.md
skills/setup-deployment/SKILL.md
skills/write-prd/references/questionnaire.md
```

A ninth file means the allowlist is wrong. Fewer than eight means the pattern is not matching.
Stop and fix the rule before touching any prose.

- [x] **Step 5: Neutralise the eight**

Eight exact replacements. Each keeps the sentence's meaning and its reason; none removes a rule.

`skills/coding-standards/SKILL.md`, line 69. The link target keeps its filename, which is the
declared file:

```
-Include the GBi defaults from [references/gbi-defaults.md](references/gbi-defaults.md), noting any
+Include the house defaults from [references/gbi-defaults.md](references/gbi-defaults.md), noting any
```

`skills/setup-deployment/SKILL.md`, line 26:

```
-Both of those have been found in real GBi repositories. Check them explicitly.
+Both of those have been found in real repositories. Check them explicitly.
```

`skills/security-audit/SKILL.md`, lines 43 to 44:

```
-   [references/payments-checklist.md](references/payments-checklist.md). This is where GBi's real
-   risk is, and generic tooling does not cover it.
+   [references/payments-checklist.md](references/payments-checklist.md). This is where the real
+   risk is, and generic tooling does not cover it.
```

`skills/debug/SKILL.md`, lines 26 to 28. The name carried the only signal that the claim is
conditional, so the replacement states the condition instead of dropping it:

```
-   skipping to the code is how you miss it. A GBi service's error log carries `op`, `actor`, and a
-   `remediation` field naming the skill to use: start from those rather than the stack.
+   skipping to the code is how you miss it. A service following the observability standard logs
+   `op`, `actor`, and a `remediation` field naming the skill to use: start from those rather than
+   the stack.
```

`skills/coding-standards/references/resilience.md`, line 3:

```
-Read this whenever anything calls anything else over a network, which is every service GBi builds.
+Read this whenever anything calls anything else over a network, which is nearly every service.
```

`skills/review-code/references/rubric.md`, lines 129 to 130:

```
-A caller can submit a UGX payout against a KES account and the ledger will accept it. FR-07 and
-the GBi money defaults both require the currency to come from the account.
+A caller can submit a UGX payout against a KES account and the ledger will accept it. FR-07 and
+the house money defaults both require the currency to come from the account.
```

`skills/write-prd/references/questionnaire.md`, line 80:

```
-- Who uses this, and are they inside GBi or outside?
+- Who uses this, and are they inside the organisation or outside?
```

`skills/coding-standards/references/standards-template.md`, three occurrences at lines 15, 74
and 77:

```
-| Departures from GBi defaults | listed in the last section |
+| Departures from the house defaults | listed in the last section |
```

```
-## Departures from the GBi defaults
+## Departures from the house defaults
```

```
-## Departures from GBi defaults
+## Departures from the house defaults
```

- [x] **Step 6: Run it and watch it pass**

Run: `tests/no-internal-leaks.sh`
Expected: PASS, `OK    no project-specific identifiers`.

Run: `tests/validate-skills.sh`
Expected: PASS, 24 skills validated. This is the check that matters after step 5: the four body
edits must not push any body over 700 words, and the `gbi-defaults.md` link must still resolve.
If `debug` crosses 700, trim four words elsewhere in its body rather than reverting the condition,
and say which four.

Run: `tests/run-tests.sh`
Expected: `All test files passed`. About four and a half minutes.

**Executed 2026-08-17, with one sequencing deviation.** The scanner, the validator and the four body
word counts were run here as written. The **full suite was run once after step 7**, not between
steps 6 and 7: `docs/07-open-decisions.md` is tracked, `no-internal-leaks.sh` scans every tracked
file through `git ls-files`, and the session handoff records that editing a tracked file while the
suite runs is a trap. Running it between the two steps meant either a wasted four-and-a-half-minute
run or an edit racing the scanner. No check was skipped; one run covered both steps. Result: `All
test files passed`, all fourteen stages, and the lint stage ran rather than skipping, `OK shellcheck
clean`.

Measured here, since step 5 said to measure rather than assume: `debug` **693** words, seven under
the 700 target, so its four-word gain needed no trim. `coding-standards` 683, `setup-deployment`
683, `security-audit` 593.

- [x] **Step 7: Record it against decision 2**

`docs/07-open-decisions.md` is append-only: a decision reversed is more useful than one silently
rewritten. Append to the end of section 2, after the paragraph beginning **Added 2026-08-11, found
by a sweep:**

```markdown
**Enforced 2026-08-17, after the list had already drifted.** The five named files above were a good
intention with no check behind it, and by 0.8.0 eight more files under `skills/` named GBi,
including four `SKILL.md` bodies, which is the one thing this decision explicitly forbids. Neither
`tests/no-internal-leaks.sh` nor `tests/validate-skills.sh` looked for the name: the scanner's deny
list was built for client identifiers and GBi is not a client.

All eight are neutralised. The name now appears under `skills/` only in the five files above, and
`tests/no-internal-leaks.sh` fails when it appears anywhere else under `skills/` or `templates/`.
The wording changes were exchanges rather than deletions: `debug` now says "a service following the
observability standard" rather than "a GBi service", which states the condition the name was
carrying implicitly, and `standards-template.md` says "the house defaults", which is what a
generated document in a non-GBi repository should have said all along.

Two things the enforcement deliberately does not cover, so nobody assumes it does. The rule matches
`\bGBi` and not `gbi-solutions`, because `templates/profile.schema.json` and
`templates/keel-profile.example.json` carry `gbi-solutions-ltd` inside the canonical schema URL,
where it is correct. And it is scoped to `skills/` and `templates/`: `docs/`, `README.md`,
`CHANGELOG.md` and the audits name GBi and real client repositories freely, and the audits are the
highest-risk documents in the tree. Both facts, and the rest of what publishing actually requires,
are in `docs/runbooks/going-public.md`.
```

- [x] **Step 8: Commit**

```bash
git add tests/no-internal-leaks.sh tests/test-no-leaks.sh \
        skills/coding-standards/SKILL.md skills/setup-deployment/SKILL.md \
        skills/security-audit/SKILL.md skills/debug/SKILL.md \
        skills/coding-standards/references/standards-template.md \
        skills/coding-standards/references/resilience.md \
        skills/review-code/references/rubric.md \
        skills/write-prd/references/questionnaire.md \
        docs/07-open-decisions.md
git commit -m "fix(skills): keep GBi in the five files decision 2 named, and check it

Decision 2 confined GBi-specific content to named reference files so publishing
would be a deletion rather than an audit. Nothing enforced it, and eight more
files had picked up the name, four of them SKILL.md bodies the decision forbids
outright. The scanner never looked: its deny list is for client identifiers and
GBi is not a client.

The eight are exchanges, not deletions. debug now names the condition the word
GBi was carrying implicitly, and standards-template says house defaults, which
is what a generated document in a non-GBi repository always needed."
```

---

### Task 2: Document the model pins that shipped at 0.8.0

**Kind:** documentation. The behaviour exists and is already tested; nothing about it changes here.
**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `docs/ideas/model-routing.md`

**Interfaces:**
- Consumes: the rule enforced at `tests/validate-skills.sh:189-202`, and the pins in
  `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea` and
  `execute-plan/references/subagent-prompts.md`.
- Produces: the CONTRIBUTING bullet task 4 appends below.

**Done when:** there is no verifying command. This task documents behaviour that
`tests/test-validate-skills.sh` already covers, and adds no new behaviour to test.
`tests/run-tests.sh` must still report `All test files passed`, which proves nothing was broken but
does not check the prose.

**Status, since the item asked for confirmation first.** Built, shipped and enforced. Four skills
name `sonnet` on their fan-out briefs; `execute-plan` keeps implementation and both reviews on
`inherit`; the validator rejects any alias Claude Code does not accept; `docs/standards.md:303-317`
records the rule and why `haiku` is not used yet. What was **not** built, deliberately: the
complexity router, session-level switching (unavailable to a plugin at all), routing to third-party
CLIs, and shipped `agents/` definitions. `docs/ideas/model-routing.md` holds the reasoning.

- [x] **Step 1: There is no test for this**

The behaviour is already covered by `tests/test-validate-skills.sh`'s model-alias case, added when
the pins shipped. A test asserting that README contains a sentence would be a test of prose, and the
one class of README claim worth checking mechanically is a number, which is task 3's job. This is
documentation of a shipped rule.

- [x] **Step 2: Add the README section**

In `README.md`, insert immediately before the `## Tests` heading:

```markdown
### Which model runs a delegated brief

Several skills fan work out to subagents. Those briefs name the model, so the wide mechanical
reading does not run on whatever the session happens to be pinned to:

| Brief | Model | Why |
|---|---|---|
| `repo-snapshot`, `port-assess`, `apex-port-plan`, `shape-idea` fan-outs | `sonnet` | Wide mechanical reading over many files, with a cited `path:line` for every claim, so the output is checkable |
| `execute-plan` implementation and both reviews | `inherit` | These write code under the TDD gate or judge another agent's verdict. A cheaper model gets less benefit of the doubt, not more |

The dispatching skill announces the model in one line when it delegates.
`tests/validate-skills.sh` rejects any alias Claude Code does not accept, because a brief sent to a
model that does not exist is a brief sent to nothing and the failure is silent. No brief names a
full model id, which would pin harder and rot faster, and none names `haiku` yet: that waits on one
measured comparison rather than an assumption.

**A session's own model is not part of this and cannot be.** No hook event exposes model selection,
so nothing here can move a session from one model to another; that stays `/model`. There is no
complexity router either, and there will not be one: routing pays on work that is long and
mechanical, not on work that is simple, so a router keyed on guessed complexity is wrong in the
direction nobody notices. The reasoning is in
[`docs/ideas/model-routing.md`](docs/ideas/model-routing.md).
```

- [x] **Step 3: Add the validator rule to CONTRIBUTING**

In `CONTRIBUTING.md`, under **The rules the validator enforces**, append after the bullet beginning
`No client name, partner name`:

```markdown
- A model named on a brief is one of `sonnet`, `opus`, `haiku`, `fable` or `inherit`, written as
  `` model `<alias>` ``. A brief pointing at an alias that does not exist fails silently at dispatch
  time, which is the worst way for it to fail.
```

- [x] **Step 4: Close the idea record**

In `docs/ideas/model-routing.md`, change the Status row and append a closing section.

Status row:

```
-| Status | agreed, 2026-08-16, in its reduced form. The central mechanism asked for does not exist |
+| Status | built 2026-08-17 in its reduced form, and documented. The central mechanism asked for does not exist |
```

Then append at the end of the file, after **Not decided here**:

```markdown
## What shipped

Built as task 6 of `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, released
in 0.8.0, and documented in `README.md` and `docs/standards.md` on 2026-08-17. The three questions
this record left open are answered as follows.

**Which dispatches are mechanical.** The four fan-outs: `repo-snapshot`, `port-assess`,
`apex-port-plan` and `shape-idea`. Everything in `execute-plan` stays `inherit`, because it either
writes code under the TDD gate or judges another agent's verdict.

**Alias or full id.** Alias. A full id is reproducible and goes stale inside a pinned release, and
the validator's job is to catch the stale case, which it can only do against a known alias set.

**The measurement worth taking first.** Not taken, which is why no brief names `haiku`. The
`sonnet` pins are a shape judgement rather than a measured saving, and this record should not be
read as claiming otherwise: keel measures context, not spend, so nothing here has demonstrated a
cost reduction. That remains the honest gap.
```

- [x] **Step 5: Run the suite**

Run: `tests/run-tests.sh`
Expected: `All test files passed`. Nothing here changes behaviour, so a failure means a link broke
or a dash slipped in.

- [x] **Step 6: Commit**

```bash
git add README.md CONTRIBUTING.md docs/ideas/model-routing.md
git commit -m "docs(model-pins): document the pins that shipped, and what was not built

The rule lived only in docs/standards.md, which nobody installing the plugin
reads. README now carries the table and the two things that cannot be built:
a session's own model is not reachable from a plugin, and a complexity router
keys on the wrong variable.

The idea record's three open questions are answered, including the one that
stays open: no brief names haiku, because no comparison was ever measured."
```

---

### Task 3: Make the countable claims in README fail when they drift

**Kind:** `build`. Four numeric claims in `README.md` are wrong today and nothing would ever notice.
**Files:**
- Create: `tests/test-doc-claims.sh`
- Modify: `tests/run-tests.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: `tests/supply-chain-scan.sh --list-rules`, `ls skills`, `ls tests/evals/scenarios`,
  `grep -c '^## [0-9]' docs/07-open-decisions.md`. All read-only and investigative.
- Produces: `tests/test-doc-claims.sh`, added to `tests/run-tests.sh`'s list. Linted automatically
  because `verify.lint` globs `tests/*.sh`.

**Done when:** `tests/test-doc-claims.sh` passes all four cases and `tests/run-tests.sh` reports
`All test files passed` with the new file in its output.

**Why only numbers.** A test that asserts on README prose fails every time somebody rewords a
sentence, which teaches people to ignore the check. `CONTRIBUTING.md` already states the rule:
too strict is the unrecoverable failure. A count is different: it has one right answer, it is
derivable from the tree, and it is exactly the class of claim that goes stale silently. Task 4
handles the prose claims by reading them, because that is the honest way to handle prose.

- [x] **Step 1: Write the failing test**

Create `tests/test-doc-claims.sh`:

```bash
#!/usr/bin/env bash
# Countable claims in README.md must match the tree.
#
# Not prose. A test that asserts on wording fails whenever somebody improves a sentence, which
# teaches people to ignore checks, and CONTRIBUTING.md says the too-strict failure is the
# unrecoverable one. A count is different: one right answer, derivable from the tree, and the
# class of claim that goes stale in total silence.
#
# Every assertion here was wrong when this file was written. README said four eval scenarios when
# there were six, four structural scan rules when there were five, and "Nine decisions: 5 resolved,
# 4 open" when all eleven were resolved. Nothing had noticed for months.
#
# Usage: tests/test-doc-claims.sh   (from the repository root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# claim <name> <actual> <phrase containing exactly one [0-9]+>
# Matches the phrase in README.md, pulls the number out of what matched, and compares.
#
# Two numbers in one phrase would make the first one win silently, so each phrase below carries
# exactly one. And the phrase is matched with grep -o rather than captured with sed: a leading `.*`
# in an ERE is greedy, so `.*([0-9]+) skills built` captures `4` out of `24 skills built` and this
# whole file would have asserted the wrong thing while looking correct.
claim() {
    local name="$1" actual="$2" phrase="$3" matched claimed
    matched="$(grep -oE "$phrase" README.md | head -1)"
    if [ -z "$matched" ]; then
        bad "$name" "no claim in README.md matched /$phrase/. A number a check cannot read is the same problem as a wrong one: reword the sentence to carry a digit, or delete this case if the claim is gone"
        return 0
    fi
    claimed="$(printf '%s' "$matched" | grep -oE '[0-9]+' | head -1)"
    if [ "$claimed" = "$actual" ]; then
        ok "$name ($actual)"
    else
        bad "$name" "README says '$matched', the tree says $actual"
    fi
}

claim "skill count" \
      "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
      '[0-9]+ skills built'

claim "eval scenario count" \
      "$(find tests/evals/scenarios -name '*.md' | wc -l | tr -d ' ')" \
      '[0-9]+ scenarios'

claim "supply chain pattern rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -vc structural)" \
      '[0-9]+ pattern rules'

claim "supply chain structural rules" \
      "$(tests/supply-chain-scan.sh --list-rules | grep -c structural)" \
      'and [0-9]+ structural'

claim "open decision count" \
      "$(grep -cE '^## [0-9]+\.' docs/07-open-decisions.md)" \
      'of [0-9]+ resolved'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [x] **Step 2: Run it and watch it fail**

Run: `chmod +x tests/test-doc-claims.sh && tests/test-doc-claims.sh`
Expected: FAIL, three of five cases. `skill count` passes at 24 and `supply chain pattern rules`
passes at 19. `supply chain structural rules` reports README says 4 and the tree says 5.
`eval scenario count` and `open decision count` both report no match, because the current sentences
are "Four scenarios, all passing as of 2026-08-11" and "Nine decisions: 5 resolved, 4 open": one
spells the number as a word and the other has no `of N` in it.

One of those is the honest RED for a mismatch and two are the RED for a claim written in a shape the
check cannot read. **A number a check cannot read is the same problem as a number that is wrong**, so
step 3 rewords both rather than only renumbering the third. The alternative, teaching the pattern to
read English number words, is a regex that grows every time somebody writes "a dozen".

- [x] **Step 3: Correct the four claims**

`README.md`, in the Tests section:

```
-19 pattern rules and 4 structural ones cover pipe-to-shell, decode-and-execute, credential reads,
+19 pattern rules and 5 structural ones cover pipe-to-shell, decode-and-execute, credential reads,
```

```
-Four scenarios, all passing as of 2026-08-11. Results and the arguments they produced are in
-[`tests/evals/results.md`](tests/evals/results.md).
+6 scenarios exist. Five pass and discriminate, last re-run 2026-08-16 after both pilots. The sixth,
+`done-without-verifying`, passes in both arms, which means it measures nothing about the skill and
+is recorded as an invalid scenario rather than a passing one. Results and the arguments they
+produced are in [`tests/evals/results.md`](tests/evals/results.md).
```

`README.md`, in the How to read this repo table:

```
-| [`docs/07-open-decisions.md`](docs/07-open-decisions.md) | Nine decisions: 5 resolved, 4 open |
+| [`docs/07-open-decisions.md`](docs/07-open-decisions.md) | Every call taken and why, decisions: 11 of 11 resolved, two with a named part still open |
```

- [x] **Step 4: Run it and watch it pass**

Run: `tests/test-doc-claims.sh`
Expected: PASS, `5 passed, 0 failed`.

- [x] **Step 5: Add it to the suite**

In `tests/run-tests.sh`, after the `run tests/test-cache-install.sh` line:

```bash
run tests/test-doc-claims.sh
```

Run: `tests/run-tests.sh`
Expected: `All test files passed`, with `== tests/test-doc-claims.sh` in the output.

- [x] **Step 6: Commit**

```bash
git add tests/test-doc-claims.sh tests/run-tests.sh README.md
git commit -m "test(docs): fail when a countable README claim drifts

Four numbers in README were wrong and nothing would ever have noticed: four
eval scenarios where there are six, four structural scan rules where there are
five, and nine decisions described as 5 resolved and 4 open when all eleven had
been resolved for months.

Scoped to counts on purpose. A test that asserts on wording goes red whenever
somebody improves a sentence, and CONTRIBUTING already says the too-strict
failure is the one you do not recover from."
```

---

### Task 4: Correct the root document claims no test can hold

**Kind:** `fix`. Each claim below is false today, verified against the tree.
**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `SOURCES.md`
- Modify: `CHANGELOG.md`
- Modify: `IMPLEMENTATION-PLAN.md`

**Interfaces:**
- Consumes: the CONTRIBUTING validator bullet added by task 2. Append below it, do not replace it.
- Produces: nothing code reads.

**Done when:** there is no verifying command for prose. `tests/run-tests.sh` reports
`All test files passed`, and `tests/test-doc-claims.sh` still passes, which together prove nothing
broke. Each correction is checked by the reviewer against the evidence column in the findings table
at the top of this plan.

- [x] **Step 1: There is no test for this**

Every remaining claim is a sentence, not a number. Task 3 explains why prose assertions are not
worth their false positives. The check here is a reviewer reading each replacement against the
finding it corrects, which is the same standard `CONTRIBUTING.md` sets for "every rule states its
reason": a judgement, checked by a person, deliberately not automated.

- [x] **Step 2: README, the three prose claims**

The suite is not seconds. It was 351.7s before the 2026-08-17 perf work and is 270.0s after, and
`tests/run-tests.sh:2` already says so:

```
-Plain bash, no dependencies, seconds. `tests/validate-skills.sh` enforces the frontmatter shape,
+Plain bash, no dependencies, about four and a half minutes: 270.0s measured 2026-08-17, down from
+351.7s. Run it in the background and read the last line. `tests/validate-skills.sh` enforces the frontmatter shape,
```

`doctor` and the suite are different numbers and the perf work moved only one of them:

```
-`doctor` runs the whole suite and takes around ten minutes, silent for most of them. It is slow,
-not hung.
+`doctor` runs the whole suite plus its own checks and takes around eleven minutes, silent for most
+of them. It is slow, not hung. The 2026-08-17 perf work made the suite 81 seconds faster and left
+`doctor` where it was, because its time goes on running each verify command rather than on reading
+the profile.
```

`keel guard install` writes two hooks, not one:

```
-keel guard install    # pre-push hook, repo-local, opt-in
+keel guard install    # pre-push and pre-commit hooks, repo-local, opt-in
```

and immediately after the paragraph beginning `The hook refuses a push the scan flags`, add:

```markdown
It writes a `pre-commit` hook in the same place, which does nothing until `gates.commit_guard` is
set to `required` or `warn` in the profile. When on it runs `verify.format`, `verify.lint` and
`verify.typecheck` against the commit and refuses rather than reformatting, because a hook that
rewrites files and re-stages them puts content into a commit its author never read.
```

- [x] **Step 3: CONTRIBUTING, the runtime and the two rule lists**

```
-Free, no dependencies, seconds. It runs the skill validator, the CLI suite, the leak scanner, and
+Free, no dependencies, about four and a half minutes. Run it in the background and read the last
+line. It runs the skill validator, the CLI suite, the leak scanner, the documented-claims check, and
 the same lint CI runs. If it is red before you start, fix that first or you will not know what you
 broke.
```

The body budget understates ADR-0001, which allows more than 700 and prices it:

```
-- Body within 700 words. Target 400 for one linear path, 600 when it fans out to subagents or carries
-  modes.
+- Body within 700 words, which is the target rather than the ceiling: ADR-0001 allows up to 900, and
+  anything over 700 requires a passing eval arm at that length recorded in `tests/evals/results.md`.
+  No body has ever bought that, so in practice 700 is the limit. Aim at 400 for one linear path, 600
+  when it fans out to subagents or carries modes.
```

Then append four bullets after the model-alias bullet task 2 added:

```markdown
- The `description` frontmatter of every skill, summed, stays under 1,320 tokens. That sum is in the
  prefix of every request in every keel project, and 1,320 is 30 skills at the measured mean, which
  is the count decision 6 says to revisit before rather than after.
- `skills/repo-snapshot`'s section 10 requires a `security-audit --full` item, a `coding-standards`
  item, and a line saying what the snapshot did not check. A snapshot that omits all three reads as a
  clean bill of health, which is the one thing it must never accidentally be.
- `templates/profile.schema.json` cannot change shape without `SCHEMA_VERSION` moving, because
  `doctor` compares the version and not the fields, so a silent schema change is one it stays quiet
  about.
- GBi is named under `skills/` only in the five reference files decision 2 declares, and never in a
  `SKILL.md`. `tests/no-internal-leaks.sh` enforces it, so publishing stays a deletion rather than an
  audit.
```

- [x] **Step 4: SOURCES, the uncredited skill and the untrue claim**

`skills/ship` appears nowhere in `SOURCES.md`, in a file whose own Our own work section says
originals are listed by name "rather than left to everything not above". Add a row to that table,
after the `skills/context-budget` row:

```markdown
| `skills/ship` | The gate list, the PR body assembled from the plan and the diff, and the override-recording rule are ours. `superpowers` has no equivalent skill and `cursor-starter` no equivalent prompt |
```

The trailer claim is false for all five close adaptations. Correct the claim rather than adding
trailers, because the MIT obligation is already discharged by this file plus
`THIRD-PARTY-LICENSES.md`, and a trailer would cost words from a body that has none to spare:

```
-Where a skill is a close adaptation, its `SKILL.md` also names the source in a trailer.
+Attribution lives here and in `THIRD-PARTY-LICENSES.md`, which is what discharges the MIT notice
+requirement. It is **not** repeated in each `SKILL.md`: this file claimed a source trailer in every
+close adaptation until 2026-08-17, and there has never been one in any of the five. The reference
+files adapted directly from an upstream document do name it in their first line, which is where the
+borrowing is most concrete.
```

- [x] **Step 5: CHANGELOG and IMPLEMENTATION-PLAN, one line each**

`CHANGELOG.md` names a project that does not exist:

```
-Notable changes to gbaiutils. Versions follow [semantic versioning](https://semver.org).
+Notable changes to keel. Versions follow [semantic versioning](https://semver.org).
```

The 1.0.0 gate requires something decision 2 established is not required, in the direction that
costs people time:

```
-- [ ] `/plugin marketplace add` and `/plugin install` verified from a second machine, against the
-      private repo, using only `gh` auth.
+- [ ] `/plugin marketplace add` and `/plugin install` verified from a second machine, against the
+      private repo. **Corrected 2026-08-17:** not "using only `gh` auth". Decision 2 records that
+      the marketplace is cloned over HTTPS through the ordinary git credential helper, verified on a
+      machine with no `gh` at all, and that the original wording sent people to install a tool they
+      did not need. What this gate wants is a second machine, not a particular credential.
```

- [x] **Step 6: Run the suite**

Run: `tests/run-tests.sh`
Expected: `All test files passed`, including `tests/test-doc-claims.sh`.

- [x] **Step 7: Commit**

```bash
git add README.md CONTRIBUTING.md SOURCES.md CHANGELOG.md IMPLEMENTATION-PLAN.md
git commit -m "docs: correct the root documents against the tree

Seven claims that were false. The suite is four and a half minutes, not
seconds, and doctor is eleven and did not get faster. guard install writes two
hooks. CONTRIBUTING said a 700-word ceiling where ADR-0001 says 700 target and
900 priced. SOURCES credited every skill but ship, and asserted a source
trailer in five SKILL.md files that has never existed in any of them. CHANGELOG
called the project gbaiutils. The 1.0.0 gate still demanded gh auth that
decision 2 had already established is not required.

Each is corrected in place rather than restated, except the two the decision
files own, which are appended to."
```

---

### Task 5: Write the runbook for making the repository public

**Kind:** `build`. `docs/runbooks/` is empty and nothing anywhere states what publishing requires.
**Files:**
- Create: `docs/runbooks/going-public.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: decision 2 in `docs/07-open-decisions.md`, including the note task 1 appended, and the
  `NOTE, BEFORE THIS REPOSITORY IS EVER MADE PUBLIC` header in `tests/no-internal-leaks.sh`.
- Produces: `docs/runbooks/going-public.md`, linked from README's repo map.

**Done when:** `tests/run-tests.sh` reports `All test files passed`. Nothing in this task changes
visibility, moves the deny list, deletes a file, or touches history.

**Corrected during execution, 2026-08-17.** This line originally added "and
`tests/validate-skills.sh` passes, which proves the new document's relative links resolve." **That is
false and it is the exact class of error this plan exists to fix.** `tests/validate-skills.sh:172`
iterates `find skills templates output-styles`, so nothing in the repository checks links, em
dashes, or docs-root notation in anything under `docs/`: not this runbook, not an ADR, not an idea
record, not this plan.

What actually verifies a new file under `docs/` is `tests/no-internal-leaks.sh` and
`tests/supply-chain-scan.sh`, both of which read every tracked and untracked file, so a leaked client
identifier or a developer path in it **is** caught. Its links and its dashes are a manual check, and
step 4 does them by hand rather than claiming a command did.

**Scope, stated because the title invites more.** This is the document that would be followed. It is
not the execution. Two of its steps are decisions rather than actions and say so.

- [x] **Step 1: There is no test for this**

A runbook is a set of instructions for a human doing something once. **Corrected during execution:**
this step originally said its links are checked by `tests/validate-skills.sh`. They are not. Nothing
validates a file under `docs/`, so the links and the dashes are checked by hand in step 4 and the
scanners cover the only thing a command can catch here, which is a leaked identifier.

- [x] **Step 2: Write the runbook**

Create `docs/runbooks/going-public.md`:

```markdown
# Runbook: making this repository public

Nothing here has been executed. It is the ordered list of what publishing actually requires,
written while the repository is private so the work is known rather than discovered.

**Two steps are decisions, not actions.** Step 1 and step 5 need an answer from an owner before
anybody runs a command. The rest are mechanical once those two are settled.

**Read this first, because it changes the order.** Publishing is not reversible in the way people
assume. Making a repository private again does not recall clones or forks, and a fork network keeps
objects reachable after the parent is locked down. Everything below assumes one attempt.

## 1. Decide the licence. DECISION

`LICENSE` is currently proprietary and all rights reserved: internal use by GBi Solutions Ltd and
its authorised personnel only. A public repository under that notice is published source that
nobody may use, which is usually not what "make it public" means.

MIT is the honest fit, because four of the projects keel adapts are MIT and roughly a third of the
skill set derives from them. Relicensing keel does not relicense their portions: those keep their
own notices in `THIRD-PARTY-LICENSES.md`, and `SOURCES.md` records which part came from where.

Do not skip this by publishing under the current notice and deciding later. The licence at the
moment of the first clone is the one that clone carries.

## 2. Move the deny list outside the tree

`tests/no-internal-leaks.sh` is the file that enumerates our clients, because it must contain their
names in order to search for them. The guard against disclosure is the disclosure. Its own header
says this and so does decision 2.

What to do, per that decision:

- Move the `DENY` array into a file outside the public tree. A sibling private repository, or a path
  read from an environment variable, both work. A private submodule does not: a submodule URL is
  public even when its contents are not, and the URL alone is a pointer at the list.
- Have the script read it, and **fall back to the generic patterns when it is absent**: developer
  home paths and document identifiers, which disclose nothing. A CI runner on a fork has no list and
  is a legitimate state, exactly as an unregistered marketplace is.
- Print which mode it ran in, on every run. A scanner that silently degrades to half its rules and
  still prints `OK` is worse than one that fails.
- Fix the coverage assertion in `tests/test-no-leaks.sh` in the same change. It compares every
  declared pattern against the ones that fired, so with an absent list it must assert coverage of
  the loaded patterns only, not of a list it cannot see.

## 3. Deal with the five GBi reference files

Decision 2 confined GBi-specific content to five files so that publishing would be a deletion. Since
2026-08-17 that is enforced by `tests/no-internal-leaks.sh`, so the list is trustworthy:

- `skills/coding-standards/references/gbi-defaults.md`
- `skills/coding-standards/references/observability.md`
- `skills/coding-standards/references/authorisation.md`
- `skills/security-audit/references/payments-checklist.md`
- `skills/setup-deployment/references/pipeline-patterns.md`

**Do not simply delete them.** `tests/validate-skills.sh` fails when a relative link does not
resolve, and `skills/coding-standards/SKILL.md` links to `gbi-defaults.md`. A deletion turns a
documented file into a broken link and the build goes red.

Per file:

| File | What it actually contains | Do |
|---|---|---|
| `gbi-defaults.md` | House conventions, most of which any team would adopt | Rename to `house-defaults.md`, remove the two GBi sentences, update the link in `skills/coding-standards/SKILL.md` |
| `observability.md` | Generic, plus SigNoz named as the default backend | Keep. Replace the named default with "whatever `profile.observability.backend` says" |
| `authorisation.md` | Separation-of-duties rules written for a payments business | Keep. The rules are good for anyone handling money; only the framing sentence names us |
| `payments-checklist.md` | Domain checklist. Read it line by line | Keep, after a read for any trap traceable to one client's incident |
| `pipeline-patterns.md` | Shapes that work, and traps found in real repositories | Keep, after the same read. "Found in a real repository" is fine; a recognisable one is not |

## 4. Update the repository name and its URLs

`gbi-solutions-ltd/keel` is load-bearing in five places, and two of them break silently:

- `README.md` install instructions and the private-repo paragraph
- `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`
- `tests/test-keel.sh`, which asserts the marketplace source lands in `settings.json`
- `templates/profile.schema.json`, as the schema's canonical `$id`
- `templates/keel-profile.example.json`, as its `$schema`

The last two are raw `githubusercontent.com` URLs. If the repository is renamed or moved, they
become 404s in every project that already has a profile, and nothing in `doctor` checks a schema URL
resolves. Decide whether the repository keeps its path before publishing, not after.

The README paragraph saying "the repository is private and this works anyway" also stops being true
and should go, along with the credential-helper explanation it exists to give.

## 5. Decide what happens to the documents that name real work. DECISION

This is the largest exposure and it is not covered by step 3's list, because those five files are
about conventions and these are about clients.

| Where | What is in it |
|---|---|
| `docs/audits/` | Five audits of real services, naming the repository, its defects and its security posture |
| `IMPLEMENTATION-PLAN.md` | Pilot repositories named outright, plus both reviewers |
| `docs/07-open-decisions.md` | The org, the reviewers, the client engagement that produced three skills |
| `docs/plans/`, `docs/ideas/`, `CHANGELOG.md` | Real repositories and real incidents, used as the reason a rule exists |

Three options, and the choice is an owner's:

1. **Publish a subset.** Ship the plugin (`skills/`, `bin/`, `lib/`, `hooks/`, `templates/`, `tests/`,
   `README.md`) and leave `docs/` and `IMPLEMENTATION-PLAN.md` behind. Cleanest, and it loses the
   thing that makes the repository worth reading: every rule states the failure that produced it.
2. **Redact in place.** Keep the documents, replace each named repository with a generic one. Slow,
   and a redaction that leaves the incident intact often still identifies the client.
3. **Publish as is.** Only if an owner has read all five audits and accepts it. They are the most
   detailed public statement about a client's security posture that we could make.

## 6. Scan the history, not the working tree

The working tree being clean says nothing. Git keeps everything, and a name removed in a later
commit is public the moment the repository is.

```bash
# Every deny pattern against every commit, not just HEAD.
for pat in $(tests/no-internal-leaks.sh --list-patterns); do
    git rev-list --all | while read -r sha; do
        git grep -I -nE "$pat" "$sha" 2>/dev/null
    done
done | sort -u | head -50
```

Expect hits. Every client identifier this repository ever removed is still in its history, and
several were removed by the sweeps decision 2 records.

If there are hits, publishing the existing history is not an option, and there are two ways out:

- **Rewrite** with `git filter-repo`. Keeps the history, invalidates every existing clone and every
  commit sha referenced in any document, including the `f135e23` and `a1b2c3d` style references
  scattered through `docs/` and `CHANGELOG.md`.
- **Start fresh.** A new repository with one squashed initial commit. Loses the history, which for a
  tool whose main asset is "this rule exists because of that failure" costs more than it looks like.

Whichever is chosen, `tests/supply-chain-scan.sh`'s `structural-secret-material` rule states the
same principle for credentials and it applies here: the remedy for something git has kept is not
deleting the file.

## 7. Re-run the whole gate, then flip

```bash
tests/run-tests.sh                    # all test files pass
tests/supply-chain-scan.sh            # clean, with every honoured suppression printed
tests/no-internal-leaks.sh            # clean, and printing that it ran in fallback mode
```

Then change visibility.

## 8. What changes the moment it is public

- **Actions run on pull requests from forks.** Read every workflow trigger and every secret it uses
  before publishing, not after. A `pull_request` trigger with access to a secret is a credential
  handed to anyone who opens a PR.
- **`keel doctor`'s marketplace check** is unaffected: it asks whether a marketplace is registered on
  this machine, not whether it is reachable.
- **Issues arrive from strangers.** Decision 9 assigns review to two named people and says either may
  review but never the author. That holds for external contributions too, and it means a contributor
  cannot merge their own skill change. Say so in `CONTRIBUTING.md` before the first PR arrives, not
  in reply to it.
```

- [x] **Step 3: Link it from the README repo map**

In `README.md`, in the How to read this repo table, after the `docs/standards.md` row:

```markdown
| [`docs/runbooks/going-public.md`](docs/runbooks/going-public.md) | What publishing this repository would require. Two of its steps are decisions, and none of it has been executed |
```

- [x] **Step 4: Verify, and do by hand what no command does**

Nothing validates `docs/`, so these three are manual and each names its own command. They are
investigative, not `profile.verify` entries:

```bash
LC_ALL=C grep -c $'\xe2\x80\x94\|\xe2\x80\x93' docs/runbooks/going-public.md   # em and en dashes: must be 0
grep -o '](\([^)]*\))' docs/runbooks/going-public.md | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)'
```

The second prints every relative link in the file; check each resolves from `docs/runbooks/`. Then
the two scanners, which are the only automatic cover a `docs/` file gets:

Run: `tests/no-internal-leaks.sh` and `tests/supply-chain-scan.sh`
Expected: both clean. The runbook names client-facing documents and the deny list, so this is not a
formality.

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 5: Commit**

```bash
git add docs/runbooks/going-public.md README.md
git commit -m "docs(runbook): what making this repository public would require

Nothing flips. This is the ordered list, written while the repository is
private so the work is known rather than discovered.

Two steps are decisions an owner has to take: the licence, because publishing
under the current all-rights-reserved notice is source nobody may use, and what
happens to docs/audits, which is five real services' security posture and the
largest exposure in the tree. It is not on decision 2's extraction list, because
that list is about conventions and these documents are about clients.

The history is the step people skip. Every identifier this repository ever
removed is still in it."
```

---

### Task 6: Record the tool-recommendation idea before building it

**Kind:** `build`. The record is the artifact; every other idea Bernard raised has one.
**Files:**
- Create: `docs/ideas/snapshot-recommends-tools.md`

**Interfaces:**
- Consumes: `docs/ideas/snapshot-surfaces-remediation-gaps.md`, whose open question 3 and section-10
  handoff this extends.
- Produces: the recommendation task 7 implements.

**Done when:** `tests/run-tests.sh` reports `All test files passed`. The record is complete when its
Recommendation and its Status agree and its assumptions table marks each assumption checked or not,
which is a judgement a reviewer makes and no command can.

**Corrected during execution, 2026-08-17**, for the reason given in task 5: this line claimed
`tests/validate-skills.sh` proves the document's links resolve, and it does not look at `docs/` at
all. Links and dashes are checked by hand in step 3.

**Why this comes before task 7 and not after.** Every other idea in `docs/ideas/` was written before
its build, and two of them came back smaller than they were asked for as a result. Writing the
record after the code makes it a changelog entry.

- [x] **Step 1: There is no test for this**

An idea record is prose whose value is the reasoning. **Corrected during execution:** nothing checks
a file under `docs/`, so its links and dashes are a manual check in step 3, not a command's job.

- [x] **Step 2: Write the record**

Create `docs/ideas/snapshot-recommends-tools.md`:

```markdown
# Idea: a gap the snapshot finds should name the tool that fills it

| | |
|---|---|
| Raised by | Bernard, 2026-08-17 |
| Status | agreed, 2026-08-17, in the form below |
| Recommendation | One shared reference of tool choices under `skills/keel/references/`, cited by the snapshot's section 10. Not a new skill, not a change to the snapshot body, not a CLI feature |
| Next | `docs/plans/2026-08-17-release-readiness.md`, task 7 |

## The problem

A snapshot ends with a recommendation naming the skill that does the work: "no tests on the
settlement path. Fix: `tdd`." The reader now knows to write tests and still has to choose a test
runner, which for a TypeScript repository means reading three comparisons of Vitest against Jest
before writing a line. Multiply that by the six or seven gaps a first snapshot typically finds and
the document has produced a research project rather than a next step.

**Evidence.** Bernard's framing: "this may help reduce the decision fatigue across many tools needed
for gap remediation." No instance of a specific snapshot stalling on a tool choice was named, so
this is a purpose statement about what a recommendation is for rather than a report of a failure.
Recorded, because it is why the recommendation below is a reference file and not a skill.

## What was asked for

> Would be nice that if the snapshot finds gaps in existing repos, it would recommend appropriate
> tools based on the repo structure/stack e.g. tests (for example choose Vitest over Jest) with
> brief reasons for the choice. This may help reduce the decision fatigue across many tools needed
> for gap remediation.

## The case against

**Strongest argument for not building this at all: a tool opinion goes stale and a skill cannot
tell.** Vitest over Jest is right in 2026 and was not in 2022. A rule about process ages in years;
a rule about which npm package to install ages in months, and the failure mode is a confident
recommendation for a tool the ecosystem has moved past. Nothing in keel has this property yet, and
`docs/ideas/model-routing.md` already recorded the same worry about pinning a model alias.

The second argument is that the snapshot has no room. Its body is 699 words against ADR-0001's 700
after the 2026-08-17 handoff change, so anything in the body must displace something.

Both are answerable. The staleness is answerable by writing each row with its **reason** rather than
its verdict: "one config shared with the bundler already present, native ESM and TS with no
transform layer" stays checkable when the names change, and a reader can see it stop being true. The
word budget is answerable by putting all of it in references, which are unbudgeted, and adding
nothing to the body at all.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The gap is real and small. A recommendation naming a skill but not a tool is half a next step |
| Do it inline, per snapshot | Nothing. The agent picks a tool each time it writes a section 10 | Available today and it is what happens now. The problem is that it is unreviewed: a tool opinion nobody wrote down is one nobody can correct, and two snapshots of sibling repositories will disagree |
| Buy it | Nothing available | No product recommends a test runner from a repository's shape and explains itself |
| Build it as a skill | Days, a 25th skill, and 44 tokens on every request in every project | Rejected. It is a lookup table, not a process. Decision 6 caps the description sum precisely to stop this |
| Build the reference | An hour or two, one file plus a validator rule | Recommended |

**Variants of building the reference**

| Variant | Note |
|---|---|
| One shared file under `skills/keel/references/`, cited by the snapshot | Recommended. Six skills already cite `asking-questions.md` from there, so the pattern and the link depth exist |
| Inside `skills/repo-snapshot/references/` | Smaller, and it puts a cross-cutting table inside one skill. `setup-deployment`, `coding-standards` and `tdd` all pick tools too, and they would drift from it |
| Emitted by `keel doctor` | Rejected. Doctor is a check, and it would duplicate `lib/detect-stack.sh`'s language knowledge into a second place while being unable to explain a trade-off, which is the whole value |
| A pick and a runner-up per row | Taken. One pick is an instruction and a list of five is the decision fatigue this is meant to remove. A named runner-up says when the pick is wrong |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A reader of a snapshot does not already know their ecosystem's default runner | The gap is real in practice | No instance was named either way | **No** |
| A tool table stays correct long enough to be worth writing | Rows carry reasons rather than verdicts | Only by re-reading it in a year | **No, and it is the main risk.** Mitigated by a review trigger rather than by hope |
| The languages worth covering are the ones keel detects | Detection is the same list a snapshot would face | `lib/detect-stack.sh`'s `lang_profile` enumerates thirteen | Yes |
| Three new tools is the most a reader will adopt from one document | Section 10 already caps at seven items and says name two or three in the handoff | Consistent with the existing cap, which was set for the same reason | Partly |

## What the system says

| Finding | Evidence | What it means |
|---|---|---|
| Section 10 already names a skill per item | `skills/repo-snapshot/references/section-templates.md:184-207` | The slot exists. This adds a tool and a reason to a shape already there |
| Two referrals are already required on a first look | Same file, after the 2026-08-17 handoff change | Precedent for section 10 carrying a requirement, and for the validator checking it inside section 10 only |
| The snapshot body is at 699 of 700 words | ADR-0001, and the handoff change that spent the last word | Nothing may go in the body. All of it is references |
| Shared references live in `skills/keel/references/` | `asking-questions.md`, cited by six skills | The location is settled, not a new convention |
| The CLI already knows the stack | `lib/detect-stack.sh`, and `profile.stack.language` in every profile | The table can be keyed on a value the reader already has, so no detection logic is duplicated |
| A validator rule can be keyed to detection | `lang_profile`'s case labels enumerate every language | A language added to detection with no row in the table becomes a failing build, which is the only thing that will keep the table honest |
| Section 9 forbids an overall score | Same templates file | A tool recommendation is not a maturity score and must not become one |

## Open questions

1. **What triggers a re-read of the table?** A stale tool opinion is the main risk and nothing in
   keel expires. Decision 9's monthly release is the obvious hook; nothing enforces it, and this
   record should not pretend otherwise.
2. **Should the other tool-picking skills cite the same file?** `setup-deployment`, `coding-standards`
   and `tdd` all choose tools implicitly. Citing one table would stop them drifting apart, and it is
   three more edits than this change needs. Deliberately left out of task 7.
3. **Does a repository that already has a working tool ever get a recommendation?** No, and the
   reference says so. The most common failure here would be recommending Vitest to a repository with
   2,000 passing Jest tests, which is not a gap.

## Recommendation

**Build the reference.** One file, `skills/keel/references/tool-choices.md`, keyed on the languages
`lib/detect-stack.sh` detects, one pick and one runner-up and one reason per gap type. Cite it from
section 10 of the snapshot's templates, where the recommendation is already written, and add a
validator rule that fails when a detected language has no row.

Why: the capability is not missing, the written-down opinion is. This gets a reader from "you have
no tests" to "install Vitest, here is why" without a new skill, without a token on the always-loaded
prefix, and without touching a body that has one word left.

## Not decided here

Whether the other tool-picking skills cite the table, what makes anyone re-read it, and whether a
gap-remediation baseline that diffs two snapshots deserves its own skill. That last one is open
question 2 of `snapshot-surfaces-remediation-gaps.md` and is still the most interesting unbuilt
thing in this area.
```

- [x] **Step 3: Verify, and do by hand what no command does**

```bash
LC_ALL=C grep -c $'\xe2\x80\x94\|\xe2\x80\x93' docs/ideas/snapshot-recommends-tools.md   # must be 0
grep -o '](\([^)]*\))' docs/ideas/snapshot-recommends-tools.md | sed 's/](\(.*\))/\1/' | grep -Ev '^(https?:|#)'
```

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 4: Commit**

```bash
git add docs/ideas/snapshot-recommends-tools.md
git commit -m "docs(idea): record the tool-recommendation idea before building it

Agreed in its reduced form: a shared reference of tool choices, cited by the
snapshot's section 10. Not a 25th skill, because a lookup table is not a
process and the description sum is capped precisely to stop that.

The record exists mainly for the argument against, which is real: a process
rule ages in years and a rule about which package to install ages in months.
The mitigation is writing each row's reason rather than its verdict, so a
reader can see it stop being true. Nothing in keel expires, and this record
says so rather than implying a review that nobody scheduled."
```

---

### Task 7: Name the tool, and the reason, next to the gap

**Kind:** `build`.
**Files:**
- Create: `skills/keel/references/tool-choices.md`
- Modify: `skills/repo-snapshot/references/section-templates.md`
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: `lang_profile`'s case labels in `lib/detect-stack.sh`, read by the new validator rule as
  the list of languages that must have a row.
- Produces: `skills/keel/references/tool-choices.md`, cited from section 10 as
  `../../keel/references/tool-choices.md`.
- **No skill body changes.** `repo-snapshot`'s body stays at 699 words.

**Done when:** `tests/test-validate-skills.sh` passes with its two new cases,
`tests/validate-skills.sh` passes with 24 skills validated, and `tests/run-tests.sh` reports
`All test files passed`.

- [x] **Step 1: Write the failing test**

Add two cases to `tests/test-validate-skills.sh`, after the model-alias cases. The fixture root has
no `lib/` and no `skills/keel`, so each case builds the minimum the rule reads:

```bash
# A language keel detects with no row in the tool table is a gap the snapshot will improvise on,
# differently each time. The table is only trustworthy while it covers what detection produces.
tool_table_fixture() {
    local root="$1" langs="$2"
    mkdir -p "$root/lib" "$root/skills/keel/references" "$root/skills/repo-snapshot/references"
    printf 'detect_languages() {\n    local out=""\n%s    printf "%%s\\\\n" "$out"\n}\n' \
      "$langs" > "$root/lib/detect-stack.sh"
    printf '# Tool choices\n\n| Language | Pick |\n|---|---|\n| `typescript` | Vitest |\n' \
      > "$root/skills/keel/references/tool-choices.md"
    printf '## 10. Recommendations\n\nSee [../../keel/references/tool-choices.md](../../keel/references/tool-choices.md).\nsecurity-audit --full, coding-standards, did not check.\n\n## 11. Proposed profile\n' \
      > "$root/skills/repo-snapshot/references/section-templates.md"
}

m_tools_covered()  { tool_table_fixture "$1" '    out="$out typescript"
'; }
run "a tool table covering every detected language passes" 0 m_tools_covered

m_tools_missing()  { tool_table_fixture "$1" '    out="$out typescript"
    out="$out go"
'; }
run "a detected language missing from the tool table is rejected" 1 m_tools_missing
```

- [x] **Step 2: Run it and watch it fail**

Run: `tests/test-validate-skills.sh`
Expected: FAIL, one case. `a detected language missing from the tool table is rejected` reports
`expected exit 1, got 0`, because the validator has no such rule. The covered case passes for the
wrong reason, which is why both exist.

- [x] **Step 3: Add the rule**

In `tests/validate-skills.sh`, immediately after the block that checks `repo-snapshot`'s step 6 for
`did not check`, add:

```bash
# A gap the snapshot names without naming a tool leaves the reader a research project, and a tool
# the snapshot picks without a written-down reason is an opinion nobody can correct. The table is
# only worth citing while it covers what lib/detect-stack.sh actually produces: a language added to
# detection with no row is a gap the snapshot will improvise on, differently every time.
#
# The languages come from detect_languages' assignments, which is the function whose entire job is
# to produce the list. lang_profile's case labels were the obvious source and they are wrong: its
# typescript branch contains an inner `case "$f" in nest)` for framework detection, so the labels
# yield `nest` as a fourteenth language and this rule would demand a tool row for NestJS. Checked
# before the rule was written, which is the only reason it is not in it.
#
# Both files are guarded on existence, like the checks above, because
# tests/test-validate-skills.sh runs this validator from fixture roots that build only what a case
# needs.
tool_tbl=skills/keel/references/tool-choices.md
if [ -f "$tool_tbl" ] && [ -f lib/detect-stack.sh ]; then
    langs="$(awk '/^detect_languages\(\)/{f=1} f&&/^}/{f=0} f' lib/detect-stack.sh \
        | grep -oE 'out="\$out [a-z]+"' | sed -E 's/.* ([a-z]+)"/\1/' | sort -u)"
    for l in $langs; do
        grep -qE "^\| *\`?$l\`?[ |]" "$tool_tbl" \
          || report "$tool_tbl has no row for '$l', which lib/detect-stack.sh detects. A gap in a language the snapshot will meet is one it improvises a tool for."
    done

    section10="$(awk '/^## 10\./{f=1} f&&/^## 11\./{f=0} f' skills/repo-snapshot/references/section-templates.md 2>/dev/null)"
    printf '%s' "$section10" | grep -qF -- 'tool-choices.md' \
      || report "skills/repo-snapshot/references/section-templates.md section 10 does not cite tool-choices.md, so a gap gets a skill but no tool."
fi
```

- [x] **Step 4: Write the table**

Create `skills/keel/references/tool-choices.md`:

```markdown
# Tool choices

Read this when a document is about to say "there are no tests here" or "nothing formats this code",
and the reader will then have to choose a tool. Cited by `repo-snapshot` section 10; usable by any
skill recommending tooling.

**Each row carries its reason, not its verdict.** A pick without a reason is an opinion that cannot
be corrected and cannot be seen going stale. If a reason has stopped being true, the row is wrong
whatever the tool's current popularity, and changing it is a normal edit.

## The rules that matter more than the tables

1. **A working tool is not a gap.** A repository with 2,000 passing Jest tests has a test runner.
   Recommending Vitest there is a migration proposal, which is a different document and usually a
   bad idea. Read what is installed before reading these tables.
2. **One pick, one reason, one runner-up.** The runner-up says when the pick is wrong. A list of
   five is the decision fatigue this file exists to remove.
3. **At most three new tools per document.** Section 10 caps recommendations at seven items and asks
   for two or three in the handoff, for the same reason: a reader adopts none of a list of seven.
4. **Key on `profile.stack.language`**, which every keel project already has, rather than
   re-detecting. Where a repository is multi-stack, `stack.also` holds the rest and the primary
   language wins.
5. **Never recommend a second CI system, a second package manager, or a second test runner.** Those
   are the three where two of a thing is worse than one of either.
6. **Prefer what is already in the toolchain.** `go test`, `cargo test` and `dotnet format` add
   nothing to install, nothing to configure, and nothing to keep current.

## Test runner

| Language | Pick | Runner-up | Why the pick |
|---|---|---|---|
| `typescript` | Vitest | Jest | Reads the project's existing bundler config, runs TS and ESM with no transform layer to maintain, and its API is close enough to Jest's that knowledge transfers |
| `javascript` | Vitest | `node:test` | Same reason. `node:test` is the right answer when the project refuses every dependency, and it is now capable enough to mean it |
| `python` | pytest | `unittest` | Plain functions and fixtures, so a test costs less to write than a class; `unittest` where a dependency is genuinely refused, since it is stdlib |
| `go` | `go test` | none | In the toolchain. Adding a framework to Go tests is a step backwards, and table-driven tests are the idiom |
| `java` | JUnit 5 | TestNG | Both Maven and Gradle wire it up with no plugin, and it is what every current guide assumes |
| `kotlin` | JUnit 5 with kotlin-test | Kotest | Keeps one runner across a mixed JVM repository. Kotest earns itself on property-based testing, not on ordinary unit tests |
| `csharp` | xUnit | NUnit | The .NET template default, so `dotnet new` and every tutorial agree with the repository |
| `php` | PHPUnit | Pest | What Laravel and Symfony both ship against, so the framework's own test helpers work unmodified. Pest is a nicer syntax over the same engine, worth it on a new codebase |
| `ruby` | RSpec | Minitest | Where Rails generated Minitest, keep Minitest: it is installed, it is fast, and switching costs a rewrite for no behaviour change |
| `rust` | `cargo test` | none | In the toolchain, and doc tests come free |
| `swift` | swift-testing | XCTest | The current direction and much less ceremony per test. XCTest where the project still supports an older toolchain |
| `cpp` | Catch2 | GoogleTest | Header-only, so it adds a dependency and not a build system. GoogleTest where mocking is central |
| `lua` | busted | none | The only option with real adoption |

**Coverage:** use the runner's own first (`vitest --coverage`, `pytest --cov`, `go test -cover`,
JaCoCo on Gradle). A separate coverage tool is a second thing to configure for a number that is
already available.

## Lint and format

The profile splits these on purpose: `verify.lint` and `verify.format` must be **check-only**,
because the commit guard runs them and a hook that rewrites files puts content into a commit its
author never read. `verify.format_fix` is the writing one.

| Language | Pick | Runner-up | Why the pick |
|---|---|---|---|
| `typescript`, `javascript` | Biome | ESLint with Prettier | One tool, one config, lint and format together, and fast enough that nobody disables it. ESLint stays right where the project already depends on plugins Biome has no equivalent for |
| `python` | Ruff | flake8 with Black | Replaces both linter and formatter with one binary and one config section, and it is a drop-in for the rules teams actually had enabled |
| `go` | `gofmt` with `go vet` | golangci-lint | Both in the toolchain and both non-negotiable in the ecosystem. golangci-lint when the team wants more than correctness |
| `java`, `kotlin` | Spotless | Checkstyle, or ktlint for Kotlin | Runs in the existing Gradle or Maven build, and has both a check and an apply goal, which is exactly the split the profile needs |
| `csharp` | `dotnet format` with analyzers | StyleCop | In the SDK. Analyzer rules ship with the compiler and fail the build, which is stronger than a separate pass |
| `php` | PHP-CS-Fixer | PHP_CodeSniffer | Fixes as well as reports, and its rule sets track the PSR standards the frameworks assume |
| `ruby` | RuboCop | standard | The ecosystem default, and its `--only` mode makes adoption on a legacy codebase possible rather than theoretical |
| `rust` | `cargo fmt` with `cargo clippy` | none | In the toolchain, and clippy catches real bugs rather than only style |
| `swift` | swift-format | SwiftLint | Ships with the toolchain now. SwiftLint adds opinions beyond formatting |
| `cpp` | clang-format with clang-tidy | cpplint | The compiler vendor's own, so it understands the language rather than pattern-matching it |
| `lua` | Stylua with luacheck | none | Formatting and static analysis are separate here, and both are small |
| shell | shellcheck | none | Nothing else finds shell bugs. It is what this repository uses on itself |

## Typecheck

| Language | Pick | Why |
|---|---|---|
| `typescript` | `tsc --noEmit` | The compiler already in the project. A bundler that strips types is not a typecheck |
| `python` | mypy | The reference implementation and the one library stubs target. Pyright is faster and stricter by default, which is better on a new codebase and painful to adopt on an old one |
| `php` | PHPStan | Levels 0 to 9 make adoption incremental, which is the only way it happens on an existing codebase |
| `ruby` | none | Sorbet only where it is already in use. Adding gradual typing to an untyped Ruby codebase is a project, not a gap |
| `java`, `kotlin`, `csharp`, `go`, `rust`, `swift`, `cpp` | the build | Compiled. `verify.build` is the typecheck and `verify.typecheck` stays `null` rather than repeating it |
| `javascript`, `lua` | none | Say `null` in the profile. A typecheck a language cannot do is not a gap |

## Everything else

Mostly language-independent, and the first rule is the same in every row: use what the repository
and its host already have.

| Gap | Pick | Runner-up | Why the pick |
|---|---|---|---|
| CI | Whatever the host is: GitHub Actions on GitHub, GitLab CI on GitLab | none | A second CI system is the worst outcome available. Where the repository is already on a host, the choice is made |
| Container | Multi-stage Dockerfile, non-root user, a `HEALTHCHECK`, pinned base by digest | none | The three things whose absence is always a finding. A `HEALTHCHECK` is what lets a deploy fail loudly rather than serving a broken image |
| Dependency updates | The host's own: Dependabot on GitHub, Renovate anywhere | Renovate | Zero infrastructure and it already has repository access. Renovate when grouping and scheduling matter more than setup cost |
| Vulnerable dependencies | The ecosystem's own in CI: `npm audit`, `pip-audit`, `govulncheck`, `cargo audit`, `bundler-audit`, `dotnet list package --vulnerable` | Trivy or Grype | Each knows its own lockfile format exactly. One scanner across a polyglot repository when there are three or more languages |
| Secret scanning | gitleaks | trufflehog | One config drives both the CI job and a pre-commit hook, so it catches the secret before the commit that has to be rewritten. trufflehog verifies findings against live services, which is better triage and needs more trust |
| Container and IaC scanning | Trivy | Grype with Checkov | One tool over images, filesystems and IaC, so it is one job rather than three |
| Observability | The OpenTelemetry SDK for the language, exporting OTLP to whatever `profile.observability.backend` names | none | The instrumentation outlives the backend choice, which is the whole point of picking OTLP over a vendor SDK |
| Structured logging | The ecosystem's own: pino, structlog, slog, Logback with a JSON encoder, Serilog, Monolog | none | Never a bespoke wrapper. `coding-standards/references/observability.md` sets what a log line must carry; these are what carry it |
| Migrations | The framework's own, and never hand-rolled SQL in a deploy script | none | Every framework has one, it is already wired to the connection config, and its state table is the thing a hand-rolled script lacks |
| Pre-commit orchestration | The `pre-commit` framework, or `keel guard install` in a keel project | Husky with lint-staged on JS | Language-independent and it pins each hook's version. `lint-staged` is right where the only hooks are JS formatters |

**If a stack is not in these tables**, say so in the document and name what you would look for
instead: whether the ecosystem has one obvious default, whether it is in the toolchain already, and
whether the repository's neighbours in the same organisation have made a choice worth matching. Do
not guess a package name.
```

- [x] **Step 5: Cite it from section 10**

In `skills/repo-snapshot/references/section-templates.md`, section 10, replace the paragraph after
the heading:

```
-The only section with actions. Ordered by value over effort, not by severity. Each names the
-skill that does the work, so the reader's next step is one invocation.
+The only section with actions. Ordered by value over effort, not by severity. Each names the
+skill that does the work, so the reader's next step is one invocation.
+
+**Where the gap is a missing tool, name the tool and one reason**, from
+[../../keel/references/tool-choices.md](../../keel/references/tool-choices.md), keyed on
+`profile.stack.language`. "No tests here, fix: `tdd`" leaves the reader to choose a runner before
+they can start. Three new tools is the most one document may propose, and a repository with a
+working equivalent has no gap: 2,000 passing Jest tests is a test runner, and recommending Vitest
+there is a migration proposal rather than a finding.
```

Then in the worked example inside the same section, extend item 2 so the convention is visible where
it is read:

```
-2. **No tests on the settlement path.** `src/settlement/` has no test file, and it moves
-   money. Fix: `tdd`, retrofitting tests before the next change there. Effort: a day.
+2. **No tests on the settlement path.** `src/settlement/` has no test file, and it moves
+   money. Fix: `tdd`, retrofitting tests before the next change there. Tool: Vitest, which reads
+   the bundler config already here and needs no transform layer for TS. Effort: a day.
```

- [x] **Step 6: Run it and watch it pass**

Run: `tests/test-validate-skills.sh`
Expected: PASS, including both new cases.

Run: `tests/validate-skills.sh`
Expected: PASS, 24 skills validated. This proves every detected language has a row, section 10 cites
the table, the new file's links resolve, and `repo-snapshot`'s body is untouched and still under 700.

Run: `tests/run-tests.sh`
Expected: `All test files passed`.

- [x] **Step 7: Commit**

```bash
git add skills/keel/references/tool-choices.md \
        skills/repo-snapshot/references/section-templates.md \
        tests/validate-skills.sh tests/test-validate-skills.sh
git commit -m "feat(snapshot): name the tool next to the gap, with its reason

A recommendation saying 'no tests here, fix: tdd' hands the reader a research
project before they can start. Section 10 now names the tool too, from one
shared table keyed on the language the profile already records.

Every row carries its reason rather than its verdict, because a process rule
ages in years and a package recommendation ages in months, and a reason is the
only form a reader can watch stop being true.

The validator fails when a language lib/detect-stack.sh detects has no row,
which is the only thing that will keep the table honest as detection grows. No
skill body changed: repo-snapshot has one word of budget left and this needed
none of it."
```

---

### Task 8: Record the release, and settle the version

**Kind:** documentation, plus one decision that is the user's.
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `VERSION` (only if a bump is chosen)
- Modify: `.claude-plugin/plugin.json` (only if a bump is chosen)
- Modify: `.keel/profile.json` (only if a bump is chosen: `keel_version`)

**Interfaces:**
- Consumes: tasks 1 through 7.
- Produces: the released section every later change appends above.

**Done when:** `tests/run-tests.sh` reports `All test files passed` and, if a bump is chosen,
`bin/keel version` prints the new `VERSION`. `tests/test-doc-claims.sh` must still pass, since the
CHANGELOG entry restates counts this plan corrected.

- [x] **Step 1: Ask, do not assume**

Put the version to the user with `AskUserQuestion`, per
`skills/keel/references/asking-questions.md`. The recommendation, first and marked:

- **0.9.0**, folding in the unreleased perf paragraphs that deliberately did not number themselves.
  Skill bodies changed, a new shared reference shipped, two new checks landed, so this is more than
  a patch and nothing in it breaks a profile.
- **0.8.1**, if the position is that documentation and a reference file are not a feature.
- **Leave it unreleased**, adding to the existing Unreleased section and numbering later.

Do not proceed to step 2 until it is answered. Everything else in this plan is already committed, so
waiting costs nothing.

- [x] **Step 2: Write the CHANGELOG entry**

Follow the shape of the `## 0.8.0 - 2026-08-17` section: prose that says what changed and why, not a
bulleted diff. Cover, in this order, and merge the existing Unreleased paragraphs in if a version
was chosen:

- **The extraction list is enforced.** Decision 2 named five files and nothing checked; eight more
  had the name, four of them `SKILL.md` bodies the decision forbids. Say that the fix was exchanges
  rather than deletions, and that `debug` now states the condition the word GBi was carrying.
- **The model pins are documented.** They shipped in 0.8.0 and lived only in `docs/standards.md`.
  Say what cannot be built, so it is not re-proposed.
- **Seven false claims in the root documents.** Name them: the suite is four and a half minutes not
  seconds, doctor is eleven and did not get faster, `guard install` writes two hooks, the word budget
  is a target not a ceiling, `ship` was credited nowhere, the source trailer SOURCES promised has
  never existed, and the CHANGELOG called the project gbaiutils.
- **A test for the countable ones**, and why it is scoped to counts.
- **The going-public runbook**, and that nothing flipped.
- **Tool recommendations in section 10**, with the staleness risk stated rather than hidden.

- [x] **Step 3: Apply the bump, if one was chosen**

```bash
printf '0.9.0\n' > VERSION            # or the version chosen in step 1
```

Then set the same string in `.claude-plugin/plugin.json` and `keel_version` in `.keel/profile.json`.

Run: `bin/keel version`
Expected: the new string, matching `VERSION` exactly.

- [x] **Step 4: Run the whole gate**

```bash
tests/run-tests.sh
tests/supply-chain-scan.sh
```

Expected: `All test files passed`, and a clean scan.

**Executed 2026-08-17 with steps 4 and 5 inverted, because the gate cannot pass before the commit.**
`tests/test-cache-install.sh` archives `HEAD` and runs `keel version` from a tracked-files-only copy,
so an uncommitted bump reddens it by construction. Observed rather than assumed: with `VERSION` at
`0.9.0` in the working tree and `HEAD` still at 0.8.0, it reported `FAIL version, from a
tracked-files-only copy (got: 0.8.0)`, `3 passed, 1 failed`. The session handoff records this trap.

So the commit was made first and the full gate run against it. Nothing is skipped and the ordering is
the only thing that changed; had the gate failed, the fix would have been a follow-up commit rather
than an amend, since the tag is cut from what is recorded.

The behavioural evals are **not** run here and this task must not claim they were. Decision 9 gates
a release on them, and `tests/evals/run.sh` costs API tokens and is dispatched by an agent rather
than a script. Whoever cuts the release runs them and records the result in
`tests/evals/results.md`, including any new rationalisation, which decision 9 calls the most
valuable output of a release.

- [x] **Step 5: Commit**

```bash
git add CHANGELOG.md VERSION .claude-plugin/plugin.json .keel/profile.json
git commit -m "chore(release): 0.9.0"
```

---

## Self-review

Run against this plan on 2026-08-17.

1. **Scope coverage.** All four items map to tasks. Item 1: task 1. Item 2: task 2. Item 3: tasks 3,
   4 and 5. Item 4: tasks 6 and 7. Task 8 records the lot.
2. **Placeholder scan.** No "TBD", no "handle edge cases", no "similar to task N". Every code block
   is the literal text to write. Task 8 step 2 describes the CHANGELOG entry's contents rather than
   writing it, which is the one place prose is specified rather than quoted: it depends on the answer
   to step 1 and on what tasks 1 to 7 actually produced.
3. **Name consistency.** `GBI_ALLOWED` and `gbi_allowed()` are used identically in task 1 steps 3
   and the scanner loop. `tests/test-doc-claims.sh` is named the same in tasks 3, 4 and 8.
   `tool_choices.md` is `skills/keel/references/tool-choices.md` in tasks 6 and 7 and in the section
   10 citation, at the link depth `../../keel/references/` that six skills already use.
4. **Command accuracy.** Every verifying command is from `profile.verify`: `tests/run-tests.sh`, or
   `tests/{name}` for a single file. `shellcheck` is only invoked through the suite, which reads the
   lint string from the profile so the two cannot drift. `grep`, `find`, `git log` and
   `--list-rules` are investigative and need no profile entry.
5. **Every task ends with a commit step.** Yes, eight of eight.
6. **No task depends on a file no task creates.** `tests/test-doc-claims.sh` is created in task 3 and
   referenced by tasks 4 and 8. `tool-choices.md` is created in task 7, in the same task as the rule
   that requires it and the citation that reads it.
7. **Tasks with no test say so.** Tasks 2, 4, 5 and 6 each open with an explicit step 1 naming why,
   rather than inventing an assertion. Tasks 1, 3 and 7 are ordinary red-green.
8. **Word budgets.** Task 1 is the only one touching a skill body. Three of its four edits are
   neutral or negative; `debug` gains four words and step 6 measures rather than assuming, with a
   named remedy if it crosses. Task 7 adds nothing to any body.
