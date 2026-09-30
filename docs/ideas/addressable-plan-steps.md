# Idea: plan steps with their own ids, and a command to read and tick them

| | |
|---|---|
| Raised by | The maintainer, in conversation, 2026-09-28 |
| Status | agreed 2026-09-28 |
| Recommendation | Build it: step ids in the plan template, then `keel plan status` and `keel plan tick`, for new plans only |
| Next | `write-prd`: drafted as `docs/prd/addressable-plan-steps.md`, approved |

## The problem

The coordinator running a plan ticks its checkboxes by editing a markdown file where every step
label repeats once per task, so each tick needs surrounding text to hit the right line, and after a
compaction the only way to learn where a plan stands is to reread it, which for this repository's
plans means 10,000 to 35,000 words. This happens on every tick of every plan.

**Evidence.**

- `docs/plans/2026-09-27-push-scan-reads-pushed-commits.md` holds 30 checkboxes, and each of its five
  step labels ("Step 2: Run it and watch it fail" and the rest) appears six times word for word.
- Commit `5621b9e` (2026-09-01): two completed boxes in the release-operations plan were missed and
  needed their own commit. The same commit notes eight boxes left unticked on purpose, each carrying
  an instruction not to tick it.
- `skills/execute-plan/references/parallel-batches.md:101` requires batch ticks to be made serially,
  because two near-simultaneous edits to the plan file drop one task's ticks through a stale read.

## What was asked for

"Consider using xml or json for the implementation plans to allow ease of parsing the file and
updating done items." Narrowed the same day: the only readers are the model and keel's own
commands, so markdown stays and each step gets a unique id. The maintainer also asked for
`keel plan status` and `keel plan tick`.

## The case against

**Strongest argument for not building this at all.** The model already ticks boxes correctly almost
every time, and the one missed tick on record was caught and fixed by an ordinary commit. The ids
alone are a template change with no code to maintain, and they remove the ambiguity that makes a tick
edit fragile. The two commands add a CLI surface that must run on bash 3.2, be tested, and stay in
step with the template, to replace an edit the model can already make. Whatever the commands add
beyond the ids is convenience, not correctness.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Tick edits stay fragile; progress after compaction means rereading the plan | The cost is paid on every plan |
| Do it manually | A `grep -n '^- \[ \]'` gives unticked lines today | It cannot say which task a line belongs to, since labels repeat |
| Buy it | Not applicable: nothing external reads keel's plan format | |
| Build something smaller | Ids in the template only, no commands | Fixes addressing, but `ship` and the coordinator still read by eye |

Variants of the idea:

| Variant | Difference |
|---|---|
| XML plans | Rejected: plans are mostly shell and test code, whose `<`, `>` and `&` break a strict parser unless every block is wrapped, and one missed wrap loses the parsing the format was chosen for |
| JSON plans | Rejected: every line of code becomes an escaped string, unreadable in review |
| Markdown plan plus a JSON status file beside it | Rejected: two sources of truth, and ticks leave the pull request diff |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A step has more states than ticked and unticked | Plans already carry boxes deliberately left open | Commit `5621b9e`'s eight boxes; tasks marked deferred at their headings in commit `7208f6a` | Yes, both exist |
| A tick carries a note as often as not | Unwitnessed steps must be noted beside their box | `skills/execute-plan/SKILL.md` Step 4 | Yes, the rule exists |
| Only keel's commands and the model read plans | No other tool parses them | Nothing in `bin/`, `lib/` or `hooks/` reads a plan today; the maintainer confirmed no outside reader | Yes |
| Old plans can be left as they are | No command needs to read a plan without ids | The commands report such a plan as unaddressable rather than guess | Decided by the maintainer, 2026-09-28: report it |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| No code parses a plan; the validator checks only the template's `**Done when:**` marker | `tests/validate-skills.sh`, the block before the router check | The commands would be the first plan reader, so the format they read is theirs to define |
| 31 plans, 329,000 words; the largest about 35,000 | `wc -w docs/plans/*.md`, 2026-09-28 | Rereading a plan to find progress is the expensive part |
| `ship` refuses unticked boxes unless deferred out loud | `skills/ship/SKILL.md` step 7 | A mechanical check has a consumer waiting for it |
| The coordinator ticks after both reviews pass, with a note for anything unwitnessed | `skills/execute-plan/references/subagent-prompts.md#After both passes, with pass one at COMPLIES` | `tick` has to carry a note, not only flip a box |
| `execute-plan` Step 4's tick sentence is pinned word for word | `tests/test-eval-harness.sh:480` | Changing that sentence to name the command moves the pin |
| The plan template is the one place the step format is stated | `skills/write-plan/references/plan-template.md` | The id format lands there and nowhere else |

## Open questions

1. *Answered 2026-09-28, by the maintainer.* On a plan without ids, `status` and `tick` report it as
   unaddressable rather than refusing silently or guessing. Now FR-11 in `docs/prd/addressable-plan-steps.md`.
2. *Answered 2026-09-28, by the maintainer.* Both. Beyond ticked and unticked, a step can be deferred
   or not applicable, and each carries a reason. `ship` accepts either when its reason is present. Now FR-03, FR-04 and FR-15 in
   `docs/prd/addressable-plan-steps.md`.

## Recommendation

Build it: ids in the plan template for new plans, then `keel plan status` and `keel plan tick`,
with `tick` writing the note the rules already require. The ids fix addressing on their own; the
commands make progress readable without a reread and give `ship` a check. Next is `write-prd`.

## Not decided here

The id syntax, the commands' flags and output, whether `ship` and `execute-plan` call the commands
or only mention them, and whether the batch race is closed by locking. Those belong to `write-prd`
and `design-architecture`.
