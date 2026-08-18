# PRD: the profile a user can actually use

| | |
|---|---|
| Status | approved |
| Mode | from-idea |
| Author | Bernard, with Claude |
| Date | 2026-08-18 |
| Derived from | `docs/ideas/profile-key-documentation.md` and `docs/ideas/stack-plugins-on-existing-repos.md`, at `5e2de35`, and this conversation |
| Approved by | Bernard, 2026-08-18 |

> Requirement IDs are permanent. `write-user-stories` and `write-plan` trace to them.
> Retire an ID rather than renumbering.

## 1. Executive summary

`.keel/profile.json` is the file every keel skill reads and the file a user is expected to adjust,
and most of it is undiscoverable. Eleven declared keys are never written by `keel init`, so a human
has to add them; six of those eleven appear in no document a user reads; and 35 of the 59 declared
keys carry no description at all, including five that have neither a description nor a mention
anywhere. One of those five, `plugins.recommended`, is the mechanism that would make `keel doctor`
report a missing language server, which is why a repository that already has a `.claude/settings.json`
silently gets no plugins at all.

This PRD covers both halves because they are the same problem: a key nobody can discover is a key
nobody sets, and a key nobody sets eventually gets reported as a missing feature. It is for anyone
running keel on a project, and it matters now because the context window work shipped a key that is
still documented nowhere.

## 2. Problem statement

**A user cannot find out what a profile may contain without reading keel's source.** The only
complete list is `templates/profile.schema.json`, a JSON Schema written for validation. It is not
linked from the README, nothing tells a reader it is worth opening, and more than half of it is
bare.

**Evidence,** computed against `5e2de35` on 2026-08-18 by diffing schema-declared leaf keys against
the output of a real `keel init -y`:

| Measure | Count |
|---|---|
| Leaf keys declared by the schema | 59 |
| Written by `keel init` | 48 |
| Never written, so a human must add them | 11 |
| Carrying no `description` | 35 |
| Neither written nor described | 5 |

The five are `conventions.working_branch`, `deploy.registry`, `deploy.secrets_manager`,
`plugins.excluded` and `plugins.recommended`. The six unwritten keys absent from every document a
user reads are those five plus `verify_notes`.

**The second half of the problem is a consequence of the first.** `plugin_report` (`bin/keel:142-163`)
reads `plugins.recommended` and falls back to a hardcoded three when it is absent. `init` never
writes it. So on a repository that already has `.claude/settings.json`, `write_settings`
(`bin/keel:558-561`) returns after merging permissions only, no plugins are enabled at all, not even
`keel@gbi`, and doctor cannot report it because the list it checks contains no language server.
Verified on two fixtures on 2026-08-18: a fresh TypeScript repo got seven plugins including
`typescript-lsp`; an otherwise identical repo with a pre-existing settings file got no
`enabledPlugins` key whatsoever.

**What it is not.** The stack-to-plugin mapping is complete and correct. `lang_lsp`
(`lib/detect-stack.sh:581-596`) covers all thirteen detected languages, and all twelve server names
were verified against the real `claude-plugins-official` catalogue on 2026-08-18. Nothing needs
building there.

## 3. Goals and non-goals

**Goals**

- A user can read what every profile key does, in one place, without opening the schema.
- A reader can tell at a glance which keys keel writes and which are theirs to add.
- The reference cannot silently drift from the schema.
- `keel doctor` names the plugins a project is missing, including its language server, on a
  repository that already has a settings file.

**Non-goals**

- Writing into an existing `.claude/settings.json`. keel already declined to make a machine-level
  decision in a committed file for permission mode (`bin/keel:608-614`), and the same argument
  applies to enabling plugins for everyone who clones.
- Verifying that an enabled plugin resolves to something installed. Out of scope, see section 11.
- Changing the stack-to-plugin mapping, which is complete.
- A `keel keys` command. `docs/03-install-and-distribution.md:195-196` records that the CLI
  deliberately does not parse the profile back, and departing from that deserves its own argument.

## 4. Users and personas

| Who | What they are trying to do | What they know |
|---|---|---|
| A developer who just ran `keel init` | Adjust the profile to fit their project | That the file exists. Not which keys are available, nor which of them keel will overwrite |
| A developer on a mature repository | Get keel's recommended plugins enabled | Nothing is wrong. That is the problem: it is silent |
| A skill, at runtime | Read project facts | Only what the profile holds. Skills are unaffected by this change |
| `keel doctor` | Report what is missing or misconfigured | The profile, `.claude/settings.json`, and the plugin cache |

