# Idea: a produced artifact records its own path in the profile

| | |
|---|---|
| Raised by | Bernard, 2026-08-29 |
| Status | agreed, built 2026-08-30 |
| Recommendation | Build something smaller: wire a reader first, then a `keel profile sync` command that costs no skill words. Chosen by Bernard, 2026-08-29 |
| Next | nothing. Both halves landed 2026-08-30 in PRs #52 and #51, see below |

## The problem

A skill writes its artifact and leaves the profile key that names it null, so `.keel/profile.json`
never learns that the document exists. This lands on the next session rather than the one that did
the work, every time an artifact is produced.

**Evidence.** This repository, 2026-08-29. `repo-snapshot` has been run against real repositories
(`tests/evals/results.md:261-262` says so, and says it is the only evidence those three skills have),
and `.keel/profile.json:74` still reads `"snapshot": null`. So do `prd`, `stories`, `architecture`,
`decisions` and `plans`, on a repository that has 16 idea records, 12 plans, 3 ADRs and a full
`docs/` tree. **Six keys, six nulls, on the repository that dogfoods the tool.**

## What was asked for

> Running the snapshot should update the profile.json and point to the generated snapshot file

## The case against

**Strongest argument for not building this at all: `artifacts.snapshot` is a key that nothing
reads, and writing the default path into it changes no behaviour while creating a new way for
`keel doctor` to go red.** The map is documented as an override, not a record. `.keel/profile.json:73`
says "Set any of these to a path when the artifact already exists **elsewhere**", and
`templates/profile.schema.json:180-183` repeats it: "Where an artifact already lives, when it is not
under `docs_root`". A snapshot written at `<docs_root>/snapshot.md` is at the default, so every
consumer already finds it by falling back. Grepped across `skills/`, `bin/keel` and `templates/` on
2026-08-29: **no skill reads `artifacts.snapshot` at all.** The only code that touches it is
`bin/keel:1329-1343`, which fails doctor when a set path does not exist. Verified on a scratch
fixture the same day: `keel profile set artifacts.snapshot docs/snapshot.md` succeeds with no code
change, and `keel doctor` then reports

```
FAIL  artifacts.snapshot points at 'docs/snapshot.md', which does not exist
```

until the file is written. So as literally requested, the change writes a derivable string into a key
nobody consults, and converts "the snapshot was deleted" from a silent absence into a hard doctor
failure. **That is the whole of the against, and it is answerable**, because two of its premises are
themselves defects rather than facts of the design: the key is unread because a consumer was never
wired to it, and the monorepo path is not derivable at all.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The six nulls are real and reproducible in this repository. It also leaves `write-prd` unable to honour a snapshot that lives anywhere but the default path, which is a defect independent of this idea |
| Do it manually | One `keel profile set artifacts.snapshot <path>` after each snapshot | Genuinely viable and works today with no code change, proven on a fixture 2026-08-29. It is what a disciplined user would do. It does not travel, and nobody has done it here in the fourteen weeks this repository has had the key |
| Buy it | Nothing available | No tool writes keel's profile shape |
| Build something smaller | Wire one reader, then one writer that costs no skill words | Recommended. See the variants table |

**Variants of building it**

