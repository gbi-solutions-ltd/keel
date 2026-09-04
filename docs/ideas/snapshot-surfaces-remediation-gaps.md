# Idea: the snapshot should assess standards and security, and be re-run to show improvement

| | |
|---|---|
| Raised by | Bernard, 2026-08-17, alongside the profile schema question |
| Status | agreed, built 2026-08-17 |
| Recommendation | Build something smaller: make the snapshot's handoff to the two audit skills explicit and required, and leave the audits where they are |
| Next | `write-prd` is not warranted. This is a change to two skills, so `write-plan` |

## The problem

A snapshot of an unfamiliar repository tells you what the code is and where the debt is, but it does
not tell you where the repository stands against the standards it should meet or how exposed it is,
so a reader finishing the document still does not know whether the thing is safe to work in.

**Evidence.** Bernard's own framing, on reading the shipped skill: "one of the critical purposes of
the snapshot is to surface gaps that need remediation." No specific instance of a snapshot being run
and the gap biting was named, and the honest reading of that is that this is a purpose statement
about what the skill is for rather than a report of a failure. It is worth recording that
distinction, because it is why the recommendation below is small.

## What was asked for

> Could part of the snapshot's work also be that the repo is checked for coding standards (even if
> the house defaults are considered) as well as a security audit to assess current position? These
> could both be reported in the report. One of the critical purposes of the snapshot is to surface
> gaps that need remediation. In fact after remediation, the user could run the snapshot again as a
> way to ascertain being in a better position.

## The case against

**Strongest argument for not building this at all.** The snapshot already refuses this on purpose,
and the refusal is written down: section 8 of `references/section-templates.md` says "Do not attempt
a security audit; that is `security-audit`. Note what you noticed and move on", and the skill's own
Common mistakes table says "Fixing what you find: this skill reports." Folding two skills into a
third does not add a capability, because `security-audit --full` is already scoped for exactly this
moment ("New engagement, monthly, or after an incident") and `coding-standards` already reads a
repository and proposes its conventions. What it adds is a second place each of those jobs is
defined, which is the drift problem decision 6 already fought at 22 skills. It also cannot be done
without cutting the snapshot: the body is **698 words against a 700 ceiling**.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | Section 10 names a skill per recommendation, so a good snapshot already ends by pointing at `security-audit`. But nothing makes it, and a snapshot that quietly omits the pointer reads as a clean bill of health |
| Do it manually | Run the three skills in sequence and read three documents | This is what the design intends, and it works. The gap is that nobody is told to, not that they cannot |
| Buy it | A SAST or posture tool, a few hundred a month | Covers the security half only, misses authorisation and business logic entirely, per `security-audit`'s own Common mistakes row, and knows nothing about the house conventions |
| Build something smaller | An hour or two, in two skills | This is the recommendation |

Variants of building it:

| Variant | What it costs | Note |
|---|---|---|
| Snapshot requires a handoff line naming both skills, and says what it did not check | An hour. Fits: it is one sentence in step 6 and one in section 10 | Recommended. Reverses no decision, adds no duplication |
| A separate posture-baseline artifact, re-run and diffed | Days, plus a new skill and a new artifact | The genuinely unserved job here. Nothing in keel compares two runs over time. But it is a new skill, not a bigger snapshot, and section 9 forbids the single score a "better position" claim usually wants |
| Fold both audits into `repo-snapshot` | Days, and cuts to a 698-word body | What was literally asked for. Reverses section 8, duplicates two skills, and produces one long document instead of three that each get read |

**Status and Recommendation agree:** agreed, for the first variant.

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A reader of a snapshot does not already know to run `security-audit` | The handoff is being missed in practice | Look at whether any real snapshot run was followed by an audit | **No. No instance either way was named** |
| Re-running the snapshot would show improvement legibly | The document has stable comparable measures | Section 9's rubric is measured/estimated/unmeasured per metric, and section 9 explicitly forbids an overall score | Partly, and it cuts against the idea: the metrics are comparable, the summary judgement is deliberately absent |
| The two audits are cheap enough to run inside a snapshot | A `--full` audit is minutes, not hours | `security-audit --full` runs seven phases and delegates one subagent per phase | **No, and it is likely false.** A full audit is the most expensive skill in the set |
| Standards conformance is checkable against something written | The repo has standards, or house defaults apply | `skills/coding-standards/references/house-defaults.md` exists | Yes |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The snapshot already bans doing the audit | `skills/repo-snapshot/references/section-templates.md:164`, section 8 | The idea reverses a decision that was taken deliberately. Reversing it is allowed, but it needs a reason better than convenience |
| Security posture is already a named category in the debt section | Same file, section 8's grouping | The snapshot already records what it noticed. It just refuses to go looking |
| Section 10 already names the fixing skill per item | Same file, section 10, "Fix: `write-docs`", "Fix: `tdd`" | The handoff shape exists. What is missing is a requirement to use it for these two |
| `security-audit --full` is scoped for exactly this moment | `skills/security-audit/SKILL.md:21`, "New engagement, monthly, or after an incident" | The capability is not missing. The referral is |
| Agent C already reads auth, authorisation and webhook signature checks | `skills/repo-snapshot/SKILL.md:55` | A shallow security read is already happening, which is the dangerous middle: enough to look covered, not enough to be |
| No room in the body | `repo-snapshot` 698 words, `coding-standards` 683, `security-audit` 593, against ADR-0001's 700 | Anything added to the snapshot body must displace something. References are unbudgeted |
| Nothing in keel compares two runs of anything over time | No skill takes a prior artifact as a baseline | The "run it again to see if we improved" half is genuinely new, and it is the more interesting half |

## Open questions

1. **Is the missing thing the audit, or the referral?** Decided 2026-08-17 in favour of the
   referral, on the reasoning above. Recorded because the answer is reversible and the alternative
   is a real option.
2. Does the posture-baseline job deserve its own skill? It is the only genuinely unserved part of
   what was asked, and it stayed out of this recommendation because it is a different size of thing.
   Worth its own idea record if it comes back.
3. If a snapshot must say what it did not check, does the same rule belong on every reporting skill?
   `security-audit` already carries it ("Say plainly what you did not cover"). The snapshot does
   not, and that asymmetry looks accidental.

## Recommendation

**Build something smaller.** In `repo-snapshot`, require the document to state which checks it did
not perform, and require section 10 to carry a `security-audit --full` item and a
`coding-standards` item whenever the snapshot is a first look at an unfamiliar repository. Put the
wording in `references/section-templates.md`, which is unbudgeted, not in the 698-word body.

Why: the capability is not missing, the referral is. This gets the reader to the same three findings
without a second definition of either audit, and without cutting the snapshot to fit.

What happens next: `write-plan`, small, touching `repo-snapshot`'s section templates and step 6. The
posture-baseline idea in open question 2 is deliberately not part of it.

**Built 2026-08-17** as `f135e23`. The body change was one sentence, landing at 699 words against
ADR-0001's 700, and everything else went into the templates. Open question 2, the posture baseline
that diffs two runs, remains unbuilt and is still the most interesting part of what was asked.

One thing the build changed about the check itself, worth recording because it is the same class of
error this record warns about elsewhere: the validator originally matched `coding-standards` anywhere
in the templates file, and it already appears in section 7's table of missing documents, so the
assertion could not fail. It now matches inside section 10 only.

## Not decided here

Whether a posture baseline becomes its own skill, what it would measure, whether section 9's ban on
an overall score should hold if it did, and whether "say what you did not check" becomes a rule for
every reporting skill.
