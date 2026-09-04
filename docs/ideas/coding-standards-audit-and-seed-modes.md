# Idea: two more modes for `coding-standards`, audit and seed

| | |
|---|---|
| Raised by | Bernard, 2026-09-02 |
| Status | shaped. Three decisions taken 2026-09-02 and recorded here for the first time; the mode shape is argued rather than accepted |
| Recommendation | Build audit and seed, but only with Step 0a out of the body first, because the restructure is unaffordable otherwise and moving it is a real change rather than a word trick |
| Next | `write-prd`, following the `standards-that-bind.md` to `standards-assessment.md` path this skill already has. Not started |

## The decisions taken 2026-09-02

These exist nowhere else in the repository. Each is recorded with the consequence that makes it
load bearing, not just the choice.

**1. "Missing reference files" means keel's own topic references, not project files.** Seed mode's
gap report is therefore a feedback loop into keel's library rather than a to-do list for the
project. When seed cannot find a house rule covering a stack it has detected, the finding is that
`references/` has a hole, and the report says so to whoever runs keel rather than to whoever owns
the repository.

**A live example, verified 2026-09-02.** `lib/detect-stack.sh:430` sets `fw=flutter` and makes
Flutter a first-class detected framework. `references/house-defaults.md:27` gates `frontend.md` on
`profile.stack.has_ui` being true **and** `profile.stack.framework` not being `flutter`. There is no
`mobile.md`. So a Flutter application is a fully supported stack that receives no UI-layer house
defaults at all, and nothing anywhere reports that. Under this decision, seed on a Flutter app emits
"no house reference covers this stack's UI layer" as a keel finding. That is the whole argument for
decision 1 in one case: the gap is real, it is keel's, and today it is silent.

**2. The brownfield audit is report-only.** It writes `<docs_root>/audits/DATE-standards.md` and
nothing else. It does not write `standards.md`, and it does not edit anything it read. This mirrors
what assess already does, and `references/assessment-report.md:3-5` states the property for assess
in terms that apply unchanged. The consequence worth naming: audit on a repository with no
`standards.md` produces a document that describes conventions nobody has agreed to, so the report
must be explicit that it is a derivation and not a standard, or the next reader treats it as one.

**3. External adopters inherit `house-defaults.md` as-is.** No overlay file, no profile key, no
per-project variant of the house rules. An adopter who disagrees does so through their own
departures ledger in their own `standards.md`, which is the mechanism
`references/standards-template.md:85-87` already requires: every departure is either temporary with
a tracking reference or permanent with an ADR. The consequence: keel's house defaults are opinions
shipped as defaults, and the ledger is the only sanctioned way to disagree. That is a stronger claim
than the current wording makes, and it is the one that should be written into `house-defaults.md`'s
opening rather than left implicit.

## The shape, to be argued rather than accepted

|  | no `standards.md` | `standards.md` exists |
|---|---|---|
| **code to read** | **Audit** (new), then offer to author | **Assess** (shipped) |
| **no code yet** | **Seed** (new) | assess |

Two axes, four cells, three of them distinct modes plus the shipped one. The bottom-right cell is
assess by elimination rather than by design, and that is the cell to attack first: a `standards.md`
in a repository with no code is a document nobody can check against anything, so assess would run
its four checks against an empty corpus and report a coverage failure that means nothing. Either
that cell needs its own answer or the axis is wrong.

## Three things this record must not skip

### Seed inverts Step 1, and the skill has to say so

Step 1 is "Derive, do not impose. The conventions that matter are the ones already in use, not the
ones you would choose", and the first row of Common mistakes is "Importing a generic style guide,
instead: derive from the code". **Seed mode writes `standards.md` from the house defaults wholesale,
which is importing a generic style guide.** That is the thing the skill's own body forbids, in the
same file.

This is the same argument that killed the `coding-standards` to `context7` row on 2026-09-02, where
calling a documentation service for current conventions was ruled to be importing a generic style
guide with a citation attached. It applies here with the opposite conclusion, and the difference has
to be stated or the skill contradicts itself: **Step 1's rule is about a codebase that exists.**
Where there is no code, there is nothing to derive from, and the choice is between the
house defaults and nothing. Seed is the honest answer to a question Step 1 does not address rather
than an exception to it, and the body must say that in the mode's own words. A reader who meets seed
and Step 1 without that sentence is right to distrust one of them.

