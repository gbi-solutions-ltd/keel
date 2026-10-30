# Idea: the independence of a delegated review

| | |
|---|---|
| Raised by | Bernard, 2026-10-12, bringing five subagent files found online and asking whether keel needs them |
| Status | **built 2026-10-12**, via `docs/plans/2026-10-12-independence-of-a-delegated-review.md`, for the smaller build below. Open questions 1 to 4 stay open and the profile work stays parked: that plan built none of it. Open questions 5 to 7 answered by Bernard, 2026-10-12 |
| Recommendation | Build something smaller: four cheap changes, two of which are already-shipped conventions applied consistently. Decline the five role agents. Park a second delegation profile on open questions 1 and 2, and the writing profile in `standards-that-bind.md` |
| Next | Built. The sections below describe the tree before the build; the Landed lines in the Recommendation say what changed. The first real use of the dispatched rubric pass is its test |

## The problem

Whether a keel review is independent of the context that produced the work depends on the invoking
skill choosing to dispatch and on each brief restating the rules that make a review trustworthy, and
nothing checks either, so the guarantee a user gets varies by which skill they happened to invoke.

**Evidence.** The structural gap is verified three ways and the harm from it is not named.

- **Verified 2026-10-12 by mutation.** `agents/` is outside every content rule that governs
  `skills/`. The content loop is `find skills templates output-styles`
  (`tests/validate-skills.sh:207`); `docs/` has its own; `agents/` is in neither. An em dash was
  appended to `agents/keel-fanout.md`, the validator was run, and it reported 0 FAIL. The file was
  restored.
- **Verified by reading.** The rules are restated across three and four files respectively. "If
  nothing blocks, say so in the first line" appears in
  `skills/review-code/SKILL.md#If nothing blocks`, `skills/write-plan/references/plan-review.md:74`
  and `skills/execute-plan/references/subagent-prompts.md`. The cite-a-location rule appears in
  those first two, in `skills/shape-idea/SKILL.md:42`, and twice in `agents/keel-fanout.md`.
- **Verified by reading.** `write-plan` dispatches a reviewer (`SKILL.md#Then dispatch a reviewer`)
  whose brief forbids the authoring context (`plan-review.md:83`), and `execute-plan` dispatches two
  (`skills/execute-plan/references/subagent-prompts.md#Dispatch implementation and both reviews`).
  `review-code` carries `Agent` in its `allowed-tools` (`:4`). Before task 3 it dispatched nothing:
  step 2 offered an external plugin and fell back to an inline pass. Since task 3 it dispatches its
  rubric pass in step 3, briefed by `skills/review-code/references/rubric-pass.md`.
- **Not found.** No named instance of a review passing something because it ran in the context that
  produced the work. Nothing in `tests/evals/results.md` or under `docs/audits/` records one.

So the one symptom with verified harm potential is the unchecked directory, and it is latent only
because a single agent file exists today.

## What was asked for

> i am curious how we can leverage hooks and defined subagents to enhance keel functionality. the
> folder `scratchpad` holds samples of subagent files i obtained from research online. is this
> something the plugin may need?

> what if the current code review skill actually executed as a subagent so it executes outside the
> existing context

> what do you think about this sample agent scratchpad/skeptic.md whose intended purpose is
> reviewing plans/designs ahead of execution? it be re-written with appropriate prose so it clearly
> executes as expected. assume that we can be in a scenario where a plan gets written and a subagent
> reviews the plan outside the main session context

The five files are `bug-hunter`, `builder`, `code-reviewer`, `docs-scout` and `skeptic`, in
`scratchpad/` (gitignored).

## The case against