| Variant | Note |
|---|---|
| Each of the five artifact-producing skills gains a line: "then run `keel profile set artifacts.<key> <path>`" | The literal request, extended to be consistent. **Blocked by measurement, not by taste:** `write-plan` is at 897 words against ADR-0001's 900 ceiling, so the line fails `tests/validate-skills.sh` outright. `repo-snapshot` at 699 crosses the 700 target and takes on an ADR-0001 obligation to hold a passing eval arm at its new length. Costed 2026-08-29, numbers below |
| `repo-snapshot` alone gains the line | What the feedback asks for, exactly. Cheapest, and it leaves the other four skills leaving nulls behind, which is the same gap with a smaller blast radius. Costs `repo-snapshot` its last word of headroom |
| A `keel profile sync` fills every null artifact key whose default path exists on disk | **Chosen, 2026-08-29.** Zero skill words, so no body pays and `write-plan`'s three words of headroom are untouched. Idempotent, and it works retroactively on repositories that already have the documents, which the per-skill line never does |
| `keel doctor` fills the keys itself | Rejected. Doctor is a diagnostic and users run it to find out what is wrong, not to have their profile edited. Doctor should **report** the drift and name the command |
| A `PostToolUse` hook notices a write under `docs_root` and sets the key | Rejected. It puts a hook in every session of every keel project to catch an event that happens a few times per repository, and keel already holds its hook budget to 400 tokens (`tests/validate-skills.sh:362-366`) |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Something will eventually read `artifacts.snapshot` | A consumer is wired to it | `write-prd`'s `from-repo` mode is the obvious one and it hardcodes `<docs_root>/snapshot.md` at `skills/write-prd/SKILL.md:28` while checking `profile.artifacts.prd` three lines later at `:31`. **The asymmetry is in one table on one screen** | **Yes, and it is currently false.** This is why the reader half comes first |
| The default path is what gets written | A single-unit repository | `skills/repo-snapshot/SKILL.md:87-88` also emits `snapshot-<unit>.md` per unit in a monorepo, which is not derivable and which a single string key cannot hold | **Yes, and it is false for monorepos.** Open question 2 |
| A skill can be trusted to run a command after writing a file | The instruction is in the body and the body has room | `design-architecture/SKILL.md:65-66` already does exactly this for `stack.has_ui`, so the pattern is established and works | Partly. Established, but never measured for compliance |
| The five bodies can afford the line | Each is under its ceiling after the edit | Measured 2026-08-29 by `tests/validate-skills.sh`: `write-plan` 897, `write-prd` 791, `repo-snapshot` 699, `design-architecture` 694, `write-user-stories` 689 | **Yes, and one of them cannot.** `write-plan` has three words |
| Setting the key is safe once set | The document is never moved or deleted | `bin/keel:1334-1335` fails doctor on a set path that does not exist | **Yes, and it is a real cost.** A user who deletes a stale snapshot gets a red doctor and a message about a key they did not set |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Nothing reads `artifacts.snapshot` | Grep over `skills/`, `bin/keel`, `templates/`, 2026-08-29. Five skills read sibling keys: `write-prd/SKILL.md:31` (`prd`), `write-user-stories/SKILL.md:18` (`prd`), `design-architecture/SKILL.md:25`, `write-plan/SKILL.md:19`, `repo-snapshot/SKILL.md:41` | The writer half has no consumer. Building it first produces a key that is written and never read, which is the definition of ceremony |
| `write-prd` reads the snapshot from a hardcoded path | `skills/write-prd/SKILL.md:28` gives `from-repo`'s first read as `<docs_root>/snapshot.md`, while `:31` checks `profile.artifacts.prd` | **The defect, and it is not the one that was reported.** A repository that maps its snapshot elsewhere is silently ignored by the one skill built to consume it |
| The writer already exists and needs no code | `bin/keel:973-1017` `profile_set`, reachable as `keel profile set <dotted.path> <value>`. It refuses a path that is not already in the file (`:990-998`), and every `artifacts.*` key is seeded by `write_profile` at `bin/keel:445-448`, so all six are settable today. Proven on a fixture 2026-08-29 | Whatever is decided, this is a wiring change and not a feature. No new writer needs building |
| Doctor already validates the map, generically | `bin/keel:1329-1343` iterates every non-underscore key with a value | Doctor needs no change to cover a newly set key, and it is where a "null but the default exists" report belongs |
| The gap is systemic, not `repo-snapshot`'s | All five artifact-producing skills write to a fixed path and set nothing: `repo-snapshot/SKILL.md:87-88`, `write-prd/SKILL.md:74-75`, `write-user-stories/SKILL.md:59-60`, `design-architecture/SKILL.md:56-57`, `write-plan/SKILL.md:55-56` | Fixing `repo-snapshot` alone answers the feedback and leaves four instances of it |
| One skill body physically cannot take the line | `tests/validate-skills.sh` on 2026-08-29: `write-plan` is 897 words, 3 from the ceiling | The per-skill variant is not a matter of preference. It fails the suite on one of the five |
| The `keel profile set` callback pattern is already in use | `design-architecture/SKILL.md:65-66`: "When the design commits to a user interface, run `keel profile set stack.has_ui true`" | The precedent exists and is one sentence long, which is what the per-skill variant would cost each body |

## Open questions

1. ~~**Who writes the key: the skill, or a command the user runs?**~~ **Answered 2026-08-29 by
   Bernard, asked as a choice: a `keel profile sync` command.** It fills every null artifact key
   whose default path exists on disk, costs no skill words so no body pays and `write-plan`'s three
   words of headroom are untouched, is idempotent, and works retroactively on repositories that
   already hold their documents. The cost accepted with it is that a user has to know the command
   exists, which is what makes open question 3 part of the same piece of work rather than an
   afterthought: doctor's report is how anyone finds out to run it.
