# PRD: plain language in chat replies

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Bernard, with Claude |
| Date | 2026-08-18 |
| Derived from | `docs/ideas/plain-language-chat.md` and `docs/ideas/concise-responses.md`, at `f9cdb03`, and this conversation |
| Approved by | Bernard, 2026-08-18 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

## 1. Executive summary

keel's chat replies are short, because `hooks/session-start` injects a brevity rule into every
session. They are also written for a developer, because nothing tells them not to be, and the reply
is the only part of keel's output aimed at a reader who is not one. This PRD covers one new profile
key, `conventions.explain_level`, with values `technical` and `plain`, and the change to
`hooks/session-start` that selects its injected paragraph from that key and `response_style`
together. It is for anyone running keel on a project where a non-technical person reads the replies,
and it matters now because the always-loaded block has 44 tokens of headroom, which is little enough
that the shape of this change is decided by the budget rather than by preference.

Artifacts are untouched. A PRD, a plan, an ADR or a review stays exactly as technical as its skill
requires, which is the requester's own narrowing and the thing that makes the rest of this document
answerable.

## 2. Problem statement

A reader who is not a developer receives a keel reply that is now short but still assumes the
vocabulary of the thing it describes. Brevity made it denser rather than clearer. That reader has
one recourse, which is to ask what a term meant, and that is one extra turn rather than a broken
process.

**The evidence is an assertion, not a measurement, and this is the second time it has been
accepted as one.** Bernard raised it from use on 2026-08-18 with no instance named and no numbers.
The same weakness was recorded against `docs/ideas/concise-responses.md` on 2026-08-16, whose open
question 1, "what is the actual split", went unanswered through the terse rollout. On 2026-08-18 the
requester closed that question rather than carrying it forward: nobody is going to measure whether
keel meaningfully moves reply vocabulary at all. That decision is recorded here as `A1` and is why
section 9 says `Unknown, needs a decision` instead of a target.

The question bears harder here than it did for length. Length is something keel demonstrably
influences, because it ships a rule about it. Vocabulary is mostly set by the model, the harness
system prompt and the user's own global instructions, none of which keel can reach.

## 3. Goals and non-goals

**Goals**

- A project can be configured once so that its chat replies define the technical terms they use,
  without any reader having to find `/config` or ask per turn.
- The two dials stay independent: how long a reply is and what vocabulary it assumes are separate
  choices, and all four combinations are reachable and configured.
- The always-loaded injection does not grow. The headroom that exists today still exists after
  this change.
- The audit statements keel's gates depend on stay verbatim, whichever combination is configured.

**Non-goals**

- Making artifacts readable by a non-technical reader. They stay technical by design.
- Making delegated subagent reports plain. Nothing in this change reaches them.
- Deciding what "plain" means well enough to assert it automatically.
- Establishing whether keel influences reply vocabulary at all. See `A1`.

## 4. Users and personas

| Who | What they want | What they know |
|---|---|---|
| A non-technical person reading keel's replies, the "vibe-coder" of the request | To know what changed and what needs deciding, without looking a term up | The problem domain. Not the stack, not keel's own vocabulary |
| The developer who set the project up | To flip one key and have it travel with the repository | The profile exists and is editable |
| Everyone else, on `technical` | Nothing to change | Today's behaviour, unchanged byte for byte |

The third row is a requirement, not a courtesy. `technical` is the default, and a project that never
sets the key gets exactly the injection it gets today.

