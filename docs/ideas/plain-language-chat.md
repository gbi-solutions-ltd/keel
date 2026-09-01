# Idea: plain language in chat replies

| | |
|---|---|
| Raised by | Bernard, 2026-08-18 |
| Status | **built 2026-08-18.** `conventions.explain_level` is written at init, `bin/keel:436`, and is in the schema; doctor's handling of it is asserted in the suite. The record still said `shaping`, which was true only until the PRD it names was approved. Status corrected 2026-08-30 |
| Recommendation | Build something smaller: a separate `conventions.explain_level` key that **swaps** the injected paragraph rather than adding one, because the always-loaded budget has 44 tokens of headroom and the rule costs 66 |
| Next | `write-prd` done: `docs/prd/plain-language-chat.md`, 2026-08-18. All four open questions are answered |

## The problem

A reader who is not a developer receives a chat reply that is now short but still assumes the
vocabulary of the thing it describes, so brevity has made it denser rather than clearer, and the
reply is the only part of keel's output aimed at them.

**Evidence.** Asserted from use by Bernard on 2026-08-18, with no instance named and no measurement.
This is the same weakness `docs/ideas/concise-responses.md` recorded against its own problem
statement, and its open question 1, "what is the actual split", is still unanswered. That question
bears harder here than it did there: length is something keel demonstrably influences, because it
ships a rule about it, whereas vocabulary is mostly set by the model, the harness system prompt and
the user's own global instructions, none of which keel can reach.

## What was asked for

> Efficiently solve the wall of text and jargon problems. See if the terse output style can be
> updated further to also consider ELI5

Narrowed by the requester the same day, and the narrowing is the most useful line on this page:

> artifacts should remain technical as they should be. the chat response is where i would like
> minimal jargon especially for non-technical vibe-coders

That resolves the largest risk in the idea before it was raised. "Wall of text" is already solved:
terse shipped, and this record is only about jargon. And it makes the change a **third dial**
alongside the two `output-styles/keel-terse.md:9` already names, not a redefinition of either.

## The case against

**Strongest argument for not building this at all: a plain reply and a technical artifact cannot
both be honest about the same work.** `output-styles/keel-terse.md:16-17` defines what a reply is
for: "The reply is a pointer, not a copy. The artifact holds the reasoning; the reply holds the
direction." A pointer works because the reader can follow it. Tell a non-technical reader, in plain
language, that the settlement package now serialises its writes, and point them at an ADR that
explains why in the vocabulary the ADR is required to use, and one of two things happens: the reply
paraphrases the artifact into something the artifact does not say, or the reader stops at the reply
and the pointer was decorative. The idea is asking the reply to serve a reader the artifacts
deliberately exclude, and that gap is not closed by word choice.

The narrowing given above is what makes this answerable rather than fatal: if artifacts stay
technical **by design**, then the plain reply is not a summary of them, it is a statement of what
changed and what needs deciding, which is what the reply already is. That is a real position. It
just needs saying out loud, because the failure mode is a reply that quietly gets less accurate.

**Second argument: it is in direct tension with terse, and terse has no arbiter for it.**
`output-styles/keel-terse.md:42-48` resolves conflicts in favour of the statement: "A reply that is
short because it omitted a skipped check is not terse, it is wrong." An explanation costs words, so
a plain-language rule pulls the opposite way from every line in the Compress list. Worse, the
Never compress list at `:30-40` is itself the most jargon-dense part of the style: "which
verifications ran", "the output of a task's `Done when:` command", "the one-line skill
announcement". Those are the audit trail, they are named there precisely because a brevity rule
would trade them away first, and a plain-language rule would trade them away for the same reason.
Any version of this must exempt them by name, exactly as terse does.

**Third argument: it does not reach subagents.** Recorded already in
`docs/ideas/concise-responses.md`: output styles do not apply to subagents, which run their own
system prompt. Every skill in keel that delegates wide reading produces a report the main thread
relays. This fixes the relay and not the source, and nothing has changed since that was written.

