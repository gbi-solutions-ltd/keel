# PRD: keel profile sync

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Claude, in session with Bernard |
| Date | 2026-08-30 |
| Derived from | `docs/ideas/snapshot-records-its-own-path.md`, and this conversation, at commit `7633035` |
| Approved by | Bernard, 2026-08-30 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

Of the 16 functional requirements below, **7 were stated or ruled on by Bernard** (FR-01, FR-03,
FR-04, FR-06, FR-10, FR-12, FR-13) and 9 are derived from the code or from the idea record. FR-06 and
FR-12 **were author-added**, nobody asked for them, and both were put to Bernard as one question and
kept on 2026-08-30. Their rows say so, because a requirement that was invented stays cheaper to
delete than one that was requested.

## 1. Executive summary

`.keel/profile.json` carries an `artifacts` map naming where a project's documents live. Six keys,
and on this repository all six are null while `docs/` holds 5 PRDs, 5 story sets, 3 ADRs and 14
plans. Nothing fills them, because every skill that writes a document writes it and moves on.

This adds one command, `keel profile sync`, that fills the artifact keys whose default location is
unambiguous and present on disk, and one line in `keel doctor` that reports the gap and names the
command. It costs no skill words, which is why it was chosen over a line in five skill bodies:
`write-plan` is three words from ADR-0001's ceiling and cannot take one.

It is for anyone running keel on a repository that already holds its documents. It matters now
because `artifacts.snapshot` acquired its first reader on 2026-08-30, so the keys have gone from
decoration to something a skill acts on.

## 2. Problem statement

A skill writes its artifact and leaves the profile key that names it null, so the profile never
learns the document exists. The cost lands on the next session rather than the one that did the
work.

**Evidence.** This repository, measured 2026-08-30. All six `artifacts` keys are null. `docs/`
holds 5 PRDs, 5 story sets, 3 decision records and 14 plans. The key has existed here for fourteen
weeks and nobody has set one by hand, though `keel profile set artifacts.snapshot docs/snapshot.md`
has worked the whole time, proven on a scratch fixture 2026-08-29.

**What it costs, now that a reader exists.** `write-prd`'s `from-repo` mode reads
`profile.artifacts.snapshot` before falling back to the default. A repository whose snapshot is at a
non-default path and whose key is null gets the fallback, finds nothing, and is sent to
`repo-snapshot` to write a second snapshot beside the one it already has. That is the duplication
the map exists to prevent.

## 3. Goals and non-goals

**Goals**

- A repository that already holds its documents can make its profile true in one command.
- Anyone who has not run that command finds out that they need to, from a tool they already run.
- No skill body pays for it, in words or in compliance risk.

**Non-goals**

- Filling every artifact key. Three of the six cannot be filled truthfully. See FR-04.
- Deciding where a document belongs. `sync` records what is there; it never moves or creates one.
- Editing the profile from `doctor`. See CON-02.

## 4. Users and personas

Two, and neither is a new audience.

**A developer on a repository that predates keel, or predates this key.** They run `keel doctor`
because something feels off, or out of habit before shipping. They learn the command exists from
doctor's output and nowhere else, which is why FR-10 is part of this work rather than a follow-up.

**A skill, reading the map.** `write-prd` at `SKILL.md:28` and `:31`, `write-user-stories` at
`:18`, `design-architecture` at `:25`, `write-plan` at `:19`, `repo-snapshot` at `:41`. They do not
run `sync`; they are why its output has to be a path that resolves.