2. ~~**What does a monorepo write?**~~ **Answered 2026-08-30 by Bernard, asked as a choice: the
   key stays null there.** Now `FR-13` of `docs/prd/profile-sync.md`. Writing `docs/` puts a PRD
   at `<docs_root>/prd/<slug>.md` and this repository holds five, so the monorepo case turned out
   to be one instance of a wider problem rather than a special case: **four of the six keys can have
   many documents behind a single string key.** Settled the same way for all of them, `FR-03` and
   `FR-04`: sync fills only `snapshot`, `decisions` and `plans`, and the other three stay null with
   a stated reason. `CON-05` keeps the schema at `["string","null"]`.
3. ~~**Should doctor warn on a null key whose default path exists?**~~ **Answered: yes, and it
   names the command.** Not a separate decision in the end, because question 1's answer already made
   doctor's report the only way anyone learns the command exists. Now `FR-10` and `FR-11` of
   `docs/prd/profile-sync.md`, shaped after the `stack.has_ui` warning at `bin/keel:1390`: a warning
   and never a failure, and only for the keys sync can actually fill.

## What has landed

**The reader half, 2026-08-30.** `skills/write-prd/SKILL.md:28` now gives `from-repo`'s first read as
`profile.artifacts.snapshot`, else `<docs_root>/snapshot.md`, which is what the sentence three lines
below it already did for `artifacts.prd`. `artifacts.snapshot` has a consumer, so it is a key worth
setting rather than decoration, and the finding this record calls "the defect, and it is not the one
that was reported" is closed. Pinned by an assertion in `tests/test-keel.sh` that reads the table row,
because the asymmetry survived fourteen weeks of review by living in one table on one screen.

The costs this record predicted were both real and both paid. The body went 791 to 793 words, and the
ADR-0001 obligation that re-opens was discharged by re-running `build-with-no-prd` at the new length:
pass, $0.47, recorded in `tests/evals/results.md`. The estimate here was about $0.40.

**The writer, 2026-08-30, PR #52.** `keel profile sync` fills the three artifact keys whose default
location is one unambiguous place and is really there. Specified in `docs/prd/profile-sync.md`,
approved the same day, built to `docs/plans/2026-08-30-profile-sync.md`. Open questions 2 and 3 are
closed above, as `FR-13` and as `FR-10` with `FR-11`.

**One number in this record was optimistic, and the built command confirms it.** It said sync works
retroactively on repositories that already hold their documents. Run on this one it filled two keys,
not six: `docs/snapshot.md` does not exist here, and `prd`, `stories` and `architecture` are excluded
by `FR-04` because each defaults to one file per slug.

**One thing planning found that this record did not.** `keel init` scaffolds
`<docs_root>/decisions/ADR-0000-template.md`, so that directory is never empty on a fresh project.
Without a rule for it, every newly initialised repository would have had its `decisions` key set to
a directory holding only a template, and a standing doctor warning before anyone had written
anything. `FR-06` was amended for it, asked as a choice.

## Recommendation

**Build something smaller, and reverse the order the feedback implies.** First wire `write-prd`'s
`from-repo` mode to check `profile.artifacts.snapshot` before falling back to `<docs_root>/snapshot.md`,
matching what it already does for `artifacts.prd` one line below. That is a defect fix, and it is what
turns the key from decoration into something worth setting. **It is not free:** `write-prd` is at 791
words, 109 below the ceiling but already over the 700 target, so `docs/standards.md:308-311` puts it
in the class where adding words re-opens ADR-0001's obligation to hold a passing eval arm at the new
length. That arm exists and passes: `build-with-no-prd` in `tests/evals/results.md`, most recently in
the seven-arm gate of 2026-08-20. The cost is one re-dispatch, about $0.40, not a body that has to be
trimmed first.

Then the writer, and it is `keel profile sync` rather than a line in five skill bodies. Decided by
Bernard on 2026-08-29: `write-plan` has three words of headroom and cannot take the line at all, and
a command fixes the repositories that already hold their documents while a skill line only ever helps
the next run. Doctor reports the drift and names the command, which is how anyone learns it exists.

Next: `write-prd` for the sync command, settling open questions 2 and 3. The reader half is a
one-line defect fix in `write-prd`'s own body and should not wait for it.

## Not decided here

- The name and shape of the sync command, and whether it is `keel profile sync`, `keel artifacts sync`
  or a flag on `doctor`. Left to `write-prd` and `design-architecture`.
- Whether the schema grows an array for the monorepo case. Open question 2.
- Whether the other four skills gain the callback if the skill-line variant wins, and where their
  words come from. Costed above, not settled.
- Whether `keel doctor` should report a null key whose default exists. Open question 3.