## 5. Functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | `templates/profile.schema.json` must declare `conventions.explain_level` as an enum of exactly two values, `technical` and `plain`, with default `technical` and a description. | confirmed | Requester chose a separate key on 2026-08-18, `docs/ideas/plain-language-chat.md` open question 1 |
| FR-02 | `conventions.response_style` must keep its current enum of exactly two values, `terse` and `verbose`, unchanged by this work. | confirmed | Requester rejected a third enum value on 2026-08-18; `templates/profile.schema.json:355-362` |
| FR-03 | `keel init` must write `"explain_level": "technical"` into `conventions` in a newly created profile. | confirmed | Requester, 2026-08-18, this conversation. Matches the `response_style` precedent at `bin/keel:387` |
| FR-04 | `hooks/session-start` must select its injected paragraph from `response_style` and `explain_level` together, so that each of the four combinations produces one determined output. | confirmed | Requester, 2026-08-18. Today the selection reads one key, `hooks/session-start:70-73` |
| FR-05 | The combination `verbose` plus `technical` must inject no paragraph, exactly as `verbose` does today. | confirmed | `hooks/session-start:71`, and the measured 300-token verbose form |
| FR-06 | The combination `verbose` plus `plain` must inject a paragraph rather than falling through to silence. | confirmed | `docs/ideas/plain-language-chat.md` open question 2, answered 2026-08-18 |
| FR-07 | Each injected plain paragraph must word the rule as defining a technical term on first use, and must not instruct the reply to replace a term with a lay equivalent. | confirmed | Requester's narrowing, 2026-08-18. Term replacement is what makes the reply diverge from the artifact it points at |
| FR-08 | Each injected plain paragraph must name the statements that are never compressed: which verifications ran and which were skipped, assumptions, deviations, and a task's `Done when:` output. | confirmed | `output-styles/keel-terse.md:30-40`, which exempts the same list from brevity for the same reason |
| FR-09 | An absent, unreadable, or unrecognised `explain_level` must yield `technical`, and must not prevent the router pointer being injected. | confirmed | The existing failure mode at `hooks/session-start:60-73`, and the `-r` test at `:69` added after review |
| FR-10 | The selection must be a textual `case` match tolerating both `"explain_level": "plain"` and `"explain_level":"plain"`, with no new interpreter dependency. | confirmed | `hooks/session-start:16-20`, which forbids `python3` in this hook |
| FR-11 | `bin/keel`'s `SCHEMA_VERSION` must move to 2, and `schema_fingerprint_for` in `tests/validate-skills.sh` must gain a line for version 2 in the same commit, leaving the version 1 line unedited. | confirmed | `tests/validate-skills.sh:53-70, 434-439`, which fails the build otherwise |
| FR-12 | `tests/test-session-start.sh` must assert all four combinations, each by which paragraph it injects. | confirmed | Requester chose hook tests only, 2026-08-18. Today it asserts three cases at `:68-76` |
| FR-13 | `docs/profile-keys.md` must contain a row for `conventions.explain_level`, produced by `tests/generate-profile-keys.sh` rather than written by hand. | confirmed | `tests/test-profile-keys.sh:31-46`, which fails when a declared key has no row |
| FR-14 | No skill, output style, or artifact template may change what it writes as a result of this work. | confirmed | Requester's narrowing, 2026-08-18; `output-styles/keel-terse.md:11-14` |
| FR-15 | The `terse` plus `plain` paragraph must omit the pointer sentence, "Say what changed, where it is, and what needs a decision", must keep the four exempted statements of `FR-08` named item by item, and must state that artifacts stay full as well as technical. | confirmed | Requester, 2026-08-18, choosing between three measured wordings. See the note below the table |
| FR-16 | `keel doctor` must produce no output about `explain_level` beyond the schema version drift message it already prints. | confirmed | Requester, 2026-08-18. `CON-06` and `bin/keel:1404` are the whole mechanism |
| FR-17 | The `verbose` plus `plain` paragraph must state the plain rule and the four exempted statements of `FR-08`, and must omit the pointer sentence, the same trade `FR-15` makes. | confirmed | Measured 2026-08-18. It is the only candidate satisfying `FR-07`, `FR-08` and `NFR-01` together |

**The wording `FR-07`, `FR-08` and `FR-15` together fix**, measured through the hook on 2026-08-18
at 1,283 characters and 356 tokens, 2 characters inside the `NFR-01` budget:

```
Replies stay brief and plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
```

This is a requirement rather than a design note because it is what the 203 characters buy, and the
requester chose it over the two alternatives that also fit or nearly fit: collapsing the exemption
list to a single unnamed category, and raising `NFR-01` to keep both sentences. The cost is stated
plainly: a `plain`-configured project gets the brevity rule without the content instruction that
`output-styles/keel-terse.md:16` calls the pointer. The exemption list survives intact, because it
is what stops a wording rule trading the audit trail away first.

**The `verbose` plus `plain` wording `FR-17` fixes**, measured at 1,273 characters and 353 tokens,
12 inside budget:

```
Replies stay plain; artifacts full and technical. Define a technical term on first use.
Never omit which checks ran or were skipped, assumptions, deviations, or a Done when command's output.
```

Having no brevity rule to state does not buy back the pointer sentence. That wording was measured
at 1,309 characters, 24 over, and a version keeping both sentences at 1,331, 46 over. So both plain
forms make the same trade, which is at least consistent: `plain` costs the pointer sentence
whichever length dial it is paired with.

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | No combination of `response_style` and `explain_level` may produce an injection larger than 1,285 characters, which is 356 tokens by the estimate `tests/validate-skills.sh:282` uses. | confirmed | Requester chose this ceiling over the 400 hard limit, 2026-08-18. 1,284 characters is what `terse` costs today, measured 2026-08-18 |
| NFR-02 | `tests/validate-skills.sh` must apply the size check to every combination, not only to the one the repository's own profile happens to select. | confirmed | `tests/validate-skills.sh:281` runs the hook once from the repository root, so it measures `terse` plus `technical` and nothing else |
| NFR-03 | The hook's output must stay byte-identical for a given profile, changing only when a person edits the profile. | confirmed | `hooks/session-start:4-14`. A fourth form is within the bound that comment sets; a value read for its content would not be |
| NFR-04 | The hook must continue to run with no interpreter beyond the shell, and must exit 0 with the router pointer on stdout for any profile it cannot read. | confirmed | `hooks/session-start:16-20, 62-69` |
| NFR-05 | `docs/05-token-and-memory-design.md` must state the measured size of each of the four forms, replacing the two figures it carries today. | confirmed | `docs/05-token-and-memory-design.md:272-278`, which is the record of the tightest budget in the project |

