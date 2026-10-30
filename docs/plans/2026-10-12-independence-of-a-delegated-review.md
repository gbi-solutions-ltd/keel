# Independence of a delegated review Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task. Task 1 changes shell code and runs the real
> cycle. Tasks 2 to 5 change text, and their test is the applied check in the section below.

**Goal:** `agents/` is checked by the same rules as `skills/`, a directly invoked `review-code`
reviews outside the context that produced the work, the rules that make a review trustworthy are
stated once, and the `remediation` rule binds at ship.
**Stories:** none. See "There are no stories, and that is a deviation worth naming" below.
**ADRs:** ADR-0001 (a body over the 700 word target owes a passing eval arm at its length) and
ADR-0005 (one skill body per skill across harnesses). Neither decision changes. ADR-0001 shaped the
first design of tasks 2 and 3 and no longer orders them: see "The budget, measured".
**Architecture:** no new skill, no new agent, no new hook, no schema change. Two new references, one under
`skills/keel/references/` and one under `skills/review-code/references/`, one new rule in
`tests/validate-skills.sh`, and edits to existing files. Decided in `docs/ideas/independence-of-a-delegated-review.md`, whose open questions 5 to 7
were answered on 2026-10-12 and whose answers this plan implements.
**Reviewed:** by a dispatched plan reviewer on 2026-10-12, verdict BUILDABLE-WITH-CHANGES. Its two
blocking findings and all eight lesser ones are applied in this revision; what changed is recorded
in "What the review changed" below.

## Global constraints

Copied verbatim from `.keel/profile.json`, `docs/standards.md` and the idea record. Every task
inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  `verify.typecheck`, `verify.build`, `verify.e2e` and `verify.test_integration` are all `null`.
- **`shellcheck` is not installed on the machine this plan was written against.** Task 1 is the only
  task that changes shell. Its lint step says what to do when the command is absent rather than
  pretending it ran; CI runs the same command from the profile, so the gate is not lost.
- Never start on `main`. Work lands through a pull request, reviewed by somebody other than its
  author.
- No em dashes and no en dashes, in any file or commit message. Where a test must contain one to
  prove the rule, it is written as the byte escape `\xe2\x80\x94`, matching `m_em_dash` at
  `tests/test-validate-skills.sh:162`, so neither the test file nor this plan holds one.
- A skill body stays within ADR-0001's 900 word ceiling, and crossing the 700 word target owes a
  passing eval arm at that length. **No scenario in `tests/evals/scenarios/` injects `review-code`**,
  confirmed by reading all 13 `Inject:` lines, so no arm can be run for it. Its body therefore stays
  under 700 in this plan, and that is a hard constraint rather than a preference.
- **A rule that sits inside a prompt block a dispatcher pastes does not move.**
  `skills/write-plan/references/plan-review.md` and
  `skills/execute-plan/references/subagent-prompts.md` carry their rules inside fenced prompts that
  are pasted into a dispatch, and a subagent reads what it is given, not what the file links to.
  Task 2 deduplicates the **reasoning** around those prompts and leaves every line inside them
  literal. Breaking this is how a deduplication silently removes a rule from a dispatch.
- Every rule added anywhere in this plan states its reason, and the best reasons name a measured
  failure.
- Documentation lands in the same commit as the change it describes: `README.md`, `CHANGELOG.md`
  and this plan. Task 3 carries three further documents for the reason finding 5 of the review gave.

---

## The applied check

Tasks 2 to 5 move or add text in shipped files. **Their test is the applied check, not a unit
test**, and each task's own steps name the commands and the expected output. This section exists
once rather than as a first step in four tasks, following
`docs/plans/2026-09-29-skill-review-changes.md`, which hoists the same statement to its own section
and points each task's Interfaces block at it.

No fabricated test anywhere: an invented test for a prose move reads as coverage and checks
nothing, which `plan-template.md` calls worse than an honest gap.

The checks these tasks use, all read-only and all from the profile's `verify.test` suite:

| Command | What it proves |
|---|---|
| `tests/validate-skills.sh` | 0 FAIL, and the WARN set unchanged from the start of the plan. Relative links resolve, dashes are absent, bodies are inside ADR-0001 |
| `tests/validate-citations.sh` | A cited heading exists. A heading quoted wrongly fails here rather than pointing at nothing |
| `awk 'f;/^---$/{c++; if(c==2) f=1}' <skill> \| wc -w` | The body word count ADR-0001 governs |
| `tests/test-doc-claims.sh` | A documented count the tree contradicts |

## There are no stories, and that is a deviation worth naming

`write-plan` step 1 stops and names `write-user-stories` where no stories exist. There are none
here, and no PRD. The input is `docs/ideas/independence-of-a-delegated-review.md`, shaped on
2026-10-12, whose open questions 5 to 7 were put to the user as choices the same day and answered,
and whose recommendation is the four changes below.

That is the shape `docs/plans/2026-08-31-release-operations-and-claims-audit.md` and
`docs/plans/2026-08-30-design-database.md` both ran under, and the same reasoning applies: the
deciding step has been run, and a PRD would restate a decision already taken.

**One thing is different from those precedents and is better.** Both wrote content whose value had
not been measured against a baseline. Task 1 here is not content, it is a check, and it is verified
able to fail before it is written: the gap it closes was proved by mutation on 2026-10-12, when an
em dash appended to `agents/keel-fanout.md` produced 0 FAIL from `tests/validate-skills.sh`. Tasks 2
to 4 are text, and each carries an applied check rather than an unmeasured claim.

**What is still unmeasured, and task 5 records it as such:** nothing on record shows a review passing
work because it ran in the context that produced it. Task 3 buys independence on the argument that a
reviewer anchored on code it watched being written is a worse reviewer, which `plan-review.md`
already rests on, and on a context saving that is real and counted. It is not a measured defect
being fixed, and the changelog must not imply otherwise.

## The budget, measured

The numbers below were measured against the tree at `25320b5` on 2026-10-12 and re-derived
independently by the plan reviewer the same day, who applied the first design's verbatim text to a
copy and counted the result.

| Body | Now | After task 2 | After task 3 | Target | Arm owed |
|---|---|---|---|---|---|
| `review-code` | 645 | 587 | 480 | 700 | none |

**This table changed twice, and the history matters.** The first design inserted an 81 word
paragraph into `review-code`, which on its own would have landed the body at 726, over the 700
target and owing an eval arm that cannot be run because no scenario injects this skill. Task 2 was
ordered first because it freed 64 words, and was described as what makes task 3 legal. The first
review of task 3 then showed that paragraph could not work, because a subagent has to be handed the
diff, the standards and the rubric path and told the five house checks, and none of that fits in
81 words. Task 3 became a brief, `skills/review-code/references/rubric-pass.md`, which carries the
inputs and the five checks, and the five checks left the body: the driver does not run them. The
body now falls to 480 words after task 3.

So **task 2 is no longer what makes task 3 legal**, and this plan should not be read as saying it
is. Task 2 stands on its own reason, the reporting rules' reasons stated once, and its ordering
before task 3 is only that task 3 cites the reference task 2 creates.

No other body changes. `write-plan` stays at 761 and `execute-plan` at 889; task 2 touches only
their reference files, which the validator's budget loop (`for skill in skills/*/SKILL.md`) does not
read.

## What the review changed

A dispatched reviewer read this plan against the tree on 2026-10-12 and returned
BUILDABLE-WITH-CHANGES. Recorded here because the findings are the reason several steps look the way
they do, and a later reader would otherwise read the oddities as arbitrary.

| Finding | What it was | Applied as |
|---|---|---|
| Blocking | Task 1 put two `check_reports` calls near `tests/test-validate-skills.sh:162`, about 656 lines before the function is defined at `:818`. With `set -uo pipefail` and no `set -e`, that prints `command not found`, counts neither pass nor fail, and the suite still exits 0 | Step 1.1 now places the three `run` cases and the two `check_reports` cases separately, and says why |
| Blocking | The done condition read "more than the 54 it holds today". The suite reports **103 passed**; 54 was a grep that counted only `^run` lines and missed `run_out` and `check_reports`. The block is five cases, not four | Every count corrected: 103 to 108, five cases |
| Should fix | `tests/validate-skills.sh:409` is a comment about the cheatsheet, not the delegation floor, which is `:489` | Corrected here and in the idea record |
| Should fix | Step 3.5 told the implementer to preserve a `**Plugin call` lead that `review-code`'s catalogue entry does not have, and was the one text edit with no verbatim content | Step 3.4 now gives the verbatim text for all three documents |
| Should fix | `docs/standards.md` says "all seven delegating skills" three times. Task 3 makes `review-code` the eighth, and no task touched that file, against this plan's own documentation constraint | `docs/standards.md` and `docs/04-plugin-strategy.md` added to task 3 |
| Should fix | The idea record assigned the agent-description-budget question to change 1, and task 1 neither took it nor declined it | Step 1.3 decides it, with the measurement |
| Consider | Four tasks each opened with a step that was an assertion rather than an action | Hoisted into "The applied check" above, removing four steps |
| Consider | The floor read `-gt 0` where this repo pins a floor to a recorded count with its date | Now `-ge 1` with the count and date in the message |
| Consider | The citation baseline said 1879 | 1882, measured |
| Consider | `shellcheck` is absent on this machine and no step ran lint | Named in the global constraints and in step 1.5 |

