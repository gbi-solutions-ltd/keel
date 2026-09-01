# Idea: document the profile keys a user is expected to set

| | |
|---|---|
| Raised by | Bernard, 2026-08-18 |
| Status | **built 2026-08-18**, via `docs/plans/2026-08-18-usable-profile.md`, fully ticked. `docs/profile-keys.md` documents 60 keys and is generated from the schema by `tests/generate-profile-keys.sh`, with a suite check that fails when the two drift. Status corrected 2026-08-30 |
| Recommendation | Build it, but the generator is the small half: 35 of 59 keys have no description to generate from, so this is a writing job first and a tooling job second |
| Next | `docs/prd/usable-profile.md` (draft, awaiting approval), written jointly with `stack-plugins-on-existing-repos.md` |

## The problem

Twelve keys in the profile schema are never written by `keel init`, so a human has to set them, and
**seven of those twelve appear nowhere in any document a user reads.** The only complete list of
what a profile may contain is `templates/profile.schema.json`, which is a JSON Schema written for
validation rather than for a reader, so a user cannot discover that a key exists, let alone what it
does, without reading keel's source.

**Evidence.** Computed on 2026-08-18 by diffing every leaf key the schema declares (59) against
every key a real `keel init -y` produced on a fixture (48). Declared and never written:

**Recounted after the context window work merged (`5e2de35`):** eleven, not twelve.
`gates.context_window` moved to the written column, and its description was rewritten, so it also
left the undocumented list. The other counts are unchanged: 35 of 59 keys still carry no
description, and the same five have neither a description nor a mention anywhere.

| Key | Documented anywhere in `docs/`, `README.md` or `CONTRIBUTING.md`? |
|---|---|
| `gates.context_window` | **No** |
| `plugins.recommended` | **No** |
| `plugins.excluded` | **No** |
| `verify_notes` | **No** |
| `hard_block_paths` | Only in `docs/06-repo-layout.md` and `docs/07-open-decisions.md`, as design discussion |
| `conventions.working_branch` | **No** |
| `deploy.registry` | **No** |
| `deploy.secrets_manager` | **No** |
| `notes` | Mentioned in passing, not as a key a user sets |
| `gates.context_watch` | Yes, `docs/05-token-and-memory-design.md`, `docs/prompting.md` |
| `gates.context_warn_pct` | Yes, same two |
| `gates.context_stop_pct` | Yes, same two |

The same diff found one key written but not declared, `artifacts._note`, which is drift in the other
direction.

**And the schema is thinner than it looks.** Measured the same day: of 59 leaf keys, only 24 carry a
`description` and **35 carry none**. Five keys have neither a description nor a mention in any
document, so they are undocumented in every sense the word has: `conventions.working_branch`,
`deploy.registry`, `deploy.secrets_manager`, `plugins.recommended` and `plugins.excluded`. The
descriptions that do exist are good, which is what made the schema look like a usable source until
it was counted.

**This is the root cause of two other records raised on the same day.** `gates.context_window` is
the key `context-window-at-init.md` exists because nobody sets, and `plugins.recommended` is the key
`stack-plugins-on-existing-repos.md` needs written. Both are undocumented. The pattern is not
coincidence: a key that no document mentions is a key nobody sets, and a key nobody sets eventually
gets reported as a missing feature.

## What was asked for