## 5. Functional requirements

### The reference

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-01 | Every leaf key declared in `templates/profile.schema.json` must carry a non-empty `description`. | confirmed | 35 of 59 are empty, counted 2026-08-18 |
| FR-02 | A committed reference page at `docs/profile-keys.md` must list every declared key with its description, its type, and whether `keel init` writes it. | confirmed | Bernard, 2026-08-18, choosing the committed and validator-checked option |
| FR-03 | The page must be produced from `templates/profile.schema.json` by a script, not written by hand. | confirmed | `docs/ideas/profile-key-documentation.md`: a hand-written copy is the variant that goes stale, and this repository has been bitten by profile drift twice |
| FR-04 | `tests/validate-skills.sh` must fail when the committed page and the schema disagree. | confirmed | Same shape as the existing tool-table rule at `tests/validate-skills.sh:341-345` |
| FR-05 | The written-by-init column must be derived by running `keel init` against a fixture, not from a hand-maintained list. | inferred | A second hand-maintained list is the thing FR-03 exists to avoid |
| FR-06 | `docs/profile-keys.md` must be reachable from `README.md`. | inferred | The gap is discovery. A page nothing links to repeats the schema's problem |

### The plugins

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| FR-07 | `keel init` must write `plugins.recommended` from the stack it detected. | confirmed | Bernard, 2026-08-18, choosing report-only. `detect_plugins` at `lib/detect-stack.sh:601-608` already computes it |
| FR-08 | `keel doctor` must report a recommended plugin that is not enabled, on a repository whose `.claude/settings.json` predates keel. | confirmed | The fixture case that currently reports nothing |
| FR-09 | For each missing plugin, `keel doctor` must name the command that installs it. | confirmed | Bernard, 2026-08-18. Pattern already used for the marketplace at `bin/keel:1407` |
| FR-10 | Re-running `keel init` must preserve a hand-edited `plugins.recommended`. | inferred | `merge_profile` at `bin/keel:290` already gives a non-empty human value precedence. Asserted so it is not lost |
| FR-11 | `keel init` must not add entries to an existing `.claude/settings.json`. | confirmed | Bernard, 2026-08-18, choosing report-only over merge |
| FR-12 | The generator must omit any key `keel init` writes that the schema does not declare, and `artifacts._note` is the only such key today. | confirmed | Bernard, 2026-08-18, answering Q2. Declaring it would cost a `SCHEMA_VERSION` bump for a key nobody sets, see `CON-02` |

## 6. Non-functional requirements

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| NFR-01 | Generating and checking the page must need no network access and no API key. | inferred | `tests/validate-skills.sh:279-280` records that a check which only runs where a key exists is absent exactly where nobody is watching |
| NFR-02 | `keel doctor` must still start `python3` at most ten times. | confirmed | Asserted at `tests/test-keel.sh:405`. FR-07 to FR-09 add work to doctor's hot path |
| NFR-03 | This change must add nothing to what `hooks/session-start` injects. | confirmed | It measured 356 estimated tokens against a 400 ceiling on 2026-08-18, and two other ideas are competing for the remainder |
| NFR-04 | The generated page must be deterministic: generating twice from an unchanged schema must produce identical bytes. | inferred | Otherwise FR-04 fails at random and the rule gets disabled |

## 7. Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-01 | Writing 35 descriptions does **not** require a `SCHEMA_VERSION` bump. The validator fingerprints key paths only, not descriptions (`tests/validate-skills.sh:364-372`). | The existing drift rule |
| CON-02 | Declaring `artifacts._note`, which `init` writes and the schema does not declare, **would** add a path, trip the fingerprint, and force a `SCHEMA_VERSION` bump plus a new `schema_fingerprint_for` line. That cost is why it is an open question rather than a requirement. | The same rule |
| CON-03 | `keel` cannot install a plugin. `enabledPlugins` is a reference, and `/plugin install` is a user action in the client. The ceiling is recommending and reporting. | Claude Code |
| CON-04 | `.claude/settings.json` is normally committed, so anything written there decides what loads for everyone who clones. | The project's own position at `bin/keel:608-614` |
| CON-05 | Skill descriptions are budgeted and this change must not touch them. | Decision 6, enforced by `tests/validate-skills.sh` |