**Fourth argument: the always-loaded budget is nearly spent.** Measured on 2026-08-18,
`hooks/session-start` injects 1,284 characters, about 356 tokens by the validator's own estimate,
against a 250 target and a 400 hard ceiling enforced at `tests/validate-skills.sh:283-284`. The
existing brevity paragraph is 240 characters, about 66 tokens. There are 44 tokens of headroom, so a
comparable rule **added** to the hook fails the build. This is the same wall `concise-responses.md`
hit, and it has 44 tokens less room than it did then.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The reader keeps asking "what does that mean", which is one extra turn rather than a broken process. Defensible, and it is the honest answer if nobody can name an instance |
| Do it manually | One line in the user's own `CLAUDE.md`, or asking "explain that simply" when it happens | Available today, costs nothing, and targets exactly the moments it is needed rather than every reply. Does not travel with keel, and puts the burden on the reader least able to carry it |
| Buy it | Nothing available | Not a product |
| Build something smaller | One swapped paragraph, no net token cost | Recommended. See the variants table |

**Variants of building it**

| Variant | Note |
|---|---|
| A separate `conventions.explain_level` key that **swaps** the injected paragraph | Recommended, and chosen by the requester. The hook already selects one of two forms with a `case`; selecting from four costs nothing extra because each form replaces rather than appends, which is the only shape that fits in 44 tokens. Travels with the profile, so a project is configured once |
| A third value in the `response_style` enum | Rejected by the requester on 2026-08-18, and correctly: length and vocabulary are independent, so one enum cannot express both. `response_style` keeps its current two values |
| A new rule **added** to `hooks/session-start` | Rejected on measurement. 66 tokens against 44 of headroom fails `tests/validate-skills.sh:283-284` |
| A second output style, `output-styles/keel-plain.md` | Zero always-loaded cost and it is the shape `concise-responses.md` recommended for terse. Rejected as the primary: output styles are chosen one at a time in `/config`, so it would have to duplicate all of terse to avoid replacing it, and two files stating the same doctrine drift |
| A glossary reference under `skills/keel/references/` | Cheap and unbudgeted, and it pairs well with any of the above. On its own it changes nothing, because nothing would cite it on the turn that matters |
| Define each term on first use, keep the term | Recommended as the **wording**, not as a variant. It keeps the reply accurate and the reader able to follow the artifact, which is what the strongest objection above is about |
| Replace terms with lay equivalents | Rejected. It is the version that makes the reply diverge from the artifact, and it destroys the pointer |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Vocabulary is something keel meaningfully controls | Removing keel's rule changes reply vocabulary | Nobody has run the comparison. `concise-responses.md` open question 1, still open | **No, and it is the largest unknown** |
| A non-technical reader is actually receiving these replies | There is a real vibe-coder on a keel project | Asserted 2026-08-18, no instance named | **No** |
| Plain wording does not cost accuracy | Replies still name skipped checks, assumptions and deviations verbatim | The Tier 3 evals assert gate announcements and would fail if it did | No, but the check exists and is cheap to run |
| Define-on-first-use is enough | The reader can follow the artifact afterwards | Only by asking one | No |
| A third injected form keeps prompt caching intact | The output stays byte-identical per configuration | Follows from `hooks/session-start:9-14`, which bounds the hook to a fixed set of forms changed only by a deliberate edit. A third form is within that bound | Yes, by construction |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The always-loaded hook is at 356 of a 400 ceiling | Measured 2026-08-18; rule at `tests/validate-skills.sh:283-284`, budget in `docs/05-token-and-memory-design.md` | 44 tokens of headroom. The rule must swap, not add |
| The hook is deliberately bounded to a fixed set of forms | `hooks/session-start:9-14`, and it forbids anything volatile for prompt-cache reasons | A third form is allowed by that doctrine. A rule that varied per reply is not |
| `response_style` is an enum of exactly two, and stays that way | `templates/profile.schema.json:329-336` | Untouched by the chosen design. A **new sibling key** is still a schema change, so `SCHEMA_VERSION` moves and `keel doctor` reports drift on existing profiles |
| Two independent keys give four combinations, not four paragraphs' worth of tokens | The hook picks one paragraph; the set it picks from may grow without the injected size growing | The 44-token headroom survives the separate-key design. Only a rule that **appends** breaks it |
| The hook matches the profile textually with a builtin `case`, no python3 | `hooks/session-start:16-20, 70-73` | A third branch is two lines and no new dependency |
| Terse resolves its own conflicts in favour of the statement | `output-styles/keel-terse.md:42-48` | A plain rule needs the same tie-break written down, or the two rules fight silently |
| The Never compress list is the jargon-dense part | `output-styles/keel-terse.md:30-40` | Those lines must be exempted by name, exactly as terse exempts them from brevity |
| Artifacts are explicitly out of scope of the style | `output-styles/keel-terse.md:11-14` | The requester's narrowing agrees with doctrine already shipped. No artifact changes |
| Output styles do not reach subagents | Recorded in `docs/ideas/concise-responses.md` | Delegated reports stay technical. Only the main thread changes |
| The same problem statement was accepted once before without measurement | `docs/ideas/concise-responses.md`, "Asserted from use" | Accepting it twice without measuring is a choice worth making knowingly |

