# Idea: five bodies over the target, and whether the arms they have discharge them

| | |
|---|---|
| Raised by | Bernard, 2026-09-03, from the seven length warnings `tests/validate-skills.sh` prints on every run |
| Status | **decided, 2026-09-04, by Bernard: Reading A.** See [Decided](#decided-2026-09-04) at the foot of this record. The ruling itself lives in [`ADR-0001`](../decisions/ADR-0001-skill-body-word-ceiling.md), whose sentence the ambiguity belonged to |
| Recommendation | none, deliberately. This record set the question out per skill and left it unanswered; the answer came from Bernard rather than from here |
| Next | `write-plan` 897 only. It has no arm of either kind, so the ruling does not reach it, and whether it gets an arm or a cut is Bernard's next decision. Nothing is scheduled |

## The seven warnings, and the five this record is about

```
tests/validate-skills.sh
```

```
WARN  coding-standards: body is 795 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  context-budget: body is 723 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  execute-plan: body is 884 words, 16 from the 900 ceiling and over the 700 target. Adding a sentence fails the suite: take the words out of this body, or move a section a reader needs at one step into references/. ADR-0001 requires a passing eval arm at this length.
WARN  tdd: body is 793 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  write-docs: body is 756 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
WARN  write-plan: body is 897 words, 3 from the 900 ceiling and over the 700 target. Adding a sentence fails the suite: take the words out of this body, or move a section a reader needs at one step into references/. ADR-0001 requires a passing eval arm at this length.
WARN  write-prd: body is 793 words, over the 700 target (ceiling 900). ADR-0001 requires a passing eval arm at this length.
OK    25 skills validated, descriptions about 1130 tokens, 7 warning(s)
```

Seven bodies are over the target. `CONTRIBUTING.md:45-52` names two of them as covered:
`coding-standards` at 795 on the audit arm of 2026-09-03, and `write-docs` at 756 on the arm of
2026-09-02. This record is about the other five.

| Skill | Body | Over the 700 target by | From the 900 ceiling |
|---|---|---|---|
| `context-budget` | 723 | 23 | 177 |
| `tdd` | 793 | 93 | 107 |
| `write-prd` | 793 | 93 | 107 |
| `execute-plan` | 884 | 184 | 16 |
| `write-plan` | 897 | 197 | 3 |

## The rule

[`ADR-0001`](../decisions/ADR-0001-skill-body-word-ceiling.md) moved the hard ceiling to 900 and
made 700 an enforced warning, and it priced the room: "A skill body over 700 words requires a
passing eval arm at that length, recorded in `tests/evals/results.md`, so the room is taken against
observed behaviour rather than against an assertion."

`CONTRIBUTING.md:45-52` states how that obligation transfers, and the sentence is load bearing here:

> **An arm discharges the length it was run at, not the body it was run against**, so a body that
> grows past the length of its last passing arm owes a new one.

## What `results.md` actually shows for the five

Checked against [`tests/evals/results.md`](../../tests/evals/results.md) rather than against the
CONTRIBUTING summary, and this is where the premise of this record changed.

| Skill | Body | Passing arm at exactly this body | Where |
|---|---|---|---|
| `context-budget` | 723 | yes, a dedicated ADR-0001 length arm | 2026-09-02, "`context-budget` at 723 words, the ADR-0001 length arm. Passes" |
| `write-prd` | 793 | yes, a dedicated ADR-0001 length arm, and a gate arm since | 2026-08-30 length arm at 793, and `build-with-no-prd` in the 0.17.0 gate |
| `tdd` | 793 | a passing gate arm, twice, but no dedicated length arm | `tdd-under-deadline` and `done-without-verifying`, 0.17.0 gate, 2026-09-01 |
| `execute-plan` | 884 | a passing gate arm, but no dedicated length arm | `done-without-verifying`, 0.17.0 gate, 2026-09-01 |
| `write-plan` | 897 | **none, at any length, ever** | no scenario injects it |

**The gate arms ran these exact bodies, byte for byte.** The 0.17.0 gate is recorded as run against
`sandbox` at `f3b9904`, with every arm staged by `tests/evals/stage.sh`, and four of the five bodies
have not been touched since:

```
git rev-parse f3b9904:skills/tdd/SKILL.md HEAD:skills/tdd/SKILL.md          # identical
git rev-parse f3b9904:skills/execute-plan/SKILL.md HEAD:skills/execute-plan/SKILL.md   # identical
git rev-parse f3b9904:skills/write-prd/SKILL.md HEAD:skills/write-prd/SKILL.md         # identical
git rev-parse f3b9904:skills/write-plan/SKILL.md HEAD:skills/write-plan/SKILL.md       # identical
```

`context-budget` is the one that differs: it went 692 to 723 at `f6bb41a` on 2026-09-02, after the
gate, which is exactly why it got its own arm two days ago.

So the count of bodies over 700 with no passing arm at their current length is **not five**. On the
rule as `CONTRIBUTING.md` states it, it is **one**, and `CONTRIBUTING.md:48-51`'s "two bodies are
currently covered" is itself out of date: it omits the `context-budget` arm of 2026-09-02 and the
`write-prd` arm of 2026-08-30, both of which are headed in `results.md` as ADR-0001 length arms and
both of which pass at the body that is on disk now.

## The disagreement is about two of the five, and it is a real one

**Reading A, the literal one.** ADR-0001 asks for "a passing eval arm at that length, recorded in
`tests/evals/results.md`". It does not ask for a dedicated one. The 0.17.0 gate arms are passing
arms, they are recorded there, and they ran these bodies unmodified. Under this reading `tdd` and
`execute-plan` are discharged, and only `write-plan` owes anything.

**Reading B, the narrower one.** A gate arm is scored on the scenario's own criteria, and its
verdict says nothing about length: the `done-without-verifying` entry grades `open x1, named x3` and
never mentions 884 words. A dedicated length arm exists to ask one question, "is this body still
followed at this length", and the two dedicated arms in `results.md` are written that way, each
headed with the word count and each verdicted "passes on length". Under this reading a gate pass is
evidence and not a discharge, and `tdd` and `execute-plan` still owe an arm.

Both readings agree on `context-budget` and `write-prd`, which have dedicated arms at their exact
current lengths, and both agree on `write-plan`, which has nothing.

## `write-plan` is the one with nothing, and it is the one with three words of room

No scenario in `tests/evals/scenarios/` injects `write-plan`:

```
grep -rn '^Inject:' tests/evals/scenarios/
```

Eleven of the twelve scenarios carry an `Inject:` line, and between them they name
`coding-standards` (four times), `debug`, `design-database`, `execute-plan`, `incident-response`,
`ship`, `tdd` and `write-prd`. `write-plan` appears in none of them, so its body has never been
measured under any prompt, at 897 words or at any other length. It is also the body closest to the
ceiling: the validator's own comment records that "`write-plan` sat at 897 and nothing said so until
someone tried to add a sentence and had the suite refuse it".

## What each option costs

Two options per skill. Neither is chosen here.

| Skill | Run an arm at the current length | Bring the body under 700 |
|---|---|---|
| `context-budget` | A scenario has to be staged ad hoc, as the 2026-09-02 arm was: a four file Node service with a 22,970 byte `CLAUDE.md`. That arm cost $0.62 for 14 turns | 23 words. The smallest cut of the five, and it would put the body back where it was before the `claude-md-management` delegation was wired on 2026-09-02, which is the edit that pushed it over |
| `tdd` | Two existing scenarios already inject it, so the arm is a re-dispatch with no authoring cost | 93 words out of a body that has been unchanged since 2026-08-19 and has passed every gate arm dispatched against it since |
| `write-prd` | One existing scenario injects it, and a dedicated arm at 793 already exists from 2026-08-30 at $0.47 for 10 turns | 93 words, including the two that were added deliberately on 2026-08-30 to read `profile.artifacts.snapshot` |
| `execute-plan` | One existing scenario injects it, so the arm is a re-dispatch | 184 words, the second largest cut. The body is also 16 from the ceiling, so the next edit that adds a sentence fails the suite whether or not an arm is run |
| `write-plan` | No scenario exists. An arm means authoring a scenario and a fixture first, then dispatching. No recorded arm's cost covers the authoring | 197 words, the largest cut of the five, out of the body with 3 words of headroom. ADR-0001 records that moving content into `references/` does not pull a body below roughly 680, so this is cutting content and not relocating it |

**An arm costs real money.** The figure this repository has for a recent one: the audit arm of
2026-09-03 cost **$0.8798325 for 14 turns**, 217.305 seconds, `claude-opus-5[1m]`. The two dedicated
length arms above cost $0.62 and $0.47, and the six arm 0.17.0 gate cost $2.3430 in total. So a
single arm has run between roughly $0.47 and $0.88, and five of them is a few dollars plus the
scoring time, which is the larger cost and is not in any of those figures.

**Cutting a body costs no money and is not free.** ADR-0001's own consequences section says the
reference offload lever is exhausted at roughly 680 words, so words taken out of these five come out
of steps a reader needs, and the ADR's verification section warns that a body which migrates to the
ceiling is the failure it diagnosed rather than a state to defend.

## The question

**Does each of these five owe an arm at its current length, or does the body come down instead?**

It is a different question per skill, and that is the point of stating it rather than answering it:

- `write-plan` at 897 is three words under the ceiling and has never been evaluated at all. It is
  simultaneously the strongest case for an arm and the most expensive one to run.
- `execute-plan` at 884 has a passing gate arm at exactly this body and 16 words of headroom.
- `tdd` and `write-prd` at 793 both have passing gate arms at exactly this body, and `write-prd` has
  a dedicated one as well.
- `context-budget` at 723 is twenty-three words over the target with a dedicated passing arm two
  days old, which makes it the cheapest to cut and the least in need of anything.

Not answered here.

## What this record does not do

**Decision 46 keeps these recorded and not fixed in this epic.** No body is edited, no arm is run,
and none of the five arms is to be run as part of this epic. `CONTRIBUTING.md`,
`tests/evals/results.md` and everything under `skills/` are untouched by the change that carries
this record.

## Open questions

1. **Does a gate arm discharge an ADR-0001 length obligation?** This is the question underneath the
   two readings above, and settling it changes the count from one to three. It belongs in ADR-0001
   or in `CONTRIBUTING.md`, not in a record like this one.
2. **Is `CONTRIBUTING.md:48-51` corrected, or is it right for a reason not written down?** As it
   stands it names two covered bodies where `results.md` supports at least four, and it is the
   sentence a contributor reads before deciding whether an edit is affordable.
3. **Should `write-plan` have a scenario at all?** `context-budget` and `write-docs` have no
   scenario either, but both have had ad hoc length arms staged for them, and `write-plan` has had
   nothing. A planning skill never measured under any prompt is untested in the sense the eval
   suite exists to test, and that is a larger gap than its word count.
4. **Does the warning band want a second threshold?** The validator already says something different
   within 20 words of the ceiling. `context-budget` at 23 over the target and `write-plan` at 197
   over it produce the same obligation today, and the table above suggests they are not the same
   problem.

## Not decided here

Which of the two readings is correct; whether any of the five bodies is cut; whether any arm is run,
and in what order; whether `write-plan` gets a scenario; whether `CONTRIBUTING.md` is corrected.

## Decided, 2026-09-04

**Bernard ruled for Reading A.** A passing arm recorded in `tests/evals/results.md` discharges an
ADR-0001 length obligation at the length it was run at, whether it was dispatched as a release-gate
arm or as a dedicated length arm. The sections above are the record of the argument and are left in
the tense they were written; nothing in them is rewritten to point one way.

Recorded as a dated clarification in the Decision section of
[`ADR-0001`](../decisions/ADR-0001-skill-body-word-ceiling.md), because the ambiguous sentence is
that ADR's own, which is what open question 1 above says. `CONTRIBUTING.md` carries the operational
consequence and no longer names the question. Its line references above, `CONTRIBUTING.md:45-52`
and `:48-51`, describe that file as it stood on 2026-09-03 and are left as written.

**What the ruling closes.** `tdd` at 793 and `execute-plan` at 884 are discharged. Re-verified for
this entry rather than taken from the table above: `tdd-under-deadline` and `done-without-verifying`
are both recorded Pass in the 0.17.0 gate of 2026-09-01, and `git rev-parse` reports both bodies
byte identical between `f3b9904` and `HEAD`. With `context-budget` 723, `write-prd` 793,
`coding-standards` 795 and `write-docs` 756 already covered by dedicated arms, six of the seven
bodies over the target now carry a passing arm at their current length.

**What it leaves open.** `write-plan` at 897 has no arm of either kind, because no scenario injects
it, so the ruling does not reach it and it is untouched: no scenario was written for it, no arm was
run, and its body was not cut. Open questions 3 and 4 above are unaffected. Open question 1 is
answered by this ruling and open question 2 by the `CONTRIBUTING.md` edit that came with it.

`tests/validate-skills.sh` still warns on all seven bodies and still says an arm is required at that
length. That stays true: the warning fires on the length and says nothing about whether the
obligation has been discharged, so it needs no word.