## 8. Observed but not required

Not applicable: this is `from-idea` mode.

Two behaviours are worth naming so nobody promotes them later. `write_settings` enabling seven
plugins on a fresh repository is not a requirement this PRD defends; it is what shipped, and whether
it should continue is open question Q3. And `plugin_report`'s hardcoded three-plugin fallback is a
stopgap for the absent key, not a requirement; once FR-07 lands, whether it stays is a judgement
about repositories initialised before this change.

## 9. Success metrics

Carried forward from `docs/prd/context-window-at-init.md`, where Bernard chose the test suite as the
measure for this class of internal-tooling change. Re-asking would be theatre.

| Measure | Source | Target |
|---|---|---|
| Declared keys with no description | A new assertion in `tests/validate-skills.sh` | Zero |
| The committed page disagreeing with the schema | The same assertion | Zero |
| Generating twice produces different bytes | A new assertion | Never |
| A fixture repo with a pre-existing `.claude/settings.json` where doctor reports no missing plugin | `tests/test-keel.sh` | Zero |
| `python3` starts in `keel doctor` | Existing assertion at `tests/test-keel.sh:405` | At most 10 |

## 10. Milestones

Unknown, needs a decision. No deadline was given.

## 11. Out of scope

| Excluded | Why |
|---|---|
| Verifying an enabled plugin resolves to something installed | Bernard, 2026-08-18. It roughly doubles the plugins half. Enabled-but-unavailable will still look identical to working, and that is accepted here |
| Merging entries into an existing `.claude/settings.json` | FR-11. It is the position `bin/keel:608-614` already took for permission mode |
| Reconsidering whether fresh repositories should get plugins written at all | Q3. The recommended change is correct either way |
| A `keel keys` command | Section 3 |
| Documenting keys outside the profile, such as `.claude/settings.json` | A different file with a different owner |

## 12. Assumptions

| # | Assumption | Falsified if | Checked |
|---|---|---|---|
| A1 | The 24 existing descriptions are good enough to publish unchanged | A reader finds one that misleads | Spot-checked only. `gates.context_window` is four lines and explains its reasoning |
| A2 | Writing 35 descriptions is the bulk of the work, and generation is the small half | The generator turns out to be the hard part | Yes, by count. It is why the recommendation was reworded |
| A3 | A reader who cannot find a key will look at a linked reference | They ask instead, or never notice | **No.** The theory of change for FR-06, untested |
| A4 | Doctor naming a missing plugin leads to it being installed | The warning is ignored | **No, and it is the whole theory of change for the plugins half** |
| A5 | Nobody currently relies on `plugins.recommended` being absent | A project sets `plugins.excluded` expecting the fallback list | Not checked. `plugins.excluded` is itself undocumented, so use is unlikely |
| A6 | The schema is the right source of truth for the page | The profile grows more keys the schema does not declare, and they matter to a reader | Accepted knowingly. `artifacts._note` is the one case today and `FR-12` omits it deliberately |

## 13. Open questions

| # | Question | Needs | Blocks |
|---|---|---|---|
| Q1 | ~~Where does the page live?~~ **Answered 2026-08-18: `docs/profile-keys.md`**, unnumbered like `standards.md` and `prompting.md`, since the numbered files are design documents. Now in `FR-02` and `FR-06` | Answered | Was: `FR-02` |
| Q2 | ~~Is `artifacts._note` declared, removed, or left?~~ **Answered 2026-08-18: left, and the generator omits it.** No `SCHEMA_VERSION` bump. Now `FR-12` and `CON-02` | Answered | Was: `CON-02` |
| Q3 | Should fresh repositories stop having plugins written into `.claude/settings.json`, so both paths behave the same way? | Bernard | Nothing here. It decides a later change |
| Q4 | Does `plugin_report`'s hardcoded fallback stay, for profiles written before `FR-07`? | Bernard | `FR-08`, at the edges |
| Q5 | Should `keel doctor` warn when a declared key has no description, or is that only a build-time concern? Recommended build-time only: doctor reports project problems, not keel's own | Bernard | Nothing |