## What the task 2 review changed

Execution found these, by running the plan rather than reading it. Recorded for the same reason.

| Finding | What it was | Applied as |
|---|---|---|
| Blocking | The first task 2 moved "do not rewrite it in the review" out of `review-code` and left it only in the new reference, so a reviewer at the point of use no longer saw it. The standard it breached: a rule stays stated where it is used, and the reason is what moves | Step 2.3 keeps both rules as sentences in the body. The two table rows still go, because each is now a duplicate. Budget re-measured: 587, not 581 |
| Should fix | The reference claimed four places state its rules, and that `execute-plan` states "the coordinator's version" of the rewrite rule. Reading them: pass 3's prompt has no location rule, the plan reviewer's has no cap, and `subagent-prompts.md` states a different rule with the same cause | Reference intro and the rewrite section reworded; step 2.4 now gives each of the two citing files its own accurate sentence |
| Should fix | `skills/write-docs/references/claims-audit.md:104` attributes the cap's reasoning to `review-code`, which no longer holds it | Added to task 2's Files and step 2.4 |
| Should fix | The task 1 follow-up, found the same way: a 29 line insertion moved a line number an audit cites, and the plan's own text quoted the stale number | Step 1.5 now carries the citation fix |
| Consider | The reference's closing section restated the rubric's own closing sentences | It now points at the rubric section instead |

## What the task 3 review changed

| Finding | What it was | Applied as |
|---|---|---|
| Blocking | The inserted paragraph never said what the subagent is given: the diff and its base, the plan, the standards, the decisions, the suite result. It gave the rubric as a relative path a subagent cannot resolve, and the rubric's own "verify.test already ran in SKILL.md step 3" and revert check assume context and a tree the subagent does not have | Task 3 is rebuilt as a brief, `skills/review-code/references/rubric-pass.md`, in the shape of `plan-review.md`, with the hand-over list, an absolute rubric path, the suite result passed in, and the revert check moved to a throwaway worktree. The body keeps a short paragraph that links to it: 651 words, not 668 |
| Should fix | Step 2 still said "do the inline pass" and "Continuing inline" beside a step 3 that says never inline, and `docs/04-plugin-strategy.md` still described the inline fallback as the pattern in every skill | Step 3.3 rewords step 2's fallback; step 3.5 adds a paragraph to the strategy doc |
| Should fix | The precedence clause attached its participle to the wrong noun and its premise, that the pass had read the plan, the decisions and the standards, was not instructed anywhere | Reworded, and the brief tells the subagent to read all three |
| Should fix | `docs/standards.md` "four of the seven" is a historical sentence whose own arithmetic is seven; changing it to eight was wrong | Step 3.5 changes only the two current-tense places |
| Should fix | Three live citations in `docs/prd/coding-standards-enforcement.md` pointed at the severity table by line | Added to step 3.6 |
| Consider | The `inherit: ` label is checked by no script; the earlier text said omitting it "breaks the build" | Step 3.3 says it is held by review. Whether to check it is left to the user |

Second round, on the rebuilt task 3:

| Finding | What it was | Applied as |
|---|---|---|
| Blocking | The five house checks lived only in the body and `rubric.md` does not contain them; the prompt also called the revert check "item 5 of the rubric", which in `rubric.md` is "Reuse and simplification" | The five checks are items 1 to 5 of the brief's prompt and leave the body, which falls to 480 words. The prompt names the test command to run |
| Should fix | The worktree instruction assumed committed work, and omitted `--detach`, applying an uncommitted diff, and removing the worktree | Reworded in the prompt, and the diff command differs for committed and uncommitted work |
| Should fix | "Build it from where you loaded this skill" was not actionable | The rubric path is the brief's own path with `rubric-pass.md` replaced by `rubric.md` |
| Should fix | The prompt did not say the suite already ran, or that a missing suite is itself a finding | Both said in the prompt |
| Should fix | Precedence was looser than the user's decision and said nothing of silence | "Reading the result" now says a conflict is a stated disagreement about a cited line and that a clean result does not clear a plugin finding |
| Should fix | The brief called `plan-review.md`'s failure "measured" for code review | It says no instance is on record for code and that the brief rests on the argument |
| Consider | Three lines over 100 columns | Rewrapped in the text above |

Found by the fourth dispatch: the body is now shorter than a line number a 2026-09-06 plan cites, so
that citation points past the end of the file and the suite goes red. Added to step 3.6.

---

### Task 1: `agents/` is checked by the same rules as `skills/`

**Story:** none. This task closes a gap proved by mutation; see the deviation section.
**Files:**
- Modify: `tests/validate-skills.sh`
- Modify: `docs/audits/2026-09-25-standards.md` (line 125 cites `tests/test-validate-skills.sh at lines 191 and 194`,
  which the insertion in step 1.1 moves; added after the first dispatch found it, see step 1.5)
- Test: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: `report` (`tests/test-validate-skills.sh` has its own; the validator's is at
  `tests/validate-skills.sh:96`), `frontmatter_of` (`:101`), and the content `find` loop (`:207`).
  In the test file: `run` (`:55`), `check_reports` (`:818`), `fixture_valid` (`:21`)
- Produces: a frontmatter rule for `agents/*.md`, with a floor. No function other skills call

**Depends on:** none

**Done when:** `tests/test-validate-skills.sh` reports `108 passed, 0 failed`, up from the
`103 passed, 0 failed` it reports today.

- [x] **Step 1.1: Write the failing cases** Note: witnessed by review: five cases present at the two named places; implementer wrote them

Five cases, and **they go in two places, not one.** `check_reports` is defined at
`tests/test-validate-skills.sh:818` and the file runs under `set -uo pipefail` with no `set -e`, so
a call placed above the definition prints `command not found`, increments neither counter, and
leaves the suite exiting 0 with `0 failed`. The two cases that would silently vanish are the floor
cases, which is the exact vacuous-pass class the floor exists to prevent.

**The three `run` cases go beside `m_em_dash` at `:162`**, in the `# Forbidden constructs` section.
`fixture_valid` builds no `agents/` directory, which is what the floor's guard must tolerate, so
each mutator creates one.

```bash
# An agent file is shipped content and obeys the content rules. Proved absent by mutation on
# 2026-10-12: an em dash appended to agents/keel-fanout.md gave 0 FAIL, because the content loop
# reads skills, templates and output-styles, and docs has its own.
m_agent_em_dash() {
    mkdir -p "$1/agents"
    printf -- '---\nname: a-profile\ndescription: Use when testing.\nmodel: sonnet\n---\n\nA body with an em dash \xe2\x80\x94 in it.\n' \
        > "$1/agents/a-profile.md"
}
run "an em dash in an agent file is rejected" 1 m_agent_em_dash

# The model value is the one field a dispatching skill cannot override, so a typo here routes every
# dispatch naming this profile to nothing. The vendor set is allowed HERE and rejected in a skill
# body: an agent file is where a harness resolves a profile to a model, which is the indirection
# `lib/harness/codex.sh` (deleted after v0.26.0) relies on to map keel-fanout to a Codex model.
m_agent_bad_model() {
    mkdir -p "$1/agents"
    printf -- '---\nname: a\ndescription: Use when testing.\nmodel: gpt-4o\n---\n\nBody.\n' \
        > "$1/agents/a.md"
}
run "an agent naming a model alias no harness accepts is rejected" 1 m_agent_bad_model

m_agent_no_model() {
    mkdir -p "$1/agents"
    printf -- '---\nname: a\ndescription: Use when testing.\n---\n\nBody.\n' > "$1/agents/a.md"
}
run "an agent with no model is rejected" 1 m_agent_no_model
```

**The two `check_reports` cases go after the function's definition**, at the file's tail beside the
delegation floor cases, which are the nearest thing of the same kind.

