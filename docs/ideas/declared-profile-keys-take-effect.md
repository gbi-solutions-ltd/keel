# Idea: every declared profile key either takes effect, or says it does not

| | |
|---|---|
| Raised by | Bernard, 2026-09-07, against `8919d4b` |
| Status | built 2026-09-07 via docs/plans/2026-09-07-declared-profile-keys-take-effect.md |
| Recommendation | Build something smaller than the brief proposes: correct the prose, retire six keys, wire four, declare eleven human-read, and replace the proposed matcher with a declared reader whose citation is checked |
| Next | `write-plan`. `write-prd` is deliberately skipped, which `shape-idea`'s hard gate requires be written down: this is a defect fix against a settled contract, not a new capability, and the brief names `write-plan` as the next step |

## The problem

A user setting a key in `.keel/profile.json` cannot tell, without reading keel's source, whether
anything will honour it, and 22 of the 61 declared keys will not.

**Evidence.** Measured against `templates/profile.schema.json` at `8919d4b` on 2026-09-07. The
schema declares 61 leaf keys. `CHANGELOG.md`, at "seven declared profile keys are read by nothing",
records seven. The true figure in the brief is 22, of which 14 carry a description implying
enforcement they do not have, and two are written into every new profile by `bin/keel:516` and read
nowhere, so the evidence of wiring sits in the user's own file.

**This repository already recognises the defect class.** `tests/validate-skills.sh:409` records why
the delegation check exists: the wiring map in `docs/04-plugin-strategy.md` was false in six of its
ten rows. A declared configuration key nobody reads is the same failure in a different file.

## What was asked for

> `templates/profile.schema.json` declares 61 keys. 22 have no reader anywhere in `skills/`,
> `hooks/`, `bin/` or `lib/`. 14 carry a description that implies enforcement they do not have.
> [...] For each of the 22, exactly one verdict: wire it, retire it, or declare it human-read.
> [...] The verdicts fix today. Without a mechanical rule the tree drifts back exactly as the
> delegation map did. This is the part I care most about, and it has one hard problem.

## The case against

**Strongest argument for not building this at all.** The largest share of the harm is prose, and
prose is free to fix. Fourteen false descriptions can be corrected in one regenerate-and-commit that
moves no field set, needs no eval arm and costs no body words. Once that lands, a user reading
`docs/profile-keys.md` gets a true answer for every key, which is the whole of what they were being
denied. Everything after that point is buying enforcement, and enforcement is the expensive half:
each wiring costs body words this tree does not have, each retirement moves `SCHEMA_VERSION` and
rewrites part of a released contract, and the checker is a new rule in a validator that runs on
every commit. The honest case against is that correcting the descriptions is most of the value for a
fraction of the cost, and that stopping there is defensible.

**The answer, and it is why the rest is still worth building.** Prose corrected today drifts back
tomorrow. That is the exact history of the delegation map, which three separate audits corrected and
which was false again in six of ten rows by `2026-09-02` (`tests/validate-skills.sh:409-412`). A
correction with no rule behind it has a measured half-life in this repository.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | 22 keys keep lying, and `CHANGELOG.md`, at "seven declared profile keys are read by nothing", keeps understating by a factor of three. The brief exists because a user acted on one of these descriptions |
| Do it manually | One review pass per release, by a person | This is what has happened three times to the delegation map, and it was false again each time. `CONTRIBUTING.md` reserves manual review for judgements a proxy gets wrong; "does anything read this key" is not a judgement, it is a fact |
| Buy it | No product does this | The contract is keel's own schema against keel's own tree. Nothing off the shelf knows either |
| Build something smaller | The description corrections alone, one commit | The strongest argument above. Recommended as the first task, and rejected as the whole of the work for the reason under it |

**Variants of the idea, kept out of the table above**