**On NFR-01, and it is the sharpest thing in this document.** The verbose base injection measures
1,082 characters. The ceiling is 1,285. That leaves **203 characters** for the selected paragraph.
The brevity paragraph shipping today occupies 202 of them. So a `terse` plus `plain` paragraph, which
has to state the brevity rule, the define-on-first-use rule and the exemption list of `FR-08`, gets
one character more than the paragraph that states only the first and the third. Wording is
therefore the binding constraint here, not implementation. Three candidates were measured through
the real hook on 2026-08-18: 1,292 characters shortening nothing, 1,323 keeping both sentences in
full, and 1,283 for the wording `FR-15` fixes, after review restored the words "artifacts full" that
an earlier draft of it had dropped. The last one fits, so `NFR-01` holds at 356 and the 44 tokens of
headroom survive.

## 7. Constraints

| ID | Constraint | Imposed by | Evidence |
|---|---|---|---|
| CON-01 | The always-loaded injection has a 400-token hard ceiling, and the build fails above it. | `docs/05-token-and-memory-design.md`, enforced in CI | `tests/validate-skills.sh:283-284` |
| CON-02 | The rule must swap the injected paragraph, never append one. An added rule of comparable size costs about 56 tokens against 44 of headroom. | Arithmetic on CON-01 | Measured 2026-08-18: `terse` 1,284 characters, `verbose` 1,082, a 202-character difference |
| CON-03 | `response_style` stays an enum of exactly two values. | The requester, 2026-08-18 | `docs/ideas/plain-language-chat.md`, variants table |
| CON-04 | Artifacts stay technical. No PRD, plan, ADR, snapshot, runbook, review or audit changes vocabulary. | The requester, 2026-08-18 | `output-styles/keel-terse.md:11-14` already says the same for length |
| CON-05 | Output styles and SessionStart context do not reach subagents, which run their own system prompt. Delegated reports stay technical whatever this key says. | Claude Code | Recorded in `docs/ideas/concise-responses.md` |
| CON-06 | Adding a declared key to the profile schema forces a `SCHEMA_VERSION` bump, and every existing profile then reports drift until `keel init` is re-run. | `tests/validate-skills.sh`, and `bin/keel` doctor | `tests/validate-skills.sh:390, 434-439`; the drift message at `bin/keel:1404` |
| CON-07 | Nothing in the injected text may be volatile. A rule whose wording varied per reply, per date or per branch would cost the prompt cache on every request. | `hooks/session-start:4-8` | The comment block that opens the hook |

`CON-06` also settles a question the idea record left undecided: `keel doctor` needs no new code for
this key. It already reports a schema version older than the installed keel, and tells the user to
re-run `keel init`, which merges. That message is how the new key reaches an existing project.

## 8. Observed but not required

Not applicable, because this is `from-idea` mode. Nothing is being reverse-engineered from a
running system.

## 9. Success metrics

`Unknown, needs a decision`, and deliberately so.

The requester decided on 2026-08-18 that nobody will measure whether keel influences reply
vocabulary, closing a question open on `docs/ideas/concise-responses.md` since 2026-08-16. Without
that baseline there is no honest number to put here: any target would be measured later against a
mechanism nobody has shown works. Inventing one would be worse than leaving it empty, because a
fabricated metric gets quoted.

What is verifiable is the mechanism, not the outcome, and that is what section 5 and section 6
assert: the key exists, the four combinations each inject a determined paragraph, none of them grows
the always-loaded block, and the audit statements survive in all four.

## 10. Milestones

No deadline was given and none is implied, so the date is `Unknown, needs a decision`.

**The sequencing constraint this section claimed does not exist, and the correction is recorded
rather than quietly removed.** When this PRD was approved it said the `SCHEMA_VERSION` bump would be
shared with `docs/ideas/profile-key-documentation.md`, and the requester chose one bump for both on
that basis. Checked on 2026-08-18 before planning: that work shipped in PR #29 as
`docs/prd/usable-profile.md`, and it deliberately moves nothing. Its `CON-01` records why, because
the validator fingerprints key paths and not descriptions, so writing 35 descriptions is free; and
its `Q2` chose to leave `artifacts._note` undeclared precisely to avoid paying for a bump.