```bash
# The floor. An agents directory that exists and yields no file means the walk is reading nothing,
# which passes every assertion above. Two rules in this repository have already passed at zero.
m_agent_dir_empty() {
    mkdir -p "$1/agents"
}
check_reports "an agents directory the walk reads nothing from is reported" yes \
  "read no agent file" m_agent_dir_empty

# And the other direction, so the floor cannot be satisfied by firing always.
m_agent_healthy() {
    mkdir -p "$1/agents"
    printf -- '---\nname: a\ndescription: Use when testing.\nmodel: inherit\n---\n\nBody.\n' \
        > "$1/agents/a.md"
}
check_reports "a healthy agents directory does not trip the floor" no \
  "read no agent file" m_agent_healthy
```

The `# shellcheck disable=SC2016` at the top of the test file already covers these single-quoted
printf strings.

- [x] **Step 1.2: Run them and watch them fail** Note: implementer read 104 passed, 4 failed; the fifth case passes on arrival by design; plan expectation corrected

Run: `tests/test-validate-skills.sh`
Expected: FAIL. The three `run` cases report `expected exit 1, got 0`, because nothing reads
`agents/`. Both `check_reports` cases fail on the needle being absent. The summary line reads
`104 passed, 4 failed`. The fifth case, `a healthy agents directory does not trip the floor`, passes on
arrival and should: it asserts a needle is absent, which is true before the rule exists. It earns
its place after step 1.3, where it stops the floor from being satisfied by firing always. (The plan
first said `103 passed, 5 failed`; the first dispatch ran it and read 104 and 4, so the expectation
is corrected here.)

**If it reads `103 passed, 0 failed`, stop.** That means the cases did not run at all, which is
blocking finding 1 reproducing itself, and the remedy is their placement, not the rule.

- [x] **Step 1.3: Write the minimal implementation**

Two edits to `tests/validate-skills.sh`.

First, bring `agents` into the content loop at line 207, so the dash, docs-root and link rules
apply:

```bash
done < <(find skills agents templates output-styles -name '*.md' 2>/dev/null)
```

Second, a frontmatter rule, placed immediately after the `bad_models` block that ends at line 338,
which is top level and inside no conditional. The two are the same subject read from opposite ends:
that one forbids a vendor alias in a skill, this one requires a valid alias in the file that
resolves it.

```bash
# An agent file is a delegation profile: a name a skill dispatches to and a harness resolves to a
# model. Nothing checked one until 2026-10-12, when an em dash appended to agents/keel-fanout.md
# gave 0 FAIL. The content loop above now covers the dashes, the docs root and the links; what is
# left is the frontmatter, and the model field is the part no dispatching skill can override, so a
# typo there routes every dispatch naming the profile to nothing and does it silently.
#
# THE VENDOR SET IS ALLOWED HERE AND REJECTED IN A SKILL BODY, deliberately. The check above exists
# so a skill names a profile rather than a model; this file is the one place the profile becomes a
# model, which is the indirection `lib/harness/codex.sh` (deleted after v0.26.0) relies on to map
# keel-fanout to a Codex model. Forbidding the alias here would leave the mapping nowhere to live.
# The set is what the harness accepts, not what this tree uses: nothing here names fable, and a set
# narrowed to current usage would reject a correct file the day somebody needs one.
#
# THE DESCRIPTION IS CHECKED FOR PRESENCE AND NOT FOR LENGTH. The 216 character ceiling that bounds
# a skill description is deliberately not applied: agents/keel-fanout.md's own description is 242
# characters, so extending it here would fail the only agent file in the tree, and
# docs/standards.md calls a check stricter than correct output the unrecoverable failure. Whether an
# agent description belongs in the 1,320 token always-loaded total is a separate measurement nobody
# has taken; it is not taken here, and this comment is where that is recorded.
#
# Guarded on the directory existing, like every other repository-only check here, because
# tests/test-validate-skills.sh runs this validator from fixture roots that build no agents/.
if [ -d agents ]; then
    agents_read=0
    for agent in agents/*.md; do
        [ -e "$agent" ] || continue
        agents_read=$(( agents_read + 1 ))
        afm=$(frontmatter_of "$agent")
        grep -q '^name:' <<<"$afm" || report "$agent: frontmatter has no name"
        grep -q '^description:' <<<"$afm" || report "$agent: frontmatter has no description"
        amodel=$(printf '%s' "$afm" | sed -n 's/^model:[[:space:]]*//p')
        if [ -z "$amodel" ]; then
            report "$agent: frontmatter has no model. A dispatch naming this profile resolves to nothing, silently."
        else
            case "$amodel" in
                sonnet|opus|haiku|fable|inherit) : ;;
                *) report "$agent: model is \"$amodel\", which no harness accepts. Use sonnet, opus, haiku, fable or inherit." ;;
            esac
        fi
    done
    # The floor, pinned to a recorded count the way the delegation floor at :489 is. Without it this
    # rule passes every assertion above by reading nothing, which is the failure this repository has
    # already shipped twice: the section-10 grep that could not fail, and two spawn-count assertions
    # that passed at zero.
    [ "$agents_read" -ge 1 ] \
      || report "agents/ exists and the walk read no agent file, against 1 on 2026-10-12, so this rule is checking nothing. Either the directory is empty or its files are not named *.md."
fi
```

- [x] **Step 1.4: Run them and watch them pass** Note: reviewer re-ran: 108 passed, 0 failed; validator 0 FAIL, 10 WARN; citations 1898 OK

Run: `tests/test-validate-skills.sh`
Expected: `108 passed, 0 failed`.

Then run the validator against this repository and confirm it is still clean:

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, and the same 10 WARN as before the task. `agents/keel-fanout.md`
declares `name`, `description` and `model: sonnet`, carries no dash, no `docs/keel` path and no
relative link, so it passes without being edited.

- [x] **Step 1.5: Lint, run the suite at the unit boundary, then hand over** Note: shellcheck NOT run (absent locally); run-tests red on a moved audit citation, fixed in this task; CI runs the lint

Run the profile's `verify.lint` command.
Expected: clean. **`shellcheck` is not installed on the machine this plan was written against.**
Where `command -v shellcheck` is empty, say so in your report and name it as not run rather than
reporting a pass; CI runs the same command from the profile, so the gate holds either way. Do not
install it: that is a change to the machine, not to this task.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one suite run the task schedules.

**One citation moves, and the suite goes red on it.** Line 125 of `docs/audits/2026-09-25-standards.md`
cites `tests/test-validate-skills.sh at lines 191 and 194`, the two must-not-reject cases that step 1.1's
29 line insertion shifts. `tests/validate-citations.sh` reports `line 191 ... is blank` and
`tests/run-tests.sh` fails on it. Replace `tests/test-validate-skills.sh at lines 191 and 194` in that audit row with
`tests/test-validate-skills.sh#a bare mention of the default docs root is allowed` and
`tests/test-validate-skills.sh#a template comment naming the default is allowed`, the `file#phrase`
form the row's third citation already uses and the remedy the checker itself gives ("replace the
line number with a phrase from the text"), then run `tests/validate-citations.sh`.
Expected: no FAIL. Do not relocate the new cases to keep the old numbers: they belong beside
`m_em_dash`, and every later line number would drift silently instead, which no check reports.

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh docs/audits/2026-09-25-standards.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(tests): agents/ is checked by the rules that govern skills/"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

**Task 1 review, 2026-10-12.** Pass one COMPLIES. Pass two: nothing blocking, four should-fix, not
acted on here because each is a change to the task's verbatim code and the user has not ruled on
them. (1) The model set `sonnet|opus|haiku|fable|inherit` refuses a full model ID such as
`claude-sonnet-4-5`, which Claude Code accepts; the comment's "what the harness accepts" is then
wrong, and standards.md says a check stricter than correct output is unrecoverable. (2) No case pins
the must-not-reject direction, for example an agent shaped like `keel-fanout` with a 242 character
description. (3) Nothing tests the `name` and `description` presence checks. (4) `name` is checked
for presence only, not against the file's basename. Considers: the comment cites the delegation floor
as `:489`, which this diff moved; the `codex.sh` justification overstates that file's reach.

---

### Task 2: the review rules are stated once, with their reasons

**Story:** none. Test: the applied check, per the section above.
**Files:**
- Create: `skills/keel/references/reporting-findings.md`
- Modify: `skills/review-code/SKILL.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `skills/write-docs/references/claims-audit.md` (line 104 attributes the cap's reasoning to
  `review-code`, which step 2.3 moves; found by the quality review)
- Modify: `docs/plans/2026-08-31-release-operations-and-claims-audit.md` (line 561 cites
  `skills/review-code/SKILL.md` by line number, which step 2.3 moves; added after the first dispatch
  found it, see step 2.7)

**Interfaces:**
- Produces: `skills/keel/references/reporting-findings.md`, cited by the three files above. Task 3
  cites it too
- Consumes: nothing

**Depends on:** none

**Done when:** `tests/validate-skills.sh` exits 0 with `0 FAIL`, and
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w` reports 587.