**Strongest argument for not building this at all.** Most of what was asked for already ships, and
the part that does not has no named failure behind it. `write-plan` step 5 already dispatches a plan
reviewer whose brief says in its own words "Do not dispatch this to the same context that wrote the
plan", which is precisely the scenario the `skeptic` file was brought in to cover.
`execute-plan` already dispatches two review passes at `inherit`. The single skill that does not
delegate, `review-code`, can be brought in line by one paragraph using the dispatch convention
already shipped in two other skills, with no new file, no Codex mapping and no change to the label
rule. Everything beyond that is machinery for a problem nobody has reported, and keel has a standing
answer for that shape: `docs/ideas/lint-after-each-edit.md` was declined on exactly these terms, and
`ADR-0007` was rejected with "the laundering risk is unmeasured, not cleared".

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | Leaves one verified gap open: a second agent file could land carrying an em dash, an unbounded body, a vendor model alias or a broken link, and the suite would pass. That is cheap to close and should not wait on anything else |
| Do it manually | The maintainer reviews each agent file by eye, and each skill author remembers to restate the review rules | It is the state today, and it is the state the five-way restatement already describes. Review by eye is what the validator exists to replace |
| Buy it | Nothing available | The nearest thing is the `code-review` plugin, which `review-code` step 2 already delegates to and which `docs/01-architecture.md` already records. It is a generic reviewer: step 3 exists because it cannot run this project's five checks |
| Build something smaller | Four changes, below | The recommendation |

**Variants of building it**

| Variant | Note |
|---|---|
| A judging delegation profile, `agents/keel-adjudicate.md` at `model: inherit`, named by `write-plan`, `review-code` and both `execute-plan` passes | Drafted at `scratchpad/keel-adjudicate.md`. Blocked on open questions 1 and 2, and weakened by the assumption below that turned out false |
| One shared reference holding the review rules, linked from the three briefs | Deduplicates without touching `agents/`, the label rule or the Codex mapping. The cheapest form of the deduplication argument |
| `review-code` dispatches its rubric pass, using the shipped `inherit` convention and no new file | Answers the question actually asked, with nothing new to validate or map |
| `agents/` brought inside the validator's content loop | The verified gap. Independent of every other variant |
| The five role agents as found | Declined. See the findings table |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| An agent file's always-in-the-prompt property is what a judging dispatch needs | The brief is assembled by selection, so a rule can be omitted by the dispatcher | Compare the two brief shapes | **Checked, and false for judging.** `plan-review.md`'s prompt is a fixed template, so the rules can simply sit inside it. Selection is the failure mode of the *implementer* brief, whose `=== PROJECT STANDARDS ===` block tells the dispatcher to paste "the rules from standards.md this task could breach" |
| Naming a profile keeps the dispatch's tier visible | A reader of `Agent(<profile>: task)` can tell which model ran | Read `docs/standards.md#A dispatch names its model, and says so` against the rendered label | **Checked, and partly false both ways.** `keel-fanout: ` already requires a lookup, so the indirection exists today; but `inherit: ` is self-documenting and a named inherit profile would lose that. See open question 4 |
| Codex can express an inherit profile | `lib/harness/codex.sh` has something to write that is not a named model | Read the writer | **Checked, and nothing says it can.** `codex.sh:86` writes `.codex/agents/keel-fanout.toml` with `model = "gpt-5-codex-mini"`. There is no inherit token to emit, so an inherit profile is either dark there or silently pinned, which is a different guarantee |
| Delegating `review-code` saves driver context | The reviewer reads `references/rubric.md` itself rather than receiving it pasted | Measure the dispatch | Not checked. The rubric is 2,574 words, so the saving is real if read and zero if pasted. This is a brief-wording risk, not a design risk |
| Independence has actually failed in practice | A run is on record that passed work because it reviewed its own | `tests/evals/results.md`, `docs/audits/` | **Checked, and none is recorded.** This is what parks the profile work |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The plan-review scenario asked for is shipped | `skills/write-plan/SKILL.md#Then dispatch a reviewer`, brief at `references/plan-review.md`, model `inherit` | `skeptic` duplicates a working mechanism |
| That brief exists because of a measured run, and its finding is the one `skeptic` omits | `plan-review.md`: a run given four self-review items over a flawed plan passed all four and found the central defect only because it opened a source file unprompted | A reviewer not told to read the repository is the reviewer that failed. `skeptic` never says to, and its `tools:` line omits Bash |
| `skeptic` inverts a rule stated in three places | "Do not praise the plan" against `skills/review-code/SKILL.md#If nothing blocks, say so in the first line`, `plan-review.md:74`, `subagent-prompts.md` | A reviewer forbidden from approving invents findings. `review-code` step 4 requires saying when nothing blocks and naming what was checked |
| `skeptic` caps findings at five | Against `skills/review-code/SKILL.md#If nothing blocks, say so in the first line` and the cap-at-ten rule, which treats exceeding it as the finding | A cap drops the sixth finding with no signal |
| Three of the five files name a vendor model alias | `code-reviewer: opus`, `builder: sonnet`, `docs-scout: haiku` | `docs/standards.md#A dispatch names its model, and says so` puts judging and gated writing on `inherit`, and the validator has failed a vendor alias in a skill body since 2026-09-06. `agents/` is unchecked, so these would enter through the one directory the rule does not reach |
| Each role file duplicates a stronger skill | `code-reviewer` against `review-code` plus a 2,574 word rubric; `bug-hunter` against `debug`; `builder` against the implementer brief; `skeptic` against `plan-review.md`; `docs-scout` against `keel-fanout` | A role agent does not load the skill it is named after, so it would review against four lines instead of the rubric. That is the false-delegation-map class that the delegation check, `tests/validate-skills.sh#Every documented delegation must be one the skill actually makes`, exists to prevent, and its floor is `tests/validate-skills.sh#"$delegation_pairs" -ge 8` |
| keel already separates profile from role, and the Codex path depends on it | `agents/keel-fanout.md` carries how to read and nothing about what to look for; `lib/harness/codex.sh` (deleted after v0.26.0) maps the profile name to a model | A role agent with a hardcoded model breaks the portability the profile abstraction buys |
| `review-code` is provisioned to dispatch and does not | `allowed-tools` includes `Agent` (`:4`); no step dispatches | The smallest real change in this record, and it needs no new machinery |
| Body budgets permit the small build and not much more | `review-code` 645 words, `write-plan` 761, `execute-plan` 889, `shape-idea` 672 | A paragraph fits in `review-code`. `execute-plan` is 11 words from the ceiling and cannot take one |
| Hooks are not where this gap lives | `hooks/hooks.json` registers six events; `PostToolUse` was declined 2026-09-27 on measured grounds (12.3s against a 10s timeout, no `lint_one`, no capability row) | Nothing in this idea needs a new hook, and `SubagentStop` already fires `done-guard` |
| The `remediation` rule is in no rubric, so it sits at level 4 only | `grep -rn remediation skills/review-code/` returns nothing; the rule lives at `skills/coding-standards/references/observability.md:104-128` | It binds only if that reference is in context when the logging call is written, which a delegated implementer's is not. Question 6 settles it |

