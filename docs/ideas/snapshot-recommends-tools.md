# Idea: a gap the snapshot finds should name the tool that fills it

| | |
|---|---|
| Raised by | Bernard, 2026-08-17 |
| Status | **built 2026-08-17**, via `docs/plans/2026-08-17-release-readiness.md` task 7, fully ticked. The shared reference is `skills/keel/references/tool-choices.md`. Status corrected 2026-08-30 |
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
| The languages worth covering are the ones keel detects | Detection is the same list a snapshot would face | `lib/detect-stack.sh` detects thirteen | Yes |
| Three new tools is the most a reader will adopt from one document | Section 10 already caps at seven items and says name two or three in the handoff | Consistent with the existing cap, which was set for the same reason | Partly |

## What the system says

| Finding | Evidence | What it means |
|---|---|---|
| Section 10 already names a skill per item | `skills/repo-snapshot/references/section-templates.md`, section 10 | The slot exists. This adds a tool and a reason to a shape already there |
| Two referrals are already required on a first look | Same file, after the 2026-08-17 handoff change | Precedent for section 10 carrying a requirement, and for the validator checking it inside section 10 only |
| The snapshot body is at 699 of 700 words | ADR-0001, and the handoff change that spent the last word | Nothing may go in the body. All of it is references |
| Shared references live in `skills/keel/references/` | `asking-questions.md`, cited by six skills | The location is settled, not a new convention |
| The CLI already knows the stack | `lib/detect-stack.sh`, and `profile.stack.language` in every profile | The table can be keyed on a value the reader already has, so no detection logic is duplicated |
| A validator rule can be keyed to detection | `detect_languages` accumulates the language list in one place | A language added to detection with no row in the table becomes a failing build, which is the only thing that will keep the table honest |
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