| Variant | Why not |
|---|---|
| Wire all 22 | Six have no mechanism that changes behaviour, and a seventh (`gates.tdd`) carries a rejection dated the same day. Wiring by adding a sentence to a skill body is the outcome the brief explicitly refuses |
| Retire all 22 | Eleven are init-detected or human-set facts a person legitimately reads. Deleting them discards real detection work in `lib/detect-stack.sh` and a runbook's only recorded address for a registry |
| A dotted-path matcher over the tree | Measured and rejected. See **What the system says**, rows 1 to 3 |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A skill body sentence that nothing asserts counts as wiring | It changes behaviour under pressure | An eval arm | **No, and the brief refuses it.** Any prose read ships labelled advisory in `docs/profile-keys.md` |
| The six `gates.*` keys are subject to ADR-0003's capability manifest | They become hook gates | Read the manifest | **Checked, and false.** The manifest's gates are `session-start`, `done-guard`, `context-watch`, `sensitive-guard`. No `gates.*` schema key appears in a `requires` row |
| `bin/keel:37`'s `SCHEMA_VERSION=3` is authoritative for a retirement | The repository's own profile is not the contract | Read both | **Checked.** See the version note below |
| A checker can distinguish a generic read from an absent one | A syntactic rule exists with no false positives | Prototype it against the tree | **Checked, and false.** See rows 1 to 3 |
| Retiring `gates.tdd` does not contradict a decision recorded on 2026-09-07 | ADR-0007 requires the key to be absent of wiring, not present in the schema | Read `ADR-0007:110-113` | **Partially.** The single verdict I want a human to confirm |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| A dotted-path matcher flags 25 of 61 leaves, and 7 of the 25 are genuinely read | Prototyped against the tree 2026-09-07. The 7: `artifacts.stories`, `.architecture`, `.decisions`, `.plans` (`bin/keel:1345-1354` iterates the map), `gates.context_warn_pct`, `.context_stop_pct` (`lib/context_watch.py:497-508`), `conventions.default_branch` (`bin/keel:1640`) | 28% false positives. `docs/standards.md:79` calls the too-strict failure the unrecoverable one, and `tests/validate-citations.sh:20-25` records a rule discarded at 70%. The matcher cannot ship |
| The bare-leaf rescue passes everything | Hit counts across `bin/keel`, `lib/`, `hooks/`, `skills/`: `name` 337, `test` 484, `build` 178, `review` 146, `security` 52, `target` 49, `tdd` 25 | Every one of the 22 dead keys would pass. This is the "reads nothing, passes everything" failure the tree has already hit twice |
| Presence of a dotted path and being read are independent facts | `hooks/done-guard:114` reads the gate as `(prof.get("gates") or {}).get("done_verified")`; the dotted string appears in that file only in comments and refusal text at `:25`, `:72`, `:111`. `conventions.protect_default_branch`'s only dotted occurrence is a refusal message at `bin/keel:1673` | Both directions of the matcher are wrong. A syntactic rule is not available at any threshold |
| Six parent-map read sites exist in code, and they are the whole set | `lib/context_watch.py:498`, `:570`, `:591`, `:726`; `hooks/done-guard:114`, `:118` | Small and enumerable, which is what makes a declared reader with a checked citation affordable |
| No `gates.*` schema key is a capability-manifest gate | `lib/harness/capabilities` carries four `requires` rows, for `session-start`, `done-guard`, `context-watch` and `sensitive-guard` | ADR-0003 binds only if a `gates.*` key becomes a hook. A `cmd_doctor` read is a CLI read and harness-neutral; a skill-prose read loads identically on both harnesses and is advisory, not a guarantee, per ADR-0004 |
| `pretooluse_ask` is Claude Code only | `lib/harness/codex.sh:5-6`, citing `codex-rs/protocol/src/permissions.rs:105` | Only a gate escalated to a human-decision hook splits by harness. None of the four wirings recommended here does |
| ADR-0007's only proposed `gates.tdd` wiring was tiering's carrier | `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:419-420`: "`required` means the tiers apply with the strict list binding". The task is stamped closed at `:382` | There is no untiered proposal to revive. The nearest shape, Alternative A, was also declined, "on reasons 2 and 3" (`ADR-0007:79-82`) |
| ADR-0007 records the key staying declared | `ADR-0007:110-113`: "`gates.tdd` stays declared and unread" | Retiring it is a change to a consequence recorded the same day. Flagged for human sign-off rather than decided here |
| `gates.coding_standards` is already shaped and ranked | `docs/ideas/standards-that-bind.md:506-510` ranks it third, at "seven words per site", behind two zero-body-word mechanisms | Defer to that record. The zero-word mechanism it ranks first already exists as a block at `skills/execute-plan/references/subagent-prompts.md:29` |
| Two keys the brief calls dead are read | `verify.test_integration` at `skills/tdd/SKILL.md:31` and `:67`; `stack.package_manager` at `bin/keel:853-856` | The tree wins. Both still carry a false description. A third, `observability.otlp_endpoint_var`, looked read at `skills/coding-standards/references/observability.md:30` and is not: that line never names the key, and the key's only shipped appearance is the illustrative JSON at `:14`, one line above `observability.log_shipping` at `:15`. Corrected 2026-09-07 during execution |
| Two keys outside the 22 are named and never branched on | `conventions.commit_style` at `skills/ship/SKILL.md:62`; `stack.also` at `skills/keel/references/tool-choices.md:21` | The same defect, found by the same census. Named here so it is not rediscovered as new |
| The `artifacts.*` map is honoured on the read side and ignored on the write side | `skills/write-plan/SKILL.md:19` checks it before reading, and `:56` hardcodes the default path when writing. Same split in `design-architecture` and `write-user-stories` | A separate defect. It would pass any checker, because `bin/keel:1345-1354` reads the map. Out of scope, recorded so it is not lost |
| `docs/profile-keys.md` is scanned for unregistered harness claims | `tests/test-harness-claims.sh:139-147` puts depth-1 `docs/*.md` in scope; `tests/generate-profile-keys.sh:139-145` carries the existing tags (two on 2026-09-07, more since) | A corrected description using the words `done-guard`, `sensitive-guard`, `context-watch`, `session-start` or `hard_block_paths` needs a `CLAIMS` entry or the build goes red |