## 5. Functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | `keel profile sync` must exist as a third subcommand of `keel profile`, beside `get` and `set`. | confirmed | Bernard, 2026-08-29, asked as a choice. Recorded as the chosen variant in the idea record |
| FR-02 | `sync` must never overwrite a key that already holds a value. | inferred | The map is documented as a user's override, `templates/profile.schema.json` `artifacts.description`. Overwriting one discards a deliberate choice |
| FR-03 | `sync` must fill only `snapshot`, `decisions` and `plans`. | confirmed | Bernard, 2026-08-30, asked as a choice. These are the three whose default is a single unambiguous location |
| FR-04 | `sync` must never fill `prd`, `stories` or `architecture`, and must say why when it skips them. | confirmed | Bernard, 2026-08-30, same choice. Their defaults are per-slug files, `<docs_root>/prd/<slug>.md` at `skills/write-prd/SKILL.md:74`, and this repository holds 5. There is no one path to write |
| FR-05 | `sync` must write a key only when its default location exists on disk. | inferred | `bin/keel:1334` fails doctor on a mapped path that does not exist, so writing an absent path converts a silent gap into a hard failure |
| FR-06 | A directory default must count as present only when it holds at least one file that `keel init` did not scaffold. | confirmed, was author-added | An empty `docs/decisions/` means the project has no decision records. Setting the key would be literally true, useless to every reader, and would silence FR-10's warning for a directory with nothing in it. Invented by the author, put to Bernard as a choice and kept, 2026-08-30. **Amended 2026-08-30 while planning, asked as a choice:** `keel init` writes `<docs_root>/decisions/ADR-0000-template.md`, so the directory is never empty on a fresh project and the first form of this requirement would have set the key and warned on every one of them. Measured on a scratch init the same day |
| FR-07 | `sync` must be idempotent: a second run against an unchanged tree writes nothing and says so. | inferred | Named as a property of the chosen variant in the idea record's variants table |
| FR-08 | `sync` must report each key it filled and the path it wrote, and report when it filled none. | inferred | A command that edits a tracked file silently is not reviewable. `keel init` prints what it wrote, `bin/keel:931` |
| FR-09 | A written path must be relative to the repository root. | inferred | `bin/keel:1334` tests `[ -e "$path" ]` with the working directory at the repository root, so an absolute path would resolve on one machine only |
| FR-10 | `keel doctor` must warn, never fail, on an artifact key that is null while its default location is present, and must name `keel profile sync` in the message. | confirmed | Bernard, 2026-08-29, as part of the same decision: doctor's report is how anyone learns the command exists. Shape follows the `stack.has_ui` precedent at `bin/keel:1390` |
| FR-11 | Doctor's warning must cover only the keys `sync` can fill. | inferred | A warning whose named remedy does not apply is noise. `prd`, `stories` and `architecture` have no remedy under FR-04 |
| FR-12 | `keel --help` must list `sync` on the `profile` line. | confirmed, was author-added | `bin/keel:1881` documents `get` and `set` there. An undocumented subcommand is discoverable only from doctor's warning, which a user reaches only if their tree already has the gap. Invented by the author, put to Bernard as a choice and kept, 2026-08-30 |
| FR-13 | In a monorepo, `snapshot` must stay null when only `snapshot-<unit>.md` files exist and `snapshot.md` does not. | confirmed | Bernard, 2026-08-30. Settles the idea record's open question 2. `skills/repo-snapshot/SKILL.md:88` emits one file per unit, and the key is `["string","null"]` in the schema, so it cannot hold them |
| FR-14 | `sync` must refuse, with the existing messages, where there is no `.keel/profile.json` or no `python3`. | inferred | `cmd_profile` already does this for `get` and `set` at `bin/keel:1019-1020`, and `sync` enters through the same function |
| FR-15 | `sync` must read the documents' location from `docs_root`, not from a hardcoded `docs/`. | inferred | `docs_root()` at `bin/keel:278` exists because the root is configurable, and `bin/keel:307` treats a mis-set one as a real failure mode |
| FR-16 | `sync` must exit non-zero only on a real error, never because it filled nothing. | inferred | Filling nothing is the correct outcome on a repository whose keys are already set, which is the state FR-07 requires a second run to reach |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | `sync` must add no dependency beyond what `keel profile` already requires. | inferred | `cmd_profile` already hard-requires `python3` at `bin/keel:1020`. Three existence checks and one JSON write need nothing else |
| NFR-02 | `sync` must write the profile through the same path as `keel profile set`, so the file's formatting is unchanged relative to that command. | inferred | `profile_set` at `bin/keel:973-1017` is the existing writer, and two writers producing different formatting would show up as spurious diffs |
| NFR-03 | Doctor's added check must not measurably slow `keel doctor --fast`. | inferred | `--fast` exists because the full run takes minutes. Three `[ -e ]` tests are free, but the check must sit where `--fast` still reaches it, since a fast run is where most people will meet it |

## 7. Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-01 | No new writer may be built. `profile_set` refuses a dotted path not already in the file, `bin/keel:990-998`, and all six `artifacts.*` keys are seeded by `write_profile` at `bin/keel:445-448`, so all six are settable today. | The existing code. This is a wiring change, not a feature |
| CON-02 | `keel doctor` must not edit the profile. | Decided in the idea record, 2026-08-29. Doctor is a diagnostic; users run it to find out what is wrong, not to have a tracked file rewritten under them |
| CON-03 | No skill body may gain a word for this. | ADR-0001 and measurement. `write-plan` is 897 words against a 900 ceiling, so the per-skill variant fails `tests/validate-skills.sh` outright. This constraint is the entire reason the command was chosen |
| CON-04 | No `PostToolUse` hook. | Decided in the idea record. keel holds its hook budget to 400 tokens, `tests/validate-skills.sh:362-366`, and this event happens a few times per repository |
| CON-05 | The `artifacts.*` schema stays `["string","null"]`. | Bernard, 2026-08-30, implied by choosing the narrow option over growing an array. Revisiting it is what FR-04's three keys would need |

