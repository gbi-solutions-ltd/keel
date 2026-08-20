# Idea: measure whether a snapshot's citations are right, not just resolvable

| | |
|---|---|
| Raised by | Bernard, 2026-08-20, from the follow-up the haiku measurement opened |
| Status | shaped. The smaller thing is agreed in shape and not built. Nothing folded into the eval criteria, by instruction |
| Recommendation | Build something smaller, and aim it at **coverage rather than accuracy**: a deterministic check for claims carrying no `path:line`, which is where the expensive error landed. Do not build a sampled per-document accuracy check. **Blocked 2026-08-20:** a scripted version of this measure was shown to count itemised rows rather than claims, and is unbuildable until "what counts as a claim" is defined. See "One honest limit" |
| Next | Nothing. This does not warrant a PRD, for the reason given under Recommendation |

## The problem

Whoever acts on a snapshot inherits its errors, and roughly one citation in seven does not support
the claim attached to it, with nothing in keel measuring or reporting that.

**Evidence.** Measured 2026-08-20, recorded in `tests/evals/results.md`. Two `repo-snapshot` runs on
the same 187-file tree: hand-checking 20 citations per arm, the shipped `sonnet` configuration was
defective on 3 of 20 and the `haiku` arm on 7 of 20. Both documents passed every structural rule the
skill carries.

**What has not happened.** Nobody has yet acted on a defective citation from a keel snapshot and been
burned. There is no incident, no wasted afternoon, no wrong PRD traceable to one. The harm is
projected from `repo-snapshot`'s own core principle rather than observed, and that gap is the single
most important thing on this page. It is why the recommendation is as small as it is.

## What was asked for

> 15% of sonnet's citations were also defective, and sonnet is what ships. repo-snapshot feeds
> write-prd, design-architecture and everything downstream, and its own principle is that a confident
> snapshot which is wrong is worse than none because the next three decisions inherit the error.
> Nothing measures this today: my structural criteria passed a 35% document without comment, and
> passed the 15% one too.
>
> Shape this, do not build it. What would a check on citation accuracy actually cost, who runs it and
> when, and can any of it be automated without the contamination problem you hit? Say plainly if
> hand-checking a sample is the only honest option, and what sample size makes it meaningful at a 15%
> base rate. Do not fold anything into the eval criteria until the shape is agreed.

## The case against

**Strongest argument for not building this at all.** The check as described would measure the
cheapest failure mode and miss the expensive one. Every citation defect found on 2026-08-20 was wrong
*coordinates* attached to a substantially right *claim*: `.keel/profile.json:14` for
`package_manager` where it is at `:13`, `bin/keel:1868` for defaults that are at `:430`. A reader who
opens one loses thirty seconds and finds the thing two lines up. Meanwhile the worst factual error in
either document, sonnet's claim that `bin/keel` holds **six** subcommands where the dispatch table at
`bin/keel:1845-1852` holds **eight**, carried **no `path:line` at all**, so a citation-accuracy check
of any design would have scored that document clean on it. The failure that actually propagates into
a PRD is an uncited confident sentence, and this instrument is blind to exactly those.

**That argument survives, and it redirects the work rather than ending it.** Building a citation
*accuracy* checker is still the wrong move. But the sentence it would have missed is not unreachable:
a claim carrying no `path:line` is detectable by exactly the same deterministic means as a citation
that does not resolve, and far more cheaply than judging whether a cited line supports its claim. The
gap is coverage, and coverage is the tier-1-shaped half of the problem.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The rate moved from 15% to 35% on a one-word change to a model pin. Nothing in keel would have shown that, and the pins are expected to move again |
| Do it manually | Minutes, per reader, at the point of use | This is not an argument against it: it is the best answer to the *harm* and should happen regardless. It is simply not a measurement, so it cannot detect drift or answer whether the rate is getting worse |
| Buy it | Nothing available | Groundedness and hallucination tooling checks a claim against a supplied passage. Nothing resolves `path:line` against a working tree, because that is a keel-shaped problem, not a RAG-shaped one |
| Build something smaller | About 50 lines and no ongoing cost | This is the recommendation. See below |

**Variants of building it**