So this work carries the bump to version 2 on its own, because `explain_level` adds a key path and
that does trip the fingerprint. There is nothing to wait for and nothing to couple to. One drift
report reaches existing profiles either way, which is the outcome the requester was choosing for.

## 11. Out of scope

| Excluded | Why |
|---|---|
| A glossary reference under `skills/keel/references/` | Cheap and unbudgeted, and it changes nothing on the turn that matters, because nothing would cite it. It pairs with this work rather than being part of it |
| A second output style, `output-styles/keel-plain.md` | Output styles are chosen one at a time in `/config`, so it would have to duplicate all of terse to avoid replacing it, and two files stating the same doctrine drift |
| A third value in the `response_style` enum | `CON-03`. Length and vocabulary are independent, so one enum cannot express both |
| Replacing technical terms with lay equivalents | `FR-07`. It is the version that makes the reply diverge from the artifact it points at, which destroys the pointer |
| Any change to artifacts | `CON-04` |
| Any change to subagent reports | `CON-05`. This fixes the relay, not the source |
| A Tier 3 eval for vocabulary, or a term blocklist | The requester chose hook tests only on 2026-08-18. There is no agreed definition of plain to assert against, and a judged eval would fail for the wrong reasons |
| Measuring the vocabulary split | `A1`, closed on both idea records on 2026-08-18 |

## 12. Assumptions

These come from the assumptions table in `docs/ideas/plain-language-chat.md`. Each is written so it
can be shown false.

| ID | Assumption | False if | Checked |
|---|---|---|---|
| A1 | Reply vocabulary is something keel meaningfully influences. | Removing keel's injected paragraph leaves reply vocabulary unchanged | **No, and it is the largest unknown.** Closed unmeasured by the requester, 2026-08-18 |
| A2 | A non-technical reader is actually receiving these replies on a real keel project. | No such reader exists on any project using keel | **No.** Asserted from use 2026-08-18, no instance named |
| A3 | Defining a term on first use leaves the reader able to follow the artifact the reply points at. | The reader stops at the reply, or follows the pointer and cannot read the artifact | **No.** Only answerable by asking one |
| A4 | Plain wording costs no accuracy, because `FR-08` keeps the audit statements verbatim. | A plain-configured session omits a skipped check, an assumption, a deviation, or a `Done when:` output | Not yet, and `FR-12` is the check |
| A5 | The plain rule can be stated, with its exemptions, inside the 203 characters `NFR-01` leaves. | No wording satisfying `FR-07` and `FR-08` fits | **Yes**, measured 2026-08-18 at 1,283 characters against a 1,285 budget, once `FR-15` gave up the pointer sentence |
| A6 | A fourth injected form keeps prompt caching intact. | The hook's output varies for an unchanged profile | Yes, by construction. `hooks/session-start:9-14` bounds the hook to a fixed set of forms |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Which sentence gives, when no wording satisfying `FR-07` and `FR-08` fits in 203 characters?~~ Answered 2026-08-18: the pointer sentence gives, the exemption list stays named item by item, and `NFR-01` is not raised. Now `FR-15`. | Closed | NFR-01, FR-07, FR-08 |
| Q2 | ~~Does `keel doctor` say anything about `explain_level` beyond the existing schema drift message?~~ Answered 2026-08-18: no. Now `FR-16`. | Closed | Section 7 |
| Q3 | ~~Does this land in the same commit as `docs/ideas/profile-key-documentation.md`'s schema change?~~ **Void, 2026-08-18.** The question had a false premise: that work shipped in PR #29 and moves no schema version, so there is no second bump to share. This work bumps alone. Section 10 records it. | Void | Milestones |
| Q7 | ~~Since this work pays for a `SCHEMA_VERSION` bump regardless, does `artifacts._note` get declared in the same bump?~~ **No, 2026-08-18, and it stays out of scope.** `docs/prd/usable-profile.md` left it undeclared for two reasons and only one was cost. The other, recorded at `tests/test-profile-keys.sh:49-50`, is that it is a note to the reader rather than a key anyone sets, so documenting it as a setting would be wrong at any price. Overrule this if the free bump is worth more than the accuracy of the generated page. | Closed, overrulable | Nothing here |
| Q6 | ~~What wording does the `verbose` plus `plain` form take?~~ Answered 2026-08-18 by measurement, not preference: only one candidate satisfies `FR-07`, `FR-08` and `NFR-01` together, and it makes the same trade as `FR-15`. Now `FR-17`. | Closed | FR-06 |
| Q4 | ~~Is anyone going to measure the vocabulary split?~~ Answered 2026-08-18: no, closed on both idea records. Recorded as `A1`. | Closed | Section 9 |
| Q5 | ~~Does the eval suite grow a case for vocabulary?~~ Answered 2026-08-18: no, hook tests only. Recorded as `FR-12`. | Closed | Section 11 |