### Seed and audit sidestep the open question rather than answering it

`docs/ideas/standards-that-bind.md:624` leaves **"Why does a loaded rule not bind?"** open, and
calls it keel's own precondition for any wording change, citing
`tests/evals/results.md:2450-2452`. Every option ranked below third in that record's question 3 is
blocked on it.

Both new modes create a document. Neither adds a reminder, a gate or a read at the point of use, so
neither touches the precondition, and neither is blocked by it either. That is a defensible position
and it is not the same as answering the question. **Flag it before the first reviewer asks whether
the precondition was ignored:** it was not ignored, it was routed around, and routing around it is
only sound for as long as the modes stay document-producing. The moment either mode gains a rule
that is supposed to change behaviour at the point of work, it inherits the blocker.

### The body has 24 words, and the restructure is unaffordable without moving Step 0a

Measured 2026-09-02. `coding-standards` is 876 words against ADR-0001's 900 ceiling.

**Superseded by `4889f7a`, the same day.** Step 0a moved to `references/assess.md`, the body was
756, and the four-mode router was predicted to land at 781 with 119 spare. Both predictions are
superseded again by the router in `docs/plans/2026-09-02-the-four-mode-router-and-audit.md`, which
measures 112 words rather than 98 and lands the body at a measured 795. The heading above and the
figures below are the measurement that argued for the move, kept as the record of why it was made.
They are not the state of the tree.

| Piece | Words |
|---|---|
| Step 0, the author-or-assess prose | 74 |
| Step 0a, the four checks of assess mode | 119 |
| Headroom to the ceiling | 24 |

**Step 0 as a two-axis table plausibly pays for itself, and barely.** A four-mode table with the
disambiguation sentences measures 63 words against the current 74, so it covers twice as many
modes for 11 fewer. That is a real saving and nowhere near enough: it does not pay for two new
modes' worth of anything.

**Superseded 2026-09-02 by a measurement, and in the other direction.** That 63-word table dropped
the mode routing and the disambiguation sentences, which are the parts that do the work. A table
that actually routes four modes measures 98 words, so it **costs** 24 and does not save 11, and it
consumes the body's entire remaining headroom exactly. Both figures here are heading-inclusive,
which is the convention `tests/validate-skills.sh` counts in; see section 5 of
`docs/prd/coding-standards-audit-and-seed.md`, which states the convention because a first draft
mixed the two and got the headline wrong.

**The saving that matters is Step 0a's 119 words, and taking it is a real decision.** Four modes
cannot each carry a Step 0a in the body; the pattern does not scale past the one it has. So the mode
detail moves to `references/`, which frees about 130 words in total and makes the restructure fit.

**But that is exactly the move ADR-0001 names as the pathology.** `docs/standards.md:42-49` records
that `write-plan`'s sections were checked and left alone because they are instruction at the point
of use, and states the rule: reach for a reference because a reader needs it at one step, not as a
way to buy words. Step 0a's four checks in a fixed order are instruction at the point of use by that
test. Moving them out to afford two new modes is buying words, and the record should say so plainly
rather than presenting 130 freed words as a finding.

**The honest counter, which may or may not win:** with four modes, no reader needs all four in the
body, and a mode's detail is only ever needed after the mode is chosen. That makes Step 0 the
point-of-use instruction and each mode's steps a genuine reference, which is a different structure
rather than the same structure with words hidden. Whether that holds is the question the PRD has to
settle before any of this is built, and it should be settled by reading the four bodies side by
side, not by arithmetic.

## Not decided here

Whether audit and seed are one mode with a branch or two modes. Whether the gap report of decision 1
is written to a file or reported in the reply. What audit's report is called, given decision 2 puts
it at the same path assess writes and two modes writing one filename is a collision the PRD has to
resolve. And the bottom-right cell of the table above, which currently has no real answer.