- [x] **Step 2.1: Record the starting state**

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, 10 WARN. Record the WARN lines; task 2 must not add one.

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w`
Expected: 645. If it is not 645, stop: the budget table was measured against `25320b5` and a
different number means the body moved under you, so the arithmetic in "The budget, measured" needs
redoing before task 3 can be legal.

- [x] **Step 2.2: Write the shared reference**

Create `skills/keel/references/reporting-findings.md` with exactly this content:

```markdown
# Reporting findings

Read this once before reporting a review. It carries the reason behind the rules that the skills
which judge work state at their own point of use: `review-code`, `write-plan`'s plan reviewer, and
the two passes `execute-plan` dispatches. Not every place states every rule, and this file does not
claim they do.

The rules stay stated at the point of use, because a reviewer under time pressure reads the step in
front of it, and a subagent reads only the prompt it is pasted. **This file carries the reasons**,
which is what stops the rules being rationalised away, and it carries them once rather than in each
place that states a rule. A reviewer subagent does not read this file; the dispatcher does.

## Rank, and put blocking first

A reviewer who buries approval under nine nitpicks trains people to skim reviews, and a skimmed
review is worth less than none: it costs the author's time and buys no confidence.

## Say plainly when nothing blocks, in the first line

A reviewer who cannot approve invents problems. The instruction is not to be kind, it is to keep the
verdict informative: if every review returns findings, the presence of findings stops meaning
anything. Name what you checked, including what was fine, so a reader can tell a clean review from
an incurious one.

## Cap at around ten

More than about ten findings is itself the finding: the change is too large to review in one pass.
A fixed cap with nothing said drops whichever finding came eleventh and gives no signal that
anything was dropped, which is worse than reporting the size problem.

## Never a finding without a location, and never a location without a reason

A finding without a `path:line` is a guess, and the reader cannot check it without re-reading the
tree. `shape-idea` makes the same point about a challenge: one carrying a `path:line` changes a
decision, and the same challenge from instinct starts an argument and loses.

## Do not rewrite it in the review

Say what is wrong and let the author fix it. A reviewer that repairs what it found has removed the
decision somebody else was going to make, and in a delegated run an edit by the reviewer is a change
that neither review pass has read. `execute-plan` gives the same reasoning for the coordinator, under
"What you keep, and what you do not touch" in
`../../execute-plan/references/subagent-prompts.md`; that is a different rule with the same cause.

## "Looks good" is not a review

Name what you checked. A verdict with no evidence of reading is indistinguishable from not having
read it, and it is the one outcome that makes every later review from the same reviewer worth less.
The `review-code` rubric works this through with an example, under "Saying it is fine" in
`../../review-code/references/rubric.md`.
```

- [x] **Step 2.3: Trim the reporting rules in `review-code` to their statements**

In `skills/review-code/SKILL.md`, replace the two paragraphs after step 4's severity table:

```markdown
Put blocking findings first. If nothing blocks, say so in the first line: a reviewer who buries
approval under nine nitpicks trains people to skim reviews.

Cap it at around ten findings. More than that means the change is too large to review, and that
is itself the finding.
```

with one line:

```markdown
Blocking first. If nothing blocks, say so in the first line and name what you checked. Cap at
around ten.
```

Then in step 5, replace:

```markdown
Per finding: `file:line`, what is wrong, why it matters, and what to do. Never a finding without a
location, and never a location without a reason.
```

with:

```markdown
Per finding: `file:line`, what is wrong, why it matters, and what to do. Do not rewrite it yourself;
the author fixes it.

Read [../keel/references/reporting-findings.md](../keel/references/reporting-findings.md) once: it
carries the reason behind each rule.
```

And drop the two conduct rows from the Common mistakes table, leaving the table below. Both rules
stay stated in the body above, so dropping the rows removes a duplicate and not a rule:

```markdown
| Mistake | Instead |
|---|---|
| Style comments a formatter should make | Fix the tooling instead, once |
| Passing a behaviour change with stale docs | Documentation is part of the gate, not a follow-up |
```

The two removed rows, `"Looks good" with no evidence of reading` and
`Rewriting it yourself in the review`, are now the sentences "name what you checked" in step 4 and
"Do not rewrite it yourself; the author fixes it" in step 5, with their reasons in the new reference. **The
first version of this step removed the rules and kept only the reasons; the quality review of task 2
blocked it, because a rule a reviewer must follow a link to learn is not stated at the point of
use.**

- [x] **Step 2.4: Cite the reference from the other two, outside their prompt blocks**

In `skills/write-plan/references/plan-review.md`, add one line to the "Reading the result" section,
**after** the fenced prompt and not inside it:

```markdown
[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) carries
the reason behind the location and first-line rules the prompt above states.
```

In `skills/execute-plan/references/subagent-prompts.md`, add this line to the prose under
"## 3. Code quality review", after that section's fenced prompt:

```markdown
[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) carries
the reason behind the ranking, cap and first-line rules the prompt above states.
```

The two wordings differ on purpose: pass 3's prompt states no location rule and the plan reviewer's
states no cap, and a citation that names a rule its prompt lacks is the overclaim the quality review
found. Both files sit one directory below a skill, so the relative path is identical in each.

In `skills/write-docs/references/claims-audit.md`, line 104 reads "`review-code` caps at around ten
findings, on the reasoning that more than that means the change is too large to review and that is
itself the finding." Replace that clause so the reasoning is attributed to where it now lives,
with this text (as a fenced block here, so this plan carries no live link of its own):

```markdown
`review-code` caps at around ten findings, and
[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) gives the
reason: more than that means the change is too large to review, and that is itself the finding.
```

Keep the paragraph wrapped at 100 columns.

**Change nothing inside either fenced prompt.** Those blocks are pasted into a dispatch and a
subagent reads what it is given, so a rule moved out of one is a rule the subagent never sees. This
is the global constraint, restated here because this is the step where it would be broken.

- [x] **Step 2.5: Record the new reference in the repo layout**

Add a line to `docs/06-repo-layout.md` beside `asking-questions.md` and `tool-choices.md`, which are
at `:99-100`:

```
│   │   ├── reporting-findings.md     # the reason behind the reporting rules the judging
│   │   │                             # skills state at their own point of use
```

Match the surrounding tree's exact indentation and comment column rather than this snippet's.
`tests/test-doc-claims.sh` reads only that file's top-level entries against `git ls-files`, so a
nested line is invisible to it and this edit is for the reader.

- [x] **Step 2.6: Run the applied checks and watch them pass**

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, the same 10 WARN as step 2.1. A new relative link resolving is what this
proves; a broken one would FAIL here.

Run: `tests/validate-citations.sh`
Expected: `OK`, at or above the 1882 citations recorded on 2026-10-12.

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w`
Expected: 587.

- [x] **Step 2.7: Run the suite at the unit boundary, then hand over** Note: full suite passed on a coordinator run (exit 0, 2m36s); an implementer run saw one test-no-leaks red that did not reproduce in ten reruns; shellcheck not run (absent)

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

**One citation goes blank and the suite goes red on it, as in task 1.**
`docs/plans/2026-08-31-release-operations-and-claims-audit.md:561` cites
`skills/review-code/SKILL.md` at lines 72 to 73, quoting the "Per finding" sentence and its second
sentence, which step 2.3 moves into the new reference. Replace that citation, and only it, with the
`file#phrase` form naming both homes: `skills/review-code/SKILL.md#Step 5: Report` and
`skills/keel/references/reporting-findings.md#Never a finding without a location, and never a location without a reason`.
Leave the quotation as it is: that plan records what the file said on 2026-08-31. Then run
`tests/validate-citations.sh`. Expected: `OK`.

Other citations of the four edited files also move and the checker does not see them, because it
only fails on a blank target. They are in dated records (results, audits, older plans) that state
what a file looked like then, and are reported rather than edited. The ones in this plan's own idea
record are corrected in step 5.2.

```bash
git add skills/keel/references/reporting-findings.md skills/review-code/SKILL.md \
        skills/write-plan/references/plan-review.md \
        skills/execute-plan/references/subagent-prompts.md docs/06-repo-layout.md \
        skills/write-docs/references/claims-audit.md \
        docs/plans/2026-08-31-release-operations-and-claims-audit.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "refactor(skills): the review reporting rules carry their reasons in one place"`.