> On a separate note, all configurable profile keys (especially the ones keel doesn't overwrite)
> need to be documented for the users to adjust accordingly

The parenthesis is the precise part. Keys `init` writes are discoverable by opening the file it just
wrote. Keys it does not write are invisible, and those are exactly the twelve above.

## The case against

**Strongest argument for not building this at all: a hand-written key reference is the single most
likely document in this repository to go stale, and staleness here is worse than absence.** A user
who reads no documentation checks the schema and is correct. A user who reads a reference page
listing a key that was renamed two releases ago is confidently wrong, and they will file the bug
against the wrong component. keel already knows this failure mode: `snapshot-recommends-tools.md`
records it as the main risk of the tool table, `profile-schema-drift.md` exists entirely because
profile fields drift, and `tests/validate-skills.sh:351-365` fingerprints the schema specifically
because "a field added, removed, renamed or moved without SCHEMA_VERSION moving is a release that
expects a field nobody's profile has". Adding a prose copy of the schema adds a second thing to keep
in step with the first, in a repository that has already been bitten by exactly that.

The answer is not to write it by hand. The schema already carries a `description` on nearly every
key, and those descriptions are good: `gates.context_window`'s runs to four lines and explains why
detection cannot work. A page generated from the schema, checked by the validator, cannot drift,
because drift becomes a failing build rather than a wrong sentence. That turns the strongest
objection into the design constraint.

**Second argument: the schema is already the documentation, and it is readable.** Opening
`templates/profile.schema.json` and reading the `description` fields is a real answer, and it costs
one file open. Against that, it is 400-plus lines of JSON Schema whose structure a reader must first
understand, it is not linked from the README, and nothing tells a user it is worth reading. The gap
is discovery more than content.

**Third argument: nobody has asked for a key they could not find.** No instance was named. The
evidence here is structural, that seven keys are undocumented, rather than a report of somebody
being blocked. That is weaker evidence than a complaint, and it should be recorded as such.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The schema exists and is readable. It is also undiscoverable, and the day's other two records are both consequences of that |
| Do it manually, once | An afternoon writing a page | This is the version that goes stale. Rejected on the argument above, not on cost |
| Buy it | Nothing available, though generic JSON Schema to Markdown tools exist | A general tool would emit a reference of every key equally, and the whole point is that twelve of them deserve prominence the other 47 do not |
| Build something smaller | Add the missing `description` fields and link the schema from the README | Genuinely tempting, costs almost nothing, and captures most of the discovery gain. See the variants table |

**Variants of building it**

| Variant | Note |
|---|---|
| Generate the page from the schema, validator-checked | **Recommended.** Cannot drift, reuses descriptions already written, and the validator rule is the same shape as the existing tool-table rule at `tests/validate-skills.sh:341-345` |
| Hand-written reference page | Rejected. It is the variant the strongest objection is about |
| Link the schema from the README and stop | The cheapest thing that helps. Leaves the reader parsing JSON Schema, and does not distinguish the twelve from the rest |
| A `keel keys` command that prints them | Discoverable from the tool the user is already running, and it can mark which keys the current profile is missing. More code, and `bin/keel` deliberately does not parse the profile back (`docs/03-install-and-distribution.md:195-197`) |
| Have `keel doctor` name unset optional keys | Rejected. Doctor reports problems, and an unset optional key is not one. It would warn on every healthy project |
| Expand `templates/keel-profile.example.json` to carry all twelve with comments | JSON has no comments, and an example profile with every optional key set is not an example anybody should copy |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| The twelve are the ones that matter | Keys `init` writes are self-documenting | The written keys appear in a file the user opens; the unwritten ones appear nowhere | **Yes, that is the diff** |
| Schema descriptions are good enough to publish | Each is written for a reader, not a validator | True of the 24 that exist. `gates.context_window` at `:284-288` is four lines and explains the reasoning | Yes, for the ones that exist |
| Every key has a description | Generation produces no blanks | **Measured 2026-08-18: false.** 35 of 59 have none | **Yes, and it inverts the effort estimate** |
| Generation is cheap here | The repository can generate and check a doc | It already generates and checks the CLAUDE.md block, and the validator already fingerprints the schema | Yes |
| Nobody is currently blocked | The problem is latent | No instance named. Two same-day records are consequences, which is indirect evidence | Partly |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| Twelve declared keys are never written | Diff of schema leaves against a real `init -y` profile, 2026-08-18 | The scope is exactly twelve, not "the profile" |
| Seven of them are undocumented everywhere | Exact-string search of `docs/`, `README.md`, `CONTRIBUTING.md` | The gap is concrete and countable |
| One key is written but not declared | `artifacts._note` | Generation would surface this immediately, which is an argument for it |
| The schema carries descriptions for 24 of 59 keys | Counted 2026-08-18 | The content mostly does **not** exist. Generation alone would emit a page that is 59 percent blank |
| Five keys have neither a description nor a mention anywhere | `conventions.working_branch`, `deploy.registry`, `deploy.secrets_manager`, `plugins.recommended`, `plugins.excluded` | These are the ones a reader cannot learn about by any route, including reading the source's own comments |
| `plugins.recommended` is one of those five | Same measurement | The key that `stack-plugins-on-existing-repos.md` proposes writing is one nobody could currently discover. The two records should land together |
| The repository has been bitten by schema drift before | `docs/ideas/profile-schema-drift.md`; `tests/validate-skills.sh:351-365` | A hand-written copy is the wrong shape here, more than it would be elsewhere |
| A validator rule keyed to source-of-truth already exists | `tests/validate-skills.sh:341-345`, the tool-table rule | The enforcement pattern is proven in this repository |
| The CLI deliberately does not read the profile back | `docs/03-install-and-distribution.md:195-197` | A `keel keys` command would be a departure worth arguing separately |
| Two of the undocumented keys caused today's other records | `gates.context_window`, `plugins.recommended` | The cost of the gap is demonstrated rather than theoretical |

## Open questions

1. **Does every key actually have a usable description?** **Answered 2026-08-18: no, 35 of 59 have
   none.** The real work is writing those 35, and generation is the easy half. This does not change
   the recommendation, it changes what the work is, and it means the effort is measured in an
   afternoon of writing rather than an hour of scripting.
2. **Where does the page live?** Carried into the PRD as `Q1`, with `docs/profile-keys.md`
   recommended: the numbered files are design documents and the unnumbered ones (`standards.md`,
   `prompting.md`) are the user-facing set.
3. ~~**Should it mark which keys `init` writes?**~~ **Settled 2026-08-18: yes**, and derived by
   running `init` on a fixture rather than hand-maintained. Now `FR-05`.
4. **Does `artifacts._note` get declared, or removed?** Carried into the PRD as `Q2`, and it turned
   out to have a price the record did not know about: the validator fingerprints key paths, so
   declaring it would trip the drift rule and force a `SCHEMA_VERSION` bump for a key nobody sets.
   Recommended: leave it, and have the generator ignore it. Recorded as `CON-02`.

## Recommendation

**Build it.** Write the 35 missing `description` fields into `templates/profile.schema.json`, then
generate a single reference page from it, marking the keys `keel init` does not write, and add a
validator rule that fails when the page and the schema disagree.

Why: the schema is the only source that cannot drift from the code, so it is where the writing
belongs, and generating from it turns the staleness objection into a failing build. Writing the page
by hand instead would put 59 keys in a second place, in a repository that has been bitten by profile
drift twice.

Next: `write-prd`, alongside `stack-plugins-on-existing-repos.md`, since `plugins.recommended` is
both one of the five wholly undocumented keys and the key that record proposes to start writing.

## Not decided here

The page's format and location; whether a `keel keys` command is ever added; whether the example
profile changes; how the generated page is regenerated in CI versus locally; and whether
`artifacts._note` is declared or dropped.