| Variant | Note |
|---|---|
| Tier 1, resolution: the file exists and the line is in range | Deterministic, uncontaminated, censuses every citation for free. Would have caught 4 of sonnet's 6 defects and 1 of haiku's 8 |
| Tier 2, locality: a token from the claim appears within N lines | Built and discarded on 2026-08-20. Too noisy to gate on. Honest use is triage, picking which citations a human opens first |
| Tier 3, support: does the line say what the document says it says | Requires judgement. This is the only tier that measures the stated problem, and the only one that cannot be made cheap |
| Tier 3 by LLM judge | Possible, contaminated in a nameable way. See the contamination row in the assumptions table |
| Tier 3 by hand, sampled per document | **Rejected on arithmetic, not on cost.** See the sample-size finding below |
| Tier 3 by hand, census, on a model-pin change | The recommendation's second half. About two hours per model change |
| Fold any of it into the eval pass criteria | Explicitly deferred by Bernard until the shape is agreed. Not proposed here |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A defective citation costs a downstream decision | The claim is wrong, not merely its coordinates | Someone acts on one and is burned, or a PRD is traced back to one | **No, and nothing has been observed.** Every defect measured in the two sampled documents was coordinates, not claim. **One instance since is not:** the 2026-08-20 delegation write-up cited `SKILL.md:49-50` for a claim at `:46-47`, where the cited lines hold the dispatch instruction and support nothing, from reading line numbers off a staged prompt with a three-line preamble. See `tests/evals/results.md` |
| The rate is a property of the model, not the repository | It moves with the pin and not with the tree | Re-measure with one pin against two different repositories | **Partly.** It moved 15% to 35% with the pin held against one tree. The other direction is untested |
| A sample can estimate a document's rate | The citation population is large relative to the sample | Arithmetic | **No, disproved.** See below |
| An LLM judge is less contaminated than a self-check | The judge sees the claim and the raw lines, never the document's prose framing | Run a judge against the 2026-08-20 hand census and compare verdicts | **No.** This is the cheapest open question and would decide two hours against minutes |
| Today's 15% and 35% are solid enough to build on | The sample is powered to separate them | Arithmetic | **Weaker than it reads.** See the power finding below |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| keel already builds tier-1 checks and stops there, twice | `tests/validate-skills.sh:141` reports a broken relative link; `bin/keel:764` reports a referenced document not in HEAD | The resolver is not a new idea in this codebase, it is the third instance of an established pattern. It also shows the house style has never attempted tier 3 |
| The skill already caps verification, deliberately | `skills/repo-snapshot/SKILL.md:70-71`, "Cap at six: where being wrong changes what somebody does" | Most citations in a snapshot are *designed* to be unverified. A check that demands they all be right is arguing with the skill, not testing it |
| The accuracy guarantee is scoped to section 10 only | `skills/repo-snapshot/references/section-templates.md:23-25`, "Verified or not recommended" | The 15% is measured across a population the skill never promised was verified. The honest headline is a section 10 rate, not a document rate |
| The scoped guarantee is not fully delivered either | 2026-08-20: **each** arm carried exactly one defective citation inside section 10 (haiku `.gitignore:9-11`, real carve-out at `:20`; sonnet `tests/run-tests.sh:31`, real line `:34`) | This is the finding worth acting on. Step 3 verification is the skill's own promise and it leaks |
| Defect counts overstate independent errors | Sonnet's 4 out-of-range citations are one wrong mental offset for the end of a 1,864-line file, spent across one table | Any future measurement should count root causes as well as citations, or a single slip reads as a systemic rate |
| A document holds only 59 to 77 citations | Measured, both arms | The population is too small for sampling to work. This is the decisive constraint |
| **The citation rule is the skill's own, not a README overclaim** | `skills/repo-snapshot/SKILL.md:13` states it as the core principle; `:64-65` puts it verbatim into every subagent brief; `skills/repo-snapshot/references/section-templates.md:12-13` says "There is no third option" | Stated three times inside the skill. `README.md:202` is a fourth statement, not the origin. So this is **an unenforced rule, not an unstated one**, which is a stronger finding: the repo already decided, and never checked |
| Nothing anywhere enforces it | No test, validator or hook reads a snapshot. `tests/validate-skills.sh` validates skill bodies, never their output | The rule has not been checked once since it was written |
| **The expensive error landed in an uncited claim** | Sonnet's "six subcommands" sits in section 10's `Also noted` paragraph, which carries no `path:line` anywhere in it | An uncited claim is invisible to tiers 1, 2 and 3 alike, because all three begin from a citation. This is the gap |

### The sample-size answer, plainly

**Hand-checking a sample is the only honest option for tier 3, and at a 15% base rate no sample that
fits inside one document is meaningful.** The arithmetic, computed 2026-08-20:

| What you want | What it takes at p=0.15 |
|---|---|
| Estimate one document's rate to +-5pp | n=50 of a 77-citation population, which is 65% of it. Censusing is barely more work |
| Estimate to +-10pp | n=30, still 39% of the document |
| Separate 15% from 35%, 80% power | **n=77 per arm.** Every citation in the document |
| Detect that any defect exists at all | n=10 gives an 80% chance, but at a 15% steady state this always fires and tells you nothing |

Two consequences follow, and both cut against the original framing.

**Today's own comparison is thinner than it reads.** At n=20 per arm the power to separate 15% from
35% is about 30%. The conclusion that haiku loses does not rest on that comparison alone, and should
not be quoted as if it did: the out-of-range counts (4 against 1) were a **full census** of both
documents, and the systematic pattern, haiku one line low on `.keel/profile.json` across three
separate sections, is a root-cause observation rather than a sampled rate. Those carry the finding.
The 35% and 15% point estimates are directional.

**A per-document check is therefore not buildable as a measurement.** Either you census the document,
which is tier 1 for free or tier 3 for about two hours, or you learn nothing about its rate. The
statistically honest route for tier 3 is to **pool across runs**: 100 citations accumulated over
several model changes reaches +-7pp, which is why the recommendation is longitudinal rather than
per-release or per-document.

### The coverage gap, measured

Measured 2026-08-20 on the same two documents, counting table rows and bullets as claims, excluding
table header rows, and honouring the escape hatches the rules allow (`Unknown`, `absent`,
`unverified`, `measured`, `estimated`). Sections 3, 7 and 9 are excluded because their own rules
exempt them: section 3 is a reading list, section 7 is about things that are absent by definition,
and section 9 marks every value `measured` or `estimated` instead.

| | Haiku | Sonnet |
|---|---|---|
| Claim rows in sections 1, 2, 4, 5, 6, 8 | 50 | 53 |
| **Carrying no `path:line` and no escape hatch** | **27 (54%)** | **13 (25%)** |
| Section 10 items | 8 | 8 |
| Section 10 items with no `path:line` anywhere | 2 | 2 |

**For the configuration that ships, uncited claims and defective citations are the same order of
magnitude.** Sonnet carries about 13 uncited claim rows against roughly 11 defective citations
(15% of 77). One half of that is invisible to every tier described above, and it is the half the
worst error was in.

**The sharpest form of the finding.** Both arms have exactly two section 10 items carrying no
citation at all. Sonnet's is the `Also noted` paragraph asserting six subcommands where there are
eight. Haiku's is the `bin/keel` refactor item asserting 1,864 lines and eight subcommands, which is
correct. **The same structural slot holds one arm's wrong claim and the other arm's right one, and
nothing on the outside of either distinguishes them.** That is what an unenforced rule looks like
from the outside, and no amount of accuracy checking over cited claims reaches it.

**One honest limit.** Resolution is exact: a file either exists and has that many lines, or it does
not. Coverage is not, because "what counts as a claim" is a judgement. The measurement above took
three attempts before it stopped counting table headers and reading-list entries as uncited claims,
and that tuning is where its false positives would come from. It is deterministic, and it is not
free of design decisions the way tier 1 resolution is.

**That limit arrived on 2026-08-20, and it is fatal to the measure as specified.** The delegation
measurement in `tests/evals/results.md` scripted this measure, froze it, and pointed it at a document
written in a different shape from the two it was calibrated on. It reported the inline document 21pp
worse. **The inline document carries 68 `path:line` citations against the delegated document's 52.**
Both cannot be true, and the denominator is what is wrong.

**The measure counts itemised rows, not claims.** Three separate effects, all verified by opening the
documents:

| Effect | Evidence |
|---|---|
| **Prose is invisible** | The delegated document's section 5 is prose plus two fenced blocks, so it scored **0 of 0**. It carries real citations and real uncited claims and none of them counted. A section written as prose cannot be marked uncited |
| **Itemisation is penalised** | One finding, that `tests/evals/` is absent, written by the delegated arm as a prose paragraph carrying four citations and counted as **zero rows**, and by the inline arm as a numbered item with five nested bullets and counted as **six rows, five uncited** |
| **Executed evidence is penalised** | "`tests/test-eval-harness.sh` fails 15 of 18 assertions" is an observed test result with no line to cite and no hatch word, so it scores uncited. `repo-snapshot` Step 3 *requires* running commands and reporting what they print, so the skill's gate and this instrument disagree |

**The calibration could not have caught this.** It was validated on the haiku and sonnet documents,
both produced by the same delegated pipeline and both the same shape, and agreed to the rounded
percent on both. That validates an instrument *within a document shape*, and shape is the variable it
is sensitive to.