**Task 2 review, 2026-10-12.** Second attempt. Pass one COMPLIES. Pass two: nothing blocking, both
blockers from the first attempt resolved with evidence. Three should-fix findings: two stale
quotations of moved text in live documents, assigned to task 3 step 3.4 (`docs/02-skill-catalog.md`
`**Writes:**` line) and task 5 step 5.2 (`skills/write-docs/references/claims-audit.md:12-13`); and
one not acted on, because it changes the body again: the cap's consequence ("more than that is
itself the finding") no longer appears in `review-code`, which says only "Cap at around ten.". About
seven words restore it and the budget has room, so it is a call for the user. Considers: the
reference intro lists the spec-compliance pass among places that state these rules, which it does
not (hedged by "not every place states every rule"); the location section gives a reason for only
half its heading; the `plan-review.md` citation sits a section below its prompt. The full suite
passed once, 2m36s; a red `tests/test-no-leaks.sh` in an earlier run did not reproduce in ten reruns.

---

### Task 3: `review-code` reviews outside the context that produced the work

**Story:** none. Test: the applied check, per the section above.
**Files:**
- Create: `skills/review-code/references/rubric-pass.md`
- Modify: `skills/review-code/SKILL.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `docs/04-plugin-strategy.md`
- Modify: `docs/standards.md`
- Modify, one citation each, which this task's edits move and which turn `tests/run-tests.sh` red or
  leave a live document pointing at the wrong line (found by the first two dispatches; see step
  3.6): `docs/architecture/tiered-multi-harness-claim-inventory.md`,
  `docs/ideas/independence-of-a-delegated-review.md`, `docs/prd/coding-standards-enforcement.md`,
  `docs/plans/2026-08-31-release-operations-and-claims-audit.md` and
  `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`
- Modify, in step 3.7 only, after the quality review of the committed task:
  `skills/review-code/references/rubric.md` and `docs/06-repo-layout.md`

**Interfaces:**
- Consumes: `skills/keel/references/reporting-findings.md`, created in task 2
- Produces: `skills/review-code/references/rubric-pass.md`, the brief the body links to. Nothing
  else calls it

**Depends on:** task 2

**Done when:** `tests/validate-skills.sh` exits 0 with `0 FAIL` and no new WARN,
`awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w` reports 480, and
`grep -c 'seven delegating skills' docs/standards.md` reports 0.

**Why this task is a brief and not a paragraph.** The first version of this task inserted one
81 word paragraph into the body saying "dispatch, model `inherit`, told to read the rubric". Its
quality review blocked it: the paragraph never said what the subagent is handed (the diff and its
base, the plan, the standards, the decisions, the suite result), gave the rubric as a relative path a
subagent in the repository cannot resolve, and left the rubric's own "verify.test already ran in
SKILL.md step 3" and its revert check pointing at context the subagent does not have. Every other
keel dispatch has a brief (`plan-review.md`, `subagent-prompts.md`); this one now does, and the body
keeps a short paragraph that links to it.

**The second review found a second hole in the same place.** The five house checks (plan match,
every line traces to the request, tests first, no contradicted decision, a test proved able to fail)
lived only in the body, and `rubric.md` does not contain them: it has no decision-contradiction
check and no tests-first check, and its section 5 is "Reuse and simplification", not the revert
check the prompt called "item 5". So a subagent following the brief would never have run the checks
this skill exists for. They now sit in the brief's prompt, numbered, and leave the body, so there is
one copy and the subagent receives it.

- [x] **Step 3.1: Run the count** Note: counts measured: body 480 words

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w`
Expected: 587, task 2's result. Confirm it before editing. **If task 2 has not landed, this task
stops here**: the budget in "The budget, measured" assumes it.

- [x] **Step 3.2: Write the brief** Note: brief written; four rounds of review

Create `skills/review-code/references/rubric-pass.md` with exactly this content (the fence below is
four backticks because the content contains a three backtick fence):

````markdown
# The rubric pass brief

Dispatch this once per review, after step 2 and before step 4. Model `inherit`, and the dispatch's
description starts `inherit: `. This pass judges whether another agent's work is right, which is the
work least worth making cheaper, and a description with no routing label is ambiguous between
inherited and forgotten. `docs/standards.md`, "A dispatch names its model, and says so", has the
rule.

## Why a dispatch and not a section of the skill

A reviewer that wrote the code, or watched it being written, is anchored on it: it reads what it
meant rather than what is there.
[../../write-plan/references/plan-review.md](../../write-plan/references/plan-review.md) makes the
same argument for plans. No instance of it is on record for code review, so this brief rests on the
argument and not on a measurement. The rubric is also 2,574 words the driver does not need to load,
so the brief hands the subagent a path to it and the driver never reads it.

## What the driver must hand over

A subagent starts cold, so a brief that names none of these makes it guess:

- the diff, as a command with the base resolved, and not "the changes": `git diff <base>...HEAD`
  for committed work, or `git diff <base>` where the change is not committed yet;
- the plan or story path, or the intent you inferred in step 1 where there is none;
- the path to `<docs_root>/standards.md`, and the decisions directory: `artifacts.decisions` in
  `.keel/profile.json`, else `<docs_root>/decisions/`;
- the result of the suite run you made in step 3, quoted, so the reviewer does not run a suite of
  minutes a second time;
- the test command for the revert check: `verify.test_one` from `.keel/profile.json`, else
  `verify.test`;
- the absolute path to `rubric.md`: the path you read this brief from, with `rubric-pass.md`
  replaced by `rubric.md`. A relative path does not resolve from the repository the subagent works
  in.

## The prompt

```
Review a change against this project's own rules. You are not the author and did not watch it being
written: read what is there.

=== CHANGE ===
Diff: <the git diff command, with the base resolved>
Intent: <the plan or story path, or the intent the driver inferred>

=== PROJECT ===
Standards: <path to standards.md>
Decisions: <the decisions directory>
Suite result, run by the driver: <quoted output>
Test command for item 5 below: <verify.test_one, else verify.test>

=== RUBRIC ===
Read <absolute path to rubric.md> in full and answer its checks against the diff. The suite has
already run and its result is above: do not run it again, and a failing or missing suite is itself
a finding.

Also answer these five, which the rubric does not cover. Read the plan, the decisions and the
standards first.

1. Does the diff match the plan? Anything implemented that no task asked for is unplanned scope.
   Anything a task asked for and is absent is an incomplete claim.
2. Does every changed line trace to the request? Adjacent improvements, reformatting and drive-by
   refactoring belong in their own change.
3. Were the tests written first? A test committed after its implementation never ran red, so it is
   unproven until item 5's revert check. Commit order shows this across commits; within one commit,
   only the revert check can.
4. Does it contradict an accepted decision? Look in the decisions directory above, and if it is
   empty look for a decision log before concluding there are none.
5. Has any test in the diff been proved able to fail? A case nobody watched go red is unproven.
   Revert the line it covers, run the test command above, restore it. A suite that cannot fail is
   a finding.

Do item 5's revert in a throwaway worktree, never in the working tree: the author's tree is not
yours to change, and another reviewer may be reading it. Create it with
`git worktree add --detach <path>`, apply the diff there if the change is not committed, and remove
it when you are done. If the test cannot run there, say that the revert check was not done and why;
do not do it in the working tree.

Do not edit the change. Say what is wrong and let the author fix it.

Rank findings: blocking, should fix, consider. Each has a `file:line`, what is wrong, why it matters
and what to do. If nothing blocks, say so in the first line and name what you checked. Cap at
around ten.
```

## Reading the result

The findings go into step 4's ranking as they are. Where the `code-review` plugin also ran, you are
the only one who has seen both sets of findings, so you are the one who spots a conflict. A conflict
is a stated disagreement about a cited line. Where there is one, this pass's finding governs: it has
read the plan, the decisions and the standards, which the plugin's generic reviewers have not. A
clean result here does not clear a plugin finding, because silence is not a conflict.
[../../keel/references/reporting-findings.md](../../keel/references/reporting-findings.md) carries the
reason behind the ranking, cap and first-line rules the prompt above states.
````

Four things in that brief are load bearing and none is decoration. The list under "What the driver
must hand over" is what the first version lacked. The five numbered checks are what the second
version lacked. The throwaway worktree is there because the revert check edits the tree it runs in,
a plugin pass may be reading the same tree, and a worktree holds only what is committed. And the
last paragraph answers open question 7 of the idea record, with the user's decision that both run
and the rubric pass governs a conflict, tightened so that silence is not a conflict: without a precedence rule the skill has
two reviewers and no rule, the shape the delegation check at `tests/validate-skills.sh` exists to
prevent, because a documented relationship nobody honours is worse than an undocumented one.

If `tests/validate-skills.sh` fails the brief for naming `docs/standards.md`, keep the heading name
"A dispatch names its model, and says so" and drop the path. Report which you did.