## Open questions

1. **Is there a named instance of a review passing something because it ran in the authoring
   context?** This is the blocking question for any new profile. Nothing on record has one, and
   without one the profile work is machinery ahead of evidence, which is how `lint-after-each-edit`
   and `ADR-0007` were both answered.
2. **What does `inherit` map to on Codex?** Any inherit profile needs an answer before it ships, and
   a `docs/harness-support.md` row either way, per ADR-0004.
3. **Should `review-code` always delegate, or keep an inline path?** A review the user wants to
   interrogate turn by turn is worse delegated. ADR-0002 made delegation the default for execution;
   extending it to a directly invoked review is its own decision.
4. **If a profile ever lands, does its label lead with the profile or the tier?** `keel-adjudicate: `
   loses the self-documentation that `inherit: ` has today, and `keel-adjudicate (inherit): ` costs
   characters in the pane where truncation matters most.

Questions 5 to 7 were surfaced as choices and answered by Bernard on 2026-10-12, per
[../../skills/keel/references/asking-questions.md](../../skills/keel/references/asking-questions.md):
the section is the record, the prompt is how it gets answered. They are kept here rather than
deleted so each decision keeps its trace.

5. ~~Where does the writing profile question go, given that the selection failure mode is real only
   for the implementer brief?~~ **Answered: parked in `standards-that-bind.md`**, and recorded there
   under a dated finding rather than only here. Revisit on a named instance of a delegated
   implementer omitting a standard the dispatcher did not paste. This is the answer
   `lint-after-each-edit.md` and `ADR-0007` both got, and the reason is the same: no instance is on
   record, and the mechanism would arrive ahead of its evidence.
