# Idea: shorter agent responses

| | |
|---|---|
| Raised by | Bernard, 2026-08-16 |
| Status | agreed, 2026-08-16, after the requester separated the two dials |
| Recommendation | SUPERSEDED. Was: an opt-in output style. Now: terse by default, verbose on request |
| Next | `docs/plans/2026-08-16-terse-chat-output.md`, then `docs/plans/2026-08-16-terse-by-default.md` |

**Reversed the same day, by instruction.** This record recommended opt-in and its variants table
rejected anything automatic, on the grounds that keel does not get to take a setting the user made.
The requester decided the other way: "let keel init set output style to be short by default ... the
user should instead decide if they want verbose output." Both readings are defensible and the choice
was theirs. What shipped is the profile key `conventions.response_style`, not an `outputStyle`
setting, because the style's addressable name could not be verified; the reasoning is in
`docs/plans/2026-08-16-terse-by-default.md`.

**The constraint that unblocked this**, given by the requester after the record was written:

> for context, document produced by the agents/models can be detailed but the conversation responses
> can be kept brief

That resolves the strongest objection below rather than answering it. The case against argued that
keel's rules exist to make the model say *more*, and it treated that as one dial. It is two:
artifact detail and chat length are set independently, and every rule the objection cited
(`say which checks you skipped`, `state your assumptions`, the one-line skill announcement) is a
short obligation, not a long one. Brevity threatens narration, not obligations.

It also makes the idea consistent with doctrine keel already ships rather than a new position:
`shape-idea` says "Chat is not an output", and `<docs_root>/prompting.md` tells the user to "point
at artifacts instead of re-explaining". Neither had anything enforcing it on the model's own side.

## The problem

Long chat replies cost output tokens and reading time on every turn, and the reading cost lands on
the person least able to skip it.

**Evidence.** Asserted from use. No measurement of keel's contribution to reply length exists, which
matters more here than on the other ideas: the largest term may not be keel's.

## What was asked for

> Could the agent responses be made brief/concise. This may also help with output token conservation.

## The case against

**Strongest argument for not building this at all.** keel's deliverable is already a file, not a
reply, and most of what sets reply length is the harness system prompt and the user's own global
instructions, neither of which keel can reach. So the change available is small, and the obvious
place to put it is the worst place: the always-loaded block, which is already a recorded departure
at 634 tokens against a 450 target, warned by `keel doctor` on every run. Adding a brevity rule there spends input tokens on every
single request to save output tokens on some of them, and nobody has measured which way that nets
out. There is also a direct conflict: several keel rules exist precisely to make the model say more,
including "say which checks you skipped", "state your assumptions", and "announce the skill in one
line". A blunt terseness instruction erodes the rules that make the process auditable.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The complaint is real and cheap to partly address |
| Do it manually | One line in the user's own `CLAUDE.md` | Already available, and arguably the correct home, but does not travel with keel |
| Buy it | Nothing available | Not a product |
| Build something smaller | One file, no always-loaded cost | An opt-in output style plus targeted trims |

**Variants of building it**

| Variant | Note |
|---|---|
| `output-styles/keel-terse.md` with `keep-coding-instructions: true`, opt-in | Costs zero until selected. User picks it in `/config` |
| Same file with `force-for-plugin: true` | Applies automatically, and overrides the user's own `outputStyle` setting. Rejected: keel does not get to silently take that setting |
| A line in the always-loaded block | Rejected while the block is over budget |
| Trim the report sections of the longest skills | Free, targeted, and does not fight the audit rules |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| keel is a material part of reply length | Removing it shortens replies measurably | Nobody has run the comparison | No |
| Terseness does not cost accuracy | Shorter replies still name skipped checks and stated assumptions | The Tier 3 evals would show it | No |
| An output style is discoverable | Users find it in `/config` | Requires a README line at minimum | No |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The always-loaded block is already over its budget, as a recorded departure | `docs/05-token-and-memory-design.md:279` measures it at 634 against 450; `bin/keel:1075` warns over 450 and fails over 700; `docs/standards.md:257` records the departure and its end condition | The cheapest-looking home for this rule is closed |
| Plugins may ship `output-styles/` | Claude Code output-styles documentation | A zero-always-loaded-cost mechanism exists, and keel ships none |
| Output styles do not reach subagents | Same documentation: subagents run their own system prompt | Delegated work stays as verbose as before. This only fixes the main thread |
| Several keel rules deliberately require the model to say more | `skills/ship/SKILL.md` overrides; block, "say which you skipped"; `skills/keel/SKILL.md`, "announce it in one line" | Any terseness rule must exempt these by name |
| Skill bodies are already ceilinged and linted | `docs/decisions/ADR-0001-skill-body-word-ceiling.md`; `keel doctor` | Instruction length is governed. Reply length is not |

## Open questions

1. **What is the actual split?** Before writing a rule, measure one comparable task with and without
   keel loaded. If keel is 10% of reply length, this idea is close to worthless.
2. **Opt-in or forced?** Forced is one boolean and takes over a setting the user chose. Recommended
   answer: opt-in.
3. **Does terseness break the evals?** The Tier 3 scenarios assert that gates are announced. A style
   that suppresses the announcement fails them, which is the right outcome and worth knowing early.

## Recommendation

**Build something smaller.** Ship `output-styles/keel-terse.md`, opt-in, with
`keep-coding-instructions: true` and explicit carve-outs for the announcements keel depends on. In
the same pass, trim the report and summary sections of the skills that produce the most chat.

Do not put a brevity rule in the always-loaded block while the block is over budget, and measure the
split before spending anything larger than this on the idea.

## Not decided here

The wording of the style; which skills' report sections are worst; whether `/config` discoverability
needs more than a README line.