## Open questions

1. **Is this a profile setting or an output style?** **Answered 2026-08-18: a profile setting**,
   implied by the requester choosing a profile key. A vibe-coder is the least likely person to find
   `/config`, which is the objection `concise-responses.md` raised against opt-in and then had
   overruled.
2. **Does the plain form also apply to `verbose`?** **Answered 2026-08-18: yes, by construction.**
   The requester chose a separate key, `explain_level`, so `response_style` keeps its current enum
   and the two dials compose. `verbose` plus `plain` is a valid and reachable combination, and the
   hook must have a paragraph for it rather than falling through to silence.
3. ~~**Is anyone going to measure the split?**~~ **Answered 2026-08-18: no, and it is closed rather
   than carried forward.** The requester chose to accept the problem statement as asserted from use
   for the second time, knowingly. `docs/prd/plain-language-chat.md` records it as `A1` and its
   success metrics section says `Unknown, needs a decision` rather than inventing one. The same
   answer is now written into `docs/ideas/concise-responses.md` open question 1.
4. ~~**Does the terse eval suite cover vocabulary?**~~ **Answered 2026-08-18: it does not, and it
   will not.** The requester chose hook tests only. Nothing asserts a reply is followable by a
   non-expert, because nothing reliably can. Now `FR-12` and `NFR-02` in
   `docs/prd/plain-language-chat.md`, which assert the four combinations and the per-form token
   ceiling instead.

## Recommendation

**Build something smaller.** Add `conventions.explain_level` (`technical` by default, `plain` as
the opt-in) and have `hooks/session-start` select its paragraph from the two keys together, wording
the plain form as define-on-first-use rather than term-replacement, with the Never compress list of
`output-styles/keel-terse.md:30-40` exempted by name.

Why: the requester's narrowing removed the risky half (artifacts stay technical), a separate key
keeps `response_style` intact and lets the two dials compose, and swapping the paragraph rather than
appending one is the only shape that fits the 44 tokens left in the always-loaded hook.

Next: `write-prd` is done, at `docs/prd/plain-language-chat.md`. Both blocking questions were
answered before it, and the remaining two were answered during it. The schema bump should be costed
alongside `docs/ideas/profile-key-documentation.md`, which touches the same file.

## Not decided here

All four items here were decided on 2026-08-18 while `docs/prd/plain-language-chat.md` was written,
and the record is kept rather than deleted so the trace survives:

- ~~The wording of each paragraph~~ The `terse` plus `plain` wording is fixed by `FR-15`, measured
  at 1,283 characters against a 1,285 budget. It gives up the pointer sentence to keep the exemption
  list named item by item. The `verbose` plus `plain` wording is still open, as `Q6`.
- ~~How many distinct paragraphs the four combinations need~~ Three printed and one silent:
  `verbose` plus `technical` injects nothing, as `verbose` does today. `FR-04` to `FR-06`.
- ~~Whether a glossary reference is worth writing~~ Out of scope. It changes nothing on the turn
  that matters, because nothing would cite it.
- ~~How `keel doctor` reports the new key~~ It does not, beyond the schema drift message it already
  prints. `FR-16` and `CON-06`.
- ~~Whether the Tier 3 evals grow a case~~ No. Hook tests only, `FR-12`.