## 8. Observed but not required

Not applicable: `from-idea` mode. The command does not exist yet, so there is no behaviour to
classify. The one piece of existing behaviour worth naming is in Assumptions, A3.

## 9. Success metrics

Measured on this repository, which is the one with the documented gap.

| Metric | Now | After | Source |
|---|---|---|---|
| Artifact keys that are null while their default is present and fillable | 2 of 3 (`decisions`, `plans`) | 0 | `keel doctor` on this repository |
| Keys `sync` fills here on a first run | n/a | 2 | `docs/decisions/` holds 3 files, `docs/plans/` holds 14 |
| Keys `sync` fills here on a second run | n/a | 0 | FR-07 |

**`snapshot` stays null on this repository, and that is the correct outcome, not a shortfall.**
`docs/snapshot.md` does not exist here: `repo-snapshot` has been run against other repositories but
its output was never committed to this one. The idea record's headline, six keys and six nulls, is
true, but only two of them are fillable today.

## 10. Milestones

`Unknown, needs a decision.` None were given, and this is small enough that a date would be noise.

## 11. Out of scope

- **Filling `prd`, `stories` and `architecture`.** FR-04. Reopening it means growing the schema to
  an array and changing both consumers, which today read the key as one path.
- **Any change to what a skill writes or where.** `sync` records; it never moves a document.
- **Running `sync` automatically from `keel init`.** A fresh `init` has no documents to find, so it
  would fill nothing on the one occasion it ran.
- **Reporting a mapped path that has gone stale.** Doctor already fails on it, `bin/keel:1335`.

## 12. Assumptions

| ID | Assumption | Falsified if |
|---|---|---|
| A1 | A repository whose documents sit at the default location benefits from the key being set, even though every consumer already falls back to that same default. | Someone shows a consumer where a set key and an unset key behave identically forever. The value is that doctor then validates the path, and that a later move is caught |
| A2 | Users run `keel doctor` often enough for FR-10 to be the discovery route. | Nobody reaches the warning. There is no measurement of doctor invocation, so this is the assumption most likely to be wrong |
| A5 | Nothing else `keel init` scaffolds can be mistaken for a document. | A second scaffolded file appears under a fillable key's default directory. Checked 2026-08-30: a fresh init creates `architecture/`, `audits/`, `ideas/`, `plans/`, `port/`, `prd/`, `runbooks/` and `stories/` empty, plus `README.md` and `prompting.md` at the root of `docs_root` where no key looks. `decisions/ADR-0000-template.md` is the only one, which is what makes FR-06's amendment a name rather than a list |
| A3 | Setting a key is safe once set. | A user deletes a stale document and gets a red doctor about a key they did not set by hand. This is a real cost, accepted in the idea record 2026-08-29, and FR-06 narrows it by not setting a key for an empty directory |
| A4 | `docs_root` is the only configurable part of a default location. | A project configures per-artifact subdirectory names. Nothing supports that today |

## 13. Open questions

| # | Question | Owner | Blocks |
|---|---|---|---|
| ~~Q1~~ | ~~Are FR-06 and FR-12 wanted? Both are author-added.~~ **Answered 2026-08-30 by Bernard, asked as a choice: keep both.** Their rows keep the `was author-added` mark so the trace survives | Closed | Nothing |
| Q2 | Does `sync` warrant its own test fixture, or do the existing profile fixtures cover it? | `write-plan` | Nothing here |
| Q3 | If `prd`, `stories` and `architecture` are ever to be covered, does the schema grow an array or do those keys get retired? | Nobody yet | Nothing here. Recorded so the FR-04 decision keeps its trace |

~~Q4~~ **What does a monorepo write?** **Answered 2026-08-30 by Bernard, asked as a choice: the key
stays null.** Now `FR-13`. This was open question 2 in the idea record.

~~Q5~~ **Should doctor report a null key whose default exists?** **Answered 2026-08-29 by Bernard,
as part of the decision to build a command rather than a skill line: yes, and it names the
command.** Now `FR-10` and `FR-11`. This was open question 3 in the idea record.