**A shape-insensitive version would have to count** a denominator of claims rather than rows; prose
sentences that assert something; one finding as one claim regardless of nesting depth; and it would
need a hatch for claims whose evidence is an executed command. The first two need sentence
segmentation and a definition of assertion, **both judgements**.

**This is a precondition on the recommendation below, and it undercuts its main argument.** The
recommendation rests on coverage being the deterministic, model-free, denominator-is-free half of the
problem. It is not free. Until "what counts as a claim" is defined and tested against documents in at
least two shapes, this check must not be built, and it must not be folded into any pass criterion,
because it would score prose above itemisation and measurement above both.

### Contamination, and what survives it

| Tier | Automatable | Contamination |
|---|---|---|
| 1, resolution | Fully | **None.** `os.path.isfile` and a line count. No model in the loop |
| 2, locality | Yes, but | **Self-inflicted, and I hit it.** The first version extracted the citation string itself as the token to search for, so correct citations scored as failures. Fixable, and even fixed it disagreed with the hand census often enough to be triage only |
| 3, support | Only with a model | **Structural, and not removable.** A model judging whether a line supports a claim can share the misreading that produced it. Giving the judge only the claim and the raw lines, never the surrounding prose, reduces the anchoring but does not make it a different kind of thing |

## Open questions

1. **Does a defective citation ever change a downstream decision?** Unknown, and nobody can name an
   instance. This decides whether any of this is worth doing, and it is the reason the recommendation
   is small. The cheapest way to answer it is to notice the next time a `write-prd --from-repo` run
   inherits something wrong, rather than to build an instrument first.
2. **Would an LLM judge, given only the claim and the raw lines, agree with the hand census?** The
   2026-08-20 census is on disk and makes a ready-made answer key. This is the difference between two
   hours and minutes per model change, and it is a half-hour experiment.
3. **Is the rate a property of the model or of the repository?** Measured against keel itself, which
   is unusually well commented and may flatter a weak reader.
4. **Should the honest headline be a section 10 rate rather than a document rate?** The skill only
   promises section 10. Reporting a document-wide rate measures something nobody claimed.
5. **Is "a claim" definable tightly enough to gate on?** The coverage measurement above needed three
   attempts to stop counting table headers and reading lists. A check that cries wolf on a reading
   list will be switched off. This is the only real implementation risk in the recommendation, and
   it is a tuning question rather than a research one.

## Recommendation

**Build something smaller, and point it at coverage rather than accuracy.** The order changed once
the uncited claim was measured: **tier 1 over uncited claims is worth more than tier 3 over cited
ones**, and it is cheaper.

**First, the coverage check.** Flag any claim-bearing row or item carrying neither a `path:line` nor
one of the escape hatches the rules already name. It is deterministic, needs no model, and lands
exactly where the expensive error was: sonnet's only materially wrong fact sat in the one section 10
item with no citation in it. The rule it enforces is already written three times inside the skill
(`skills/repo-snapshot/SKILL.md:13` and `:64-65`,
`skills/repo-snapshot/references/section-templates.md:12-13`), so this adds no policy, it checks a
policy the repository set and never verified.

**Second, the resolver**, unchanged from the earlier draft and now the junior partner: file exists,
line in range, a free census of every citation. It catches the dominant failure of the model that
ships and it is the third instance of a pattern `tests/validate-skills.sh:141` and `bin/keel:764`
already establish.

**Third, and only on a model-pin change, the hand census** for tier 3. Not per release, not per
document, pooled across runs so a rate becomes estimable over time. About two hours, paid only when
something that could move the rate has moved.

**What happens next: still nothing is built.** This does not warrant `write-prd`; the whole of the
first two parts is one script. But the ordering is now the useful output of this record, and it
inverts what was asked for: **the accuracy question that prompted this is the least valuable third of
the work.** The trigger to build the coverage check is the next `repo-snapshot` change of any kind.
Question 1 below is still unanswered and still gates the expensive third.

## Not decided here

Whether the resolver runs as a test, a hook, a `doctor` check or a bare script, and whether it lives
beside `validate-skills.sh` or under `bin/`. Whether the snapshot document should state its own
citation reliability to its reader. Whether any of this ever becomes an eval pass criterion, which is
deferred by instruction until question 1 is answered. What `repo-snapshot`'s Step 3 should do about
its own leak, which is a change to a skill body and belongs to whoever takes that decision. Whether
`README.md:202` should stop describing the fan-out output as "checkable" while nothing checks it,
which is a claim about the repository rather than about this idea.