- [x] **Step 3.3: Edit the body**

Three replacements in `skills/review-code/SKILL.md`, and nothing else.

In step 2, replace `Not installed? Say so once, then do the inline pass:` with:

```markdown
Not installed? Say so once, then go straight to step 3, which is then the whole review:
```

In the quotation that follows it, replace the words `Continuing` and `inline.` at the end of the
last line, which read `Continuing` at a line end and `> inline.` on the next, with `Continuing` and
`> without it.`. The reason: step 3 now dispatches, so "inline" is false, and the fallback must not
describe an inline pass the skill no longer runs.

In step 3, replace everything from the sentence beginning `Read [references/rubric.md]` through the
end of the numbered list of five checks, that is the `Read` sentence, the sentence
`The five that a generic reviewer cannot run:` on the same line, and items 1 to 5, stopping before
`## Step 4:`, with:

```markdown
**Dispatch this pass; do not run it inline.** A reviewer that watched the code being written is
anchored on it. Brief a subagent as [references/rubric-pass.md](references/rubric-pass.md) says,
with model `inherit` and a description starting `inherit: `. Where step 2's plugin ran, both stand:
it is the correctness pass, and this one settles a conflict, having read the plan, the decisions and
the standards.
```

with a blank line after it, before `## Step 4:`. The five checks are not lost: they are items 1 to
5 of the brief's prompt, which is the only copy. The driver does not run them, so the body does not
carry them.

"model `inherit`" is what the validator's `names_model` looks for; "Dispatch" at the start of a bold
run-in and the word "subagent" are what its dispatch detector looks for. Remove any of them and it
either stops seeing the dispatch or fails it. The `inherit: ` label itself is **not** checked by any
script in the repository, which the first dispatch's quality review confirmed by simulation: it is
held by review, which is why it is also in the brief.

- [x] **Step 3.4: Run the applied checks and watch them pass**

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w`
Expected: 480. If it reads 701 or more, stop and report. A number far from 480 means the
replacement took more or less than step 3.3 says, so read the diff before reporting.

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, and the same 10 WARN. **No eleventh WARN naming `review-code`.** That
line appearing is this task's own failure condition. The new relative links in the brief must also
resolve.

- [x] **Step 3.5: Say the same thing in the documents that now contradict the skill**

None of these is pinned by a test, which is why they are listed here rather than left to be noticed.

**`docs/02-skill-catalog.md`.** The `review-code` entry's `**Does:**` line says it "Falls back to an
inline rubric otherwise", which stops being true. Replace that line with:

```markdown
**Does:** delegates to the `code-review` plugin when installed, because its multi-agent
confidence-scored review beats a single inline pass, and dispatches its own rubric pass to a
subagent on `inherit` either way, so that pass is not run by the context that wrote the code. Both
passes stand and the rubric pass settles a conflict. The rubric covers correctness, standards
conformance, test coverage and honesty, error handling, performance, security, simplicity.
```

Do not add a `**Plugin call` lead. This entry has never had one: its leads are `**Trigger:**`,
`**Reads:**`, `**Writes:**` and `**Does:**`, and the `review-code` to `code-review` pair the
delegation floor counts comes from the `review-code` row of `docs/04-plugin-strategy.md`, not from this file.

The same entry's `**Writes:**` line quotes "Say what is wrong. The author fixes it.", the table row
task 2 removed from the skill (found by task 2's quality review; this is the only remaining
occurrence of the phrase). Change the quotation inside that line to the wording now in the skill,
"Do not rewrite it yourself; the author fixes it.", and change nothing else on the line.

**`docs/04-plugin-strategy.md`, the row at line 102.** That row reads
`| \`review-code\` | \`code-review\` | The correctness pass |`. Replace the third column with
`The correctness pass. keel dispatches its own rubric pass beside it, and that pass settles a
conflict`. Leave the first two columns exactly as they are: the delegation check parses them in
backticks and the floor counts the pairs.

**`docs/04-plugin-strategy.md`, the pattern block.** The section "How skills call plugins" says the
pattern is "used identically in every skill that has a plugin dependency" and ends its fenced block
with "Then run the inline rubric." After that block's closing fence, add one paragraph:

```markdown
`review-code` departs from this in one place: its house-specific checks are dispatched to a
subagent rather than run inline, so where the plugin is absent it says so once and goes straight to
that pass.
```