6. ~~Should the `remediation` rule gain a line in `review-code`'s rubric, or wait for the enforcement
   PRD's set of six, or wait for a typed logger?~~ **Answered: add the rubric line, in this build.**
   `docs/prd/coding-standards-enforcement.md` scoped those six out of **config-shaped** enforcement,
   a compiler flag or a CI step, and a rubric line is review-shaped, so this reverses nothing. Since
   0.22.0 `gates.coding_standards` defaults to `required` and a `Should fix` finding citing a
   `coding-standards` reference blocks at ship, so one line in an unbounded reference turns prose
   into something that stops a change. The typed logger stays the level 1 answer and is not
   displaced; the other five follow if they earn it.
7. ~~When `review-code` dispatches its own pass, how does it relate to the `code-review` plugin's
   pass that step 2 already delegates to?~~ **Answered: both run, and keel's governs on a conflict.**
   They answer different questions, which step 3 already states as "A generic reviewer does not know
   this project's intent", and keel's pass read the plan, the ADRs and the standards. The build
   states the precedence rather than leaving two reviewers and no rule, which is the shape
   the delegation check in `tests/validate-skills.sh#Every documented delegation must be one the skill actually makes`
   exists to prevent.

## Recommendation

**Build something smaller.** Four changes, in this order, none depending on the next.

1. **Bring `agents/` inside the validator's content loop.** The only verified gap, mechanical, and
   independent of everything else here. It carries a floor, so a walk that reads no agent file
   reports that rather than passing, and it is pinned in both directions.
   **Landed:** task 1, `a7a72d3`.
2. **`review-code` dispatches its rubric pass at `inherit`**, labelled `inherit: ` per the
   convention `write-plan:95` and
   `skills/execute-plan/references/subagent-prompts.md#Dispatch implementation and both reviews` already use, with the reviewer reading
   `references/rubric.md` itself rather than receiving 2,574 words pasted. Per question 7 the step
   also states the precedence: the `code-review` plugin is the correctness pass where it is
   installed, keel's dispatch is the project-specific pass, both run, and a keel finding governs on
   a conflict because it read the plan, the ADRs and the standards.
   **Landed:** task 3, `2b7453e` and `928a03d`.
3. **One reference holds the review rules** that are restated in three and four places, linked from
   `review-code`, `plan-review.md` and `subagent-prompts.md`. References are unbounded, so this is
   a deduplication rather than a relocation, which is how `write-plan`'s self-review was handled.
   **Landed:** task 2, `029db73`.
4. **A rubric line for the `remediation` rule**, per question 6. One line, no body words, no eval
   arm, and under a `required` standards gate it blocks at ship.
   **Landed:** task 4, `a4ab8e2`.

**Decline the five role agents.** Each duplicates a skill it would then review against four lines
of prose instead of that skill's rubric or brief, and three carry a vendor model alias into the one
directory no rule checks.

**Park a second delegation profile** on open questions 1 and 2. The assumption that justified it,
that an agent file is needed because a brief can omit a rule, is false for judging: those briefs are
fixed templates. It remains true for the implementer brief, which is parked in
`standards-that-bind.md` per question 5. The draft stays at `scratchpad/keel-adjudicate.md` rather
than being deleted, so a later revisit starts from it.

## Not decided here

**The wording of any dispatch brief**, including how change 2 tells the reviewer to read the rubric
rather than receive it, and how change 3's shared reference is phrased so none of the three briefs
loses a rule in the move. That is `write-prd` and `write-plan` territory, and it is craft rather
than a decision, so it is not surfaced as a choice.

**Whether change 1's rule should also bound an agent description's length or count it against the
1,320 token description budget.** The skills' own budget is enforced at
`tests/validate-skills.sh`; whether an agent description belongs in the same total is a measurement
nobody has taken, and taking it is part of change 1 rather than a prior decision.

Three items that stood here on 2026-10-12 moved to open questions 5 to 7 and were answered. The
writing profile is parked in `standards-that-bind.md` rather than undecided; the `remediation`
rubric line is in the build; the reviewer precedence rule is stated in change 2.
