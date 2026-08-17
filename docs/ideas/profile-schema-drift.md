# Idea: how a new profile field reaches an existing installation

| | |
|---|---|
| Raised by | Bernard, 2026-08-17, immediately after the 0.7.1 release |
| Status | agreed, built 2026-08-17 |
| Recommendation | Build something smaller: make the refresh signal mean something, rather than build a migration |
| Next | `write-prd` is not warranted. This is a defect fix, so `write-plan` after the decision below is confirmed |

## The problem

Every keel project is told to re-run `keel init` on every release, whether or not that release
changed anything in the profile, so the one signal that would mean "your profile is missing a field
the new skills read" is indistinguishable from noise.

**Evidence.** This repository, today. `.keel/profile.json` records `keel_version: 0.6.1` while 0.7.1
is installed, so `keel doctor` prints the re-run warning. 0.7.1 changed three markdown files and the
version. It added no profile field, removed none, and renamed none. The warning is correct by its
own logic and useless as information. The same will be true of every release that touches only
skills, which is most of them: 0.7.0 and 0.7.1 both qualify.

## What was asked for

> When the plugin has new fields in the profile schema, how do existing installations get those
> fields when the plugin updates on their installations.

## The case against

**Strongest argument for not building this at all.** The mechanism already exists and works, so the
risk here is building a migration system for a problem that is one comparison away from being
solved. `merge_profile` at `bin/keel:207` re-runs detection, then merges the existing profile under
the freshly generated one: a key the new template introduces is added, a value the human set wins,
and `keel_version` is the single field the tool takes back. Re-running `keel init` is therefore
already a complete, idempotent, non-destructive schema refresh, and it was built that way
deliberately after a run replaced a hand-corrected test command. Anything that writes profile fields
without a human running a command is strictly more dangerous than what is there now, for a benefit
that is one line of shell.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The warning keeps firing on releases that changed nothing, and the day a release does change the schema, nobody looks. Cheap to fix, and the cost of not fixing it is silent |
| Do it manually | A line in the release notes each time | This is close to what happens now, and it failed: 0.7.0's CHANGELOG says nothing about the profile either way, so the reader cannot tell |
| Buy it | Not available | No third party knows this schema |
| Build something smaller | Roughly an hour | This is the recommendation. See below |

Variants of building it:

| Variant | What it costs | Note |
|---|---|---|
| `schema_version` in the profile and the template, bumped only when a field changes | An hour, plus the discipline to bump it | Makes the doctor warning mean "a field you do not have exists", which is the only version of this warning worth reading |
| `keel migrate`, a command that adds missing keys without re-detecting | A day, plus tests | Duplicates `merge_profile` for the sake of avoiding re-detection, and re-detection is the part that catches a stack that has changed since init |
| Auto-refresh on plugin update | Cannot be done | A plugin has no update hook that runs in a consuming repo, and writing to a project's tracked file without being asked is the behaviour `merge_profile`'s own comment was written against |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A skill reading an absent profile field degrades safely | Every reader has a default or asks | Grep the skills for profile reads and check each one's absent branch | **Yes, 2026-08-17. It does.** See open question 1 |
| Most releases do not change the schema | Field changes are rarer than skill changes | Count schema changes against releases in the git history | Partly: 0.7.0 and 0.7.1 both changed none |
| People run `keel doctor` often enough to see the warning | It runs in CI, or habitually | It is not in `.github/workflows/ci.yml`, and it takes about 11 minutes | **No. A warning nobody sees is not a delivery mechanism** |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Re-running init already merges new keys in, non-destructively | `bin/keel:207` `merge_profile`, and its comment on why existing values win | The asked-for capability exists. The question is the signal, not the mechanism |
| `keel_version` is tool-owned, so it always reflects the last init | `bin/keel:226` | "Has this project been re-initialised since the upgrade?" is answerable. "Did the upgrade change anything?" is not |
| The doctor warning fires on any version difference | `bin/keel:1207`, `[ "$pv" != "$iv" ]` | It cannot distinguish a schema change from a typo fix, so it will cry wolf on most releases |
| The profile schema is a separate, versionless file | `templates/profile.schema.json` | There is nowhere to record that a release changed the schema, which is why the comparison has to fall back on the release version |
| A field's absence has already caused a design decision once | Decision 3, `docs/07-open-decisions.md`: `hard_block_paths` at the top level, not under `gates`, and the prose was wrong for weeks | Absent and misplaced fields are a real failure mode here, not a hypothetical one |
| `keel doctor` is not in CI and takes about 11 minutes | `.github/workflows/ci.yml` runs `run-tests.sh`, `supply-chain-scan.sh`, `test-supply-chain.sh` | Whatever the warning says, almost nobody is reading it. Fix the signal and the delivery, or fix neither |

## Open questions

1. **What does a skill do today when a field it reads is absent?** **Answered 2026-08-17: it
   degrades safely, so this is a signal problem and not a correctness one.** Only nine distinct
   profile paths are read across all 24 skills, and the five that could be missing are all `verify`
   commands, whose readers are written for the `null` case already (`skills/ship/SKILL.md:23`,
   `skills/setup-deployment/SKILL.md:30`, `skills/coding-standards/SKILL.md:53`,
   `skills/write-plan/SKILL.md:26`, `skills/execute-plan/SKILL.md:29`). The only field read by code
   rather than by a model is `hard_block_paths`, and `hooks/sensitive-guard:57` exits 0 in silence
   when the profile does not contain the string at all, which its header at line 16 states is
   deliberate.

   **But that same line is the sharpest argument for this idea.** Absent and opted-out are
   indistinguishable to the guard. A project that predates the field and a project that considered
   it and declined are the same file to it. That is exactly what schema drift costs here, and it is
   invisible rather than loud.
2. Should `keel doctor` run in CI, given it is the only thing that would surface any of this? Eleven
   minutes says no as it stands, which may mean doctor needs a fast mode more than this needs a
   version field.
3. If `schema_version` is added, who bumps it, and what stops it being forgotten? A validator that
   fails the build when `templates/profile.schema.json` changes without the version moving is the
   obvious answer, and it is the same shape as the check that caps the descriptions sum.

## Recommendation

**Build something smaller.** Add `schema_version` to `templates/profile.schema.json` and to what
`keel init` writes, bump it only when a field is added, removed, or moved, and change the
`bin/keel:1207` comparison to read it instead of `keel_version`. Then the warning fires only when
the project is genuinely missing something, and `keel init` already knows how to fix it.

Why: the merge already works, so the whole defect is that the warning cannot tell a schema change
from a release. Everything else here is building a second mechanism beside a working one.

What happens next: open question 1 is answered and the answer holds the size of this down. Nothing
crashes on an absent field, so this is a signal-quality fix, planned in
`docs/plans/2026-08-17-schema-version-and-snapshot-handoff.md`.

**Built 2026-08-17**, as three commits: `6314b7a` adds the tool-owned `schema_version`, `1fb1292`
moves doctor's warning onto it, and `5a7a14e` makes a field change without a version bump fail the
build, which is open question 3's answer. Open question 2, whether doctor belongs in CI given it
takes eleven minutes, is untouched and still open.

## Not decided here

Whether the schema gets a formal migration path at all, what a fast `keel doctor` would check,
whether doctor belongs in CI, and how a skill should behave on an absent field. The last of those is
open question 1 and may deserve its own ADR.