**`docs/standards.md`.** It says "seven delegating skills" at two places, near lines 383 and 417.
`review-code` becomes the eighth: change those two to eight and add `review-code` to the enumeration
at the first. **Do not change "four of the seven" near line 316.** That sentence records the
2026-09-19 closure, when `review-code` did not dispatch, and four skills carrying the clause plus
three that did not is seven; changing it to eight breaks its own arithmetic (found by the first
dispatch's quality review, which the first version of this step got wrong).

Run: `grep -n 'seven delegating' docs/standards.md`
Expected: only the "four of the seven delegating" sentence near line 316, which is left alone on
purpose. `grep -c 'seven delegating skills' docs/standards.md`, the Done-when form, reports 0
because that sentence wraps before "skills".

- [x] **Step 3.6: Repoint the citations this task moves, run the suite, then hand over** Note: shellcheck not installed in the sandbox, not run; quality review findings recorded below the task

The body edit moves the text of `skills/review-code/SKILL.md` and the catalog edit adds one line to
`docs/02-skill-catalog.md`. Repoint exactly these, and read each target before and after:

- `docs/architecture/tiered-multi-harness-claim-inventory.md`, rows 16 and 17 (lines 41 and 42)
  cite the catalog at lines 563 and 572. Each target moved down by one line and each was accurate
  before: change them to `:564` and `:573`. **Row 15 (line 40) is left alone**: it cites line 385,
  which was `**Does:** two scopes.` at HEAD and not the plugin-calls text the row describes, so it
  was wrong before this task and moving it by one would be wrong too. The target text is at `:401`
  now. Report it; it is not this plan's to fix.
- `docs/ideas/independence-of-a-delegated-review.md` cites `skills/review-code/SKILL.md`, line 69, at
  lines 24, 104 and 105 (the last two without the `skills/` prefix), meaning the "Blocking first. If
  nothing blocks, say so in the first line" sentence. Find that sentence's line in the edited file and
  change all three to it; read the line to confirm.
- `docs/prd/coding-standards-enforcement.md`, lines 45, 112 and 168, cites the skill's severity table
  by lines 65 to 67, which the edits move. Replace each with
  `skills/review-code/SKILL.md#Step 4: Rank, and say what blocks`, and read the sentence it sits in
  to confirm the table is what it means.
- `docs/plans/2026-08-31-release-operations-and-claims-audit.md` line 615 cites
  `skills/review-code/SKILL.md` at lines 67 to 68 and, in the same sentence, a bare `:82`. Both were
  stale before this task. Replace the lines 67 to 68 citation with
  `skills/review-code/SKILL.md#Blocking first. If nothing blocks, say so in the first line` and the
  bare `:82` with `skills/review-code/SKILL.md#Do not rewrite it yourself`. Leave the quotation
  alone: that plan records what the file said on 2026-08-31.

- `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md` line 201 cites `skills/review-code/SKILL.md`
  at line 85, meaning the instruction to run `profile.verify.test` yourself, as a skill that already
  names the command. The skill is now shorter than line 85, so the citation points past the end of
  the file, and it was already pointing at a table row before this task. Replace it with
  a citation of the sentence at `skills/review-code/SKILL.md` line 43 at `a678e64`
  (a phrase from the sentence, on one line, with no backticks in it). Leave the rest of the sentence.

Run: `tests/validate-citations.sh`
Expected: `OK`.

Other citations of these files by line number also moved and are not blank, so the checker is silent
on them (for example the older catalog line numbers in `docs/ideas/keel-on-codex.md` and in
`docs/prd/standards-assessment.md`, several of which were already wrong at HEAD). They are reported,
not edited.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
`tests/test-doc-claims.sh` derives counts from the tree and `tests/validate-citations.sh` reads
cited headings, so read both sets of lines specifically: this task edits several documents.

```bash
git add skills/review-code/references/rubric-pass.md skills/review-code/SKILL.md \
        docs/02-skill-catalog.md docs/04-plugin-strategy.md docs/standards.md \
        docs/architecture/tiered-multi-harness-claim-inventory.md \
        docs/ideas/independence-of-a-delegated-review.md docs/prd/coding-standards-enforcement.md \
        docs/plans/2026-08-31-release-operations-and-claims-audit.md \
        docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(review-code): the rubric pass runs outside the context that wrote the code"`.

- [x] **Step 3.7: Make the corrections the quality review of the committed task asked for** Note: spec COMPLIES, quality: nothing blocks; remaining findings recorded in the plan

Steps 3.1 to 3.6 are committed. The spec review complied and the quality review found nothing that
blocks, and it recommended these before merge. Each corrects text this task wrote or left stale.
Make exactly these edits and no others, reading each target first.

1. `skills/review-code/references/rubric-pass.md`, the worktree paragraph of the fenced prompt. It
   says to create the worktree with `git worktree add --detach <path>`, which checks out HEAD and
   so works only where the base is HEAD, and to remove it afterwards, which fails once the revert
   has modified it. Replace the sentences that create, apply and remove with: create it with
   `git worktree add --detach <path> HEAD`, where `<path>` is a new directory under the system temp
   directory; if the change is not committed, apply it there with
   `git diff HEAD | git -C <path> apply`; remove it when done with
   `git worktree remove --force <path>`, because the revert leaves it modified.
2. Same file, the test command. `verify.test_one` in `.keel/profile.json` carries placeholders the
   driver must fill, and the fallback `verify.test` is the whole suite, which the prompt also says
   not to run. Read the `verify.test_one` description in `templates/profile.schema.json` for the
   real placeholder names. Then make the "must hand over" bullet say: `verify.test_one` with its
   placeholders filled for the added test file or case, else `verify.test`. In the prompt, change
   "do not run it again" to say the suite is not run again except by item 5's revert check where
   only `verify.test` exists, and name that cost.
3. Same file, the RUBRIC section of the prompt: add one sentence saying the links in the rubric are
   relative to the rubric's own directory.
4. Same file, "Reading the result". The precedence rule says this pass governs a conflict but not
   what the driver does with the plugin's finding. Add: keep this pass's finding in the ranking and
   list the plugin's beside it, marked overridden and with its location, so the author sees both.
5. `skills/review-code/references/rubric.md`, the section on a suite that cannot fail. It says
   `verify.test` "already ran in SKILL.md step 3" and tells the reader to "revert the line, run the
   file, restore it", which is an in-place revert in a file the dispatched pass reads without the
   skill. Say instead that the suite result is in the brief, and that the revert is done in the
   throwaway worktree the brief describes. Search the file for any other mention of `SKILL.md` or
   of restoring a line, and correct it the same way.
6. `docs/06-repo-layout.md`, the `review-code` tree: add `references/rubric-pass.md` ahead of
   `references/rubric.md`, with the tree glyphs of its neighbours.
7. `docs/04-plugin-strategy.md`, the sentence that says the pattern is "used identically in every
   skill that has a plugin dependency", which the paragraph after the block contradicts. Say that it
   is used in every such skill with one departure, described below.
8. `skills/review-code/SKILL.md`: the sentence "Either way, add the checks in step 3." becomes
   "Either way, run step 3.", and the heading "The passes that only we can do" becomes
   "The pass that only we can do", since step 3 is now one dispatched pass. Do not touch anything
   else in the body.
9. `docs/02-skill-catalog.md`, the paragraph beginning "The house-specific additions the generic
   plugin will not know about": it names three of the five checks. Name all five: the diff matches
   the plan, every changed line traces to the request, the tests were written first, no accepted
   decision is contradicted, and a test has been proved able to fail.

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/review-code/SKILL.md | wc -w`
Expected: 480 or fewer.

Run: `tests/validate-skills.sh && tests/validate-citations.sh`
Expected: `0 FAIL` and no new WARN, then `OK`.

Run: `grep -c 'SKILL.md step 3' skills/review-code/references/rubric.md; grep -c 'used identically' docs/04-plugin-strategy.md; grep -c 'rubric-pass.md' docs/06-repo-layout.md`
Expected: 0, 0, then 1 or more.

Run: `tests/run-tests.sh > /tmp/keel-run-tests.log 2>&1; tail -5 /tmp/keel-run-tests.log`
Expected: PASS, or reds this step did not cause. It takes about 2m30s: run it alone.

```bash
git add skills/review-code/references/rubric-pass.md skills/review-code/references/rubric.md \
        skills/review-code/SKILL.md docs/02-skill-catalog.md docs/04-plugin-strategy.md \
        docs/06-repo-layout.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "fix(review-code): the rubric pass brief runs from a cold start"`.

---

### Task 4: the `remediation` rule binds at ship

**Story:** none. Test: the applied check, per the section above.
**Files:**
- Modify: `skills/review-code/references/rubric.md`

**Interfaces:**
- Consumes: `skills/coding-standards/references/observability.md`, "Error logs that trigger the
  right remediation", whose heading is at `:104`
- Produces: rubric section 4e

**Depends on:** none

**Done when:** `tests/validate-skills.sh` exits 0 with `0 FAIL`, and
`grep -c 'remediation' skills/review-code/references/rubric.md` reports at least 1 where it reports
0 today.

- [x] **Step 4.1: Confirm the gap, then write the row**

Run: `grep -rn remediation skills/review-code/`
Expected: no output. That is the gap: the rule lives only at
`skills/coding-standards/references/observability.md:104-128`, so it binds only if that reference
happens to be in context when the logging call is written, which a delegated implementer's is not.

Then add a new conditional section to `skills/review-code/references/rubric.md`, after section 4d
(`:155`) and before section 5 (`:185`), following the pattern 4b, 4c and 4d already set of a section
scoped by what the diff touches:

```markdown
## 4e. Error logs, where the diff adds or changes one

- An error-level log with no `remediation` field, so whoever is paged learns what broke and not what
  to do about it. See `observability.md`, "Error logs that trigger the right remediation."
```

One row, and the section exists to give it a trigger condition rather than firing on every diff.
`docs/prd/coding-standards-enforcement.md` names five more mechanically-shaped rules alongside this
one; it scoped all six out of **config-shaped** enforcement, a compiler flag or a CI step, and a
rubric row is review-shaped, so this reverses nothing and the other five follow only if they earn
it.

What makes this row bind is elsewhere and already shipped: since 0.22.0 `gates.coding_standards`
defaults to `required`, and a `Should fix` finding citing a file under
`skills/coding-standards/references/` counts as a standards violation at `ship`'s gate item 4.

- [x] **Step 4.2: Run the applied checks and watch them pass**

Run: `grep -c remediation skills/review-code/references/rubric.md`
Expected: 1 or more.

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, the same 10 WARN. The `observability.md` citation is a bare filename in
the rubric's established style, matching `async-work.md` and `api-contracts.md` in the sections
above, so it is not a relative link and the link rule does not apply to it.

Run: `tests/validate-citations.sh`
Expected: `OK`. This is the check that reads a cited heading. The rubric's style quotes a heading's
opening clause with a trailing period and the checker tolerates that, as
`skills/review-code/references/rubric.md:172` already does, so a heading quoted wrongly fails here
rather than silently pointing at nothing.

- [x] **Step 4.3: Run the suite at the unit boundary, then hand over** Note: 21 of 22 suite jobs pass; tests/test-keel.sh (does not read the changed file) cannot finish inside the 120 s tool limit here, so it was not seen; shellcheck absent

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

```bash
git add skills/review-code/references/rubric.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(review-code): an error log with no remediation field is a standards finding"`.

---

### Task 5: the records say what happened, including what was not measured

**Story:** none. Test: the applied check, per the section above.
**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/ideas/independence-of-a-delegated-review.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: the four tasks above
- Produces: nothing

**Depends on:** tasks 1, 2, 3 and 4

**Done when:** `tests/test-doc-claims.sh` passes, and `tests/run-tests.sh` is green.

- [x] **Step 5.1: Write the Unreleased entries**

Four bullets under `## Unreleased` in `CHANGELOG.md`, each naming its reason and, where it has one,
its measurement. Three things must appear and are easy to leave out:

- **`agents/` was unchecked, and the proof is a mutation, not an argument.** Name the date and what
  was done: an em dash appended to `agents/keel-fanout.md` on 2026-10-12 gave 0 FAIL.
- **Task 3 fixes no measured defect.** Nothing on record shows a review passing work because it ran
  in the authoring context. Say that the change buys independence and a counted context saving, and
  do not let the entry imply a defect was found. The deviation section above is the source.
- **The word counts, 645 to 587 to 480 against the 700 target**, and that the five house checks
  moved from the `review-code` body into the brief's prompt. Do not say task 2 was needed to fit
  task 3: it was, in the first design, and is not in the one that shipped.
- **The `inherit: ` label on a dispatch is held by review and by the brief, not by a script.** Task
  3's quality review confirmed by simulation that `tests/validate-skills.sh` checks that a model is
  named and never the label, in this skill or any other. Record it as a known gap with this reason,
  and do not claim a new check.
- **`skills/review-code/references/rubric-pass.md` is new**, and `skills/keel/references/
  reporting-findings.md` is new. Name both.

- [x] **Step 5.2: Close the idea record** Note: plan-review.md:76 was still correct; subagent-prompts cited at two places, not three; stale findings rows in the dated record left, with a Next-row note

In `docs/ideas/independence-of-a-delegated-review.md`, set Status to `built`, dated, and add a line
to each of the four changes in the Recommendation section naming the task that landed it. Leave open
questions 1 to 4 open and leave the park in `standards-that-bind.md` in place: this plan builds none
of the profile work, and a record that reads as finished would lose the two questions a revisit
depends on.

Also correct the record's two citations of `tests/validate-skills.sh` near line 409, which is a
comment about the cheatsheet. The delegation check it means, and its floor, have both moved since
this plan was written, because task 1 inserted about 50 lines above them: find them in the file
(search for `delegation_pairs`) and cite what you find, not the numbers this plan used before
task 1 landed.

Also the record's statement, near its line 31, that `review-code` "dispatches nothing" is true of the
tree it was written against and false after task 3: reword it to say what the skill did before and
does now.

And in `skills/write-docs/references/claims-audit.md`, lines 12 to 13 say `review-code` "already
sets the shape for a single location: never a finding without a location, and never a location
without a reason". That sentence now lives only as a heading in
`skills/keel/references/reporting-findings.md`. Reword it to cite that file, as task 2 did for the
cap at line 104 of the same file (found by task 2's quality review; task 2 missed it).

And correct what task 2 moved: the record's `plan-review.md:76` (now `:79`) and
`subagent-prompts.md:198` (now `:201`, cited at three places), found by the first dispatch of
task 2. Re-derive each from the file rather than adding three, since task 4 and this task also
insert text above some of them. The `review-code/SKILL.md:69` citations were repointed by
task 3, which is why they are not listed here.

- [x] **Step 5.3: Check the README's claims** Note: README read, no change needed

`README.md` names the skill count and describes the hooks and agents. Nothing in this plan changes
the skill count or adds an agent, so the likely edit is none. Read it, and say in your report that
you read it and what you changed, rather than skipping it silently.

Run: `tests/test-doc-claims.sh`
Expected: PASS. This is the check that fails on a count the tree contradicts.

- [x] **Step 5.4: Run the suite at the unit boundary, then hand over** Note: all suite jobs but tests/test-keel.sh ran and passed; that file reads nothing this plan touched and cannot finish inside the 120 s tool limit; shellcheck absent

Run: `tests/run-tests.sh`
Expected: PASS, `All test files passed`.

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, 10 WARN, unchanged from the start of the plan.

```bash
git add CHANGELOG.md docs/ideas/independence-of-a-delegated-review.md README.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: record the delegated-review changes, and what they did not measure"`.

---

## What the quality reviews of task 3 left open

Task 3 took five dispatches and two correction rounds. Both quality reviews of the committed text
found nothing that blocks and found more in the same brief each time, so the work stopped here and
these are carried forward, not fixed. They are all in
`skills/review-code/references/rubric-pass.md` unless a file is named.

| Finding | Why it was not fixed in this plan |
|---|---|
| The apply step drops untracked files and fails on a modified binary (`git diff --binary HEAD` and a copy of untracked files would fix it) | Each reproduced; a fix wants one more reviewed round on the brief |
| The "only `verify.test` exists" exception cannot be followed: the subagent receives a command string, not the profile key name; "a failing suite is a finding" then reads against an expected red | Needs the template and the placeholder meanings handed over |
| The reason given for `--force` is wrong: a plain remove refuses after the apply alone | Wording only; the command is right |
| A fresh worktree has no installed dependencies, so the revert check will often be reported as not done | Needs a decision: symlink, install, or accept |
| `rubric.md` leftovers: the "Ran the suite (83 passing)" example, "the brief" never named in the prompt, "Ask for the count" with nobody to ask, and the recipe it links is an in-place revert | Self-containment of the rubric is a larger edit |
| The figure "2,574 words" is now 2,596; the overridden plugin finding's effect on "what blocks" and the cap is unstated; two concurrent reviewers could pick colliding paths (`mktemp -d`) | Small; nothing depends on them |
| `docs/standards.md` says subagent briefs stay in the skill body and this one is in a reference | Resolved after the plan's code review: the standard now allows a brief in a reference when the dispatching step says to read it and the body names the checks it carries, and `review-code` step 3 does both |

The brief rests on an argument and not on a measurement (the plan says so in the brief itself), and
the first real use of the dispatched pass is the test of every row above.

Task 4's quality review (nothing blocks) left these on the one row the plan prescribed, which binds at
the ship gate because it cites a file under `skills/coding-standards/references/`:

| Finding | Why it was not fixed in this plan |
|---|---|
| The row checks that `remediation` is present, but `observability.md` also asks that it name a skill and be a fixed string per error site, so `remediation="see logs"` passes | The plan scoped one row on purpose; widening it changes what the gate flags |
| An expected validation failure logged at `error` is a level finding under `observability.md`, but the row would ask for a remediation hint on it | Same |
| "Adds or changes one" could be read to flag a legacy log the diff only reformats | Same |
| `observability.md` also says to log an exception once at the boundary and never log and rethrow; the rubric has no row for it | The other rules follow only if they earn it |


---

## Departures the code review found

- **The changelog entries for tasks 1 to 4 landed in task 5's commit**, `5137667`, not with each
  change, as the global constraints above and `docs/standards.md` require. Task 5 was scheduled that
  way, so this plan contradicted its own constraint. The history is left as it is: the branch
  merges as one pull request, which carries the entries and the changes together. Every commit made
  after the review carries its own entry.
- **`.gitignore` gained `scratchpad/`** in `c974693`, which no task asked for. That folder holds the
  five subagent samples the idea record started from, and they are not keel's to ship.

---

## Tasks run sequentially, and that is a decision

Tasks 1, 2 and 4 all say `Depends on: none` and their `Files` blocks are disjoint, which is the
necessary condition for a concurrent batch. **They are still declared sequential.**

Each is a few minutes of text or shell editing. A batch costs a worktree per task, a join, and a
batch gate, and `plan-template.md`'s three further rules apply to every member. For three short
tasks the overhead exceeds the saving, and the template is explicit that a plan earns concurrency by
declaring it rather than by being eligible. Task 3 depends on task 2 for its word budget and task 5
depends on all four, so two of the five could never be batched anyway.

## Self-review

Run against `plan-template.md`'s seven checks on 2026-10-12, then re-run after the review's findings
were applied.

1. **Every story maps to a task.** Not applicable: there are no stories, and the deviation is named
   with its precedent. Every one of the idea record's four changes maps to a task: 1, 2 and 3, and 4.
   The record's one remaining assignment, the agent-description-budget question, is decided in step
   1.3 rather than left silent.
2. **No placeholder phrases.** None. Every file is named, every command is from the profile or is
   investigative, and the text each task writes is given verbatim, including all three documents in
   step 3.4.
3. **Names match across tasks.** `skills/keel/references/reporting-findings.md` is spelled the same
   in task 2's Files block, its creation step, the three citing steps, and task 3's Interfaces.
4. **Verifying commands come from `profile.verify`.** `tests/run-tests.sh` is `verify.test`;
   `tests/test-validate-skills.sh`, `tests/test-doc-claims.sh` and the rest are `verify.test_one`
   with `{name}` substituted. `tests/validate-skills.sh` and `tests/validate-citations.sh` are run
   directly as well as by the suite, which is how `CONTRIBUTING.md` says to use them. `verify.lint`
   is run in step 1.5 and its absence on this machine is named rather than assumed. `awk`, `grep`
   and `git status` are investigative and need no entry.
5. **Every task ends with a hand-over that stages named paths and names the commit.** All five do.
   No task commits: no batch is declared.
6. **No task depends on a file no task creates.** Task 3 consumes the reference task 2 creates and
   declares the dependency.
7. **Step ids are unique and open with `Step <task>.<step>:`.** 24 steps across five tasks, 1.1 to
   5.4, counted by `keel plan status` as 5, 7, 5, 3 and 4. Confirm with
   `keel plan status docs/plans/2026-10-12-independence-of-a-delegated-review.md` before the first
   dispatch; a non-zero exit means the plan is unaddressable and must be read and ticked by hand.

## Open questions

None blocking. The four that remain open are in the idea record, not here: whether a named instance
of a review passing its own work exists, what `inherit` maps to on Codex, whether `review-code`
should keep an inline path for an interactive review, and how a profile's label would carry its
tier. **None of them blocks any task in this plan**, because this plan builds no profile and task 3
uses the `inherit` label convention already shipped rather than introducing one.
