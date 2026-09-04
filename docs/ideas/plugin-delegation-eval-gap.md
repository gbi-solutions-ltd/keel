# Idea: no eval arm can test a delegation with the plugin present

| | |
|---|---|
| Raised by | Bernard, 2026-09-02, from the review of `f6bb41a` |
| Status | **recorded, not planned.** A known limit written down so the next reader does not mistake the delegation check for a functional guarantee |
| Recommendation | Do not fix the harness now. The check that shipped is worth having on its own terms, and this is the sentence that stops it being over-read |
| Next | nothing. Revisit when a runner mode that can load a plugin is wanted for some other reason |

## The problem

`tests/validate-skills.sh` now fails when a documented delegation is not one the skill makes, and
every row of `docs/04-plugin-strategy.md`'s wiring map names a plugin its skill's body names. Two
properties follow and they are worth stating separately, because the gap sits between them.

**Guaranteed:** the table matches the tree, and every skill degrades correctly when the plugin is
absent. The absent path is the one an eval arm runs, so it is the one that gets measured.

**Not tested anywhere:** that any delegation works when the plugin is present. Not one arm has ever
exercised an installed branch, for any skill, since the first conditional was written.

The check enforces honest documentation. It does not enforce function, and the distance between
those is the whole of this record.

## Why no arm can reach it

`tests/evals/README.md` fixes the flags, and two of them are load bearing for the reason it gives:

```
--setting-sources "" --disable-slash-commands
```

They exist so a baseline arm is a baseline, rather than running with the very skills the scenario
measures. The treatment arm takes the same two flags so both arms are comparable, and the treatment
gets its skills from the prompt text instead.

The side effect is total. `--setting-sources ""` means no settings file is read, so no plugin is
enabled, so `CLAUDE_PLUGIN_ROOT` is never set for any plugin and no plugin's skills, commands or MCP
servers are loadable. **Every conditional delegation therefore takes its `Otherwise` branch in every
arm that has ever run.** This is not a property of the two arms of 2026-09-02; it is a property of
the harness, and it has held since the harness was written.

## What it covers

All six rows of the wiring map, and there is no row it does not cover.

| Skill | Plugin | Fallback branch ever run | Installed branch ever run |
|---|---|---|---|
| `review-code` | `code-review` | no | no |
| `security-audit` | `security-guidance` | no | no |
| `create-skill` | `skill-creator` | no | no |
| `design-architecture` | `context7` | no | no |
| `context-budget` | `claude-md-management` | yes, 2026-09-02 | no |
| `write-docs` | `frontend-design` | no | no |

**The first column is the surprise, and it is worse than the second.** No scenario in
`tests/evals/scenarios/` injects any of these six skills. The nine `Inject:` lines name
`coding-standards`, `debug`, `design-database`, `execute-plan`, `incident-response`, `ship`, `tdd`
and `write-prd`, and `coding-standards` lost its delegation row on 2026-09-02. So for five of the
six, **neither branch has ever run** and the conditional has never been executed in any form. One
branch of one row has been measured: `context-budget`'s fallback, by the ad-hoc length arm of
2026-09-02, which exists only because the wiring pushed that body over the 700 word target.

`design-architecture` is the oldest of these and has carried the shape since it was written, so this
is not a gap the 2026-09-02 wiring introduced. It is a gap that wiring made visible by adding two
more rows to it.

## What the two 2026-09-02 arms did and did not establish

Recorded at `tests/evals/results.md` under 2026-09-02.

**`context-budget` at 723 words, passes.** The new clause fired in its fallback branch, verbatim:
"The `claude-md-management` plugin is not installed, so its rubric was not available." That is the
half that runs for every user without the plugin, and it is the half worth having measured. It is
also the only half this harness can reach.

**`write-docs` at 756 words, passes on length, with two gaps.**

**The `frontend-design` clause was not exercised at all**, in either branch. It is gated on
`profile.stack.has_ui`, the fixture has no profile and no UI, so the gate is correctly false and the
sentence correctly did not fire. That puts it with the four above rather than with
`context-budget`: neither branch has run. A fixture with a UI would reach the fallback; nothing
available would reach the other.

**Step 3's delegation did not fire**, and no subagent was spawned. The step says to delegate reading
to concurrent `Explore` agents where the snapshot, PRD and architecture doc do not exist, and none
existed.

**The fixture is the likely cause rather than the body, and that is a judgement and not a
conclusion.** Four files is small enough that reading them inline is a defensible call, where the
2026-08-19 arm at 738 words deliberately used a twelve file service so that branch was the one the
task reached. What would settle it is a re-run at 756 against the larger fixture: if the delegation
fires there, the body is fine and the fixture was the variable; if it does not, 756 is where that
step stops binding and ADR-0001's question has a real answer for the first time. Until that run
exists, this arm does not measure Step 3 and should not be read as having done so.

## What a fix would need

Not designed here, and deliberately so.

A runner mode that makes a named plugin loadable to a treatment arm, without reintroducing the
problem `--setting-sources ""` exists to solve: the arm must still get its keel skills from the
prompt text rather than from an installed keel, or the arm stops measuring the skill under test.
That is one new axis in `tests/evals/run.sh` and its README, plus a decision about what a plugin's
absence should mean for a scenario's verdict when the machine running the gate happens not to have
it installed.

It also needs a prior question answered, which is the one that decides whether any of it is worth
building: **what would an installed-branch arm actually catch?** The failure it would find is a
delegation that names a plugin correctly and then uses it wrongly, or one whose output the skill
does not know how to consume. Nobody has yet seen that failure, so the cost is known and the benefit
is not, which is the shape of a thing worth recording and not yet worth building.

## What this record is not

It is not a claim that the delegations are broken. Four of the six rows were true and unchanged for
weeks before the check existed, and the two written on 2026-09-02 follow the shape of the four.
It is a claim about what is known, and the honest summary is that the firing path is measured for
none of the six, the fallback path for one, and neither for the other five. That was not visible
until the check made the table trustworthy enough to ask the question of.