### The version note, resolved

`bin/keel:37` declares `SCHEMA_VERSION=3` and this repository's own `.keel/profile.json` says
`schema_version 2`. **`bin/keel` is authoritative and the profile is a stale artifact.**
`tests/validate-skills.sh:695-699` fingerprints the schema document against
`schema_fingerprint_for`, which carries a line for 3 at `:86`, and the suite is green, so the
schema and the constant agree. The repository's own profile is hand-written, says so at its own
`_note` ("keel dogfoods itself. Written by hand until `keel init` exists"), and is exactly what
`bin/keel:1534`'s doctor warning exists to catch. `keel_version 0.15.0` against `VERSION` `0.18.0`
is the same staleness in the same file.

Neither is fixed by this work. Both are one command, `keel init`, and a version bump landing inside
an unrelated change is how a released version's record gets rewritten.

**A second instance of that rule, which the brief did not anticipate.** The `CHANGELOG.md` line at
"seven declared profile keys are read by nothing" is inside the `## 0.11.0 - 2026-08-18` section.
Rewriting "seven" there rewrites a released version's record, which is the sin the brief names for
`SCHEMA_VERSION`. The true count belongs in `## Unreleased`, and the live present-tense restatements
at `ADR-0007:111` and `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md:524` get a dated
appended line rather than an edit.

## Open questions

1. **Does retiring `gates.tdd` contradict `ADR-0007:110-113`?** The ADR records that wiring does not
   happen; it does not say the key must exist. The argument for retiring is that an ADR is where
   intent lives and a schema is a contract of what takes effect, and "declared so the intent has
   somewhere to live once something enforces it" is the sentence that produced this whole defect
   class. The argument against is that a consequence recorded on 2026-09-07 should stand longer than
   a day. **This is Bernard's call and the plan does not assume it.** If the answer is no, the
   verdict falls back to class A, honestly dead, and the description stays as it is, which is true.
2. **Do `deploy.target`, `.ci` and `.envs` deserve a `cmd_doctor` read?** A warning when `deploy.ci`
   is null and a CI config exists in the tree is cheap, testable and harness-neutral. It is also
   speculative: nobody has asked for it, and `keel init` already detects `ci` at
   `lib/detect-stack.sh:220`. Recommended against, and named so the decision is on the record.
3. **Does `notes` survive as human-read, or is it dead?** `verify_notes` has an unambiguous
   person-facing job. `notes` was written for a skill to read, no skill can afford to read it
   (SessionStart has 4 characters of headroom against the 1,285 limit at
   `tests/validate-skills.sh:522`), and the honest alternative is retirement. Recommended as
   human-read with a description that says plainly no skill reads it.

## Recommendation

**Build something smaller than the brief proposes, in the brief's own order.** Correct the fourteen
false descriptions first and alone; then build the rule; then wire four keys and retire six. Eleven
become declared human-read, which the schema cannot currently express and which is why they are
today indistinguishable from the ones that lie.

**Replace the proposed checker.** A dotted-path matcher was prototyped and measured at 28% false
positives, and the bare-leaf fallback passes all 22 dead keys. In its place: a declared reader on
each schema entry whose citation the validator checks, modelled on `lib/harness/capabilities`, whose
own rule is that absent evidence fails and never passes (`lib/harness/capabilities:88-89`). It is
the mechanism the brief anticipated as "a worse mechanism and an honest one", and the citation check
gives it teeth the brief did not assume.

**Next: `write-plan`.** No PRD: this is a defect fix against a contract that already exists, and the
brief names the plan as the deliverable. Recorded here because `shape-idea`'s hard gate requires a
skipped step be written down.

## Not decided here

The per-key verdict table and its evidence, which belongs to the plan. Whether `ship` should become
configurable at all, which is the question behind `gates.review` and `gates.docs_updated` and which
nobody has raised. The `artifacts.*` write-side gap. `conventions.commit_style` and `stack.also`,
which are the same defect outside this brief's 22. Anything about `keel_version` or
`SCHEMA_VERSION` beyond establishing which is authoritative.
