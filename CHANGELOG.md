# Changelog

Notable changes to keel. Versions follow [semantic versioning](https://semver.org).

Until 1.0.0 the skill set is incomplete and skill behaviour may change between minor
versions as each skill is tested against real repositories.

Entries are terse by design; the narrative for each release is in this file's git history and in docs/.

## 0.14.0 - 2026-08-19

- `keel doctor` prints each `verify.*` command as it starts and its elapsed time, and runs each under a 900s timeout where `timeout` or `gtimeout` exists.
- Added `keel doctor --fast`: validates the verify fields without executing them, under a second.
- The context watchdog no longer spawns python on every tool call; the bash wrapper short-circuits always-allowed tools against the fresh measurement cache. Every hook entry carries an explicit timeout.
- Test suite cut from about 11 minutes to under 6 with coverage unchanged: `tests/run-tests.sh` runs files in parallel with per-file timings, `tests/test-keel.sh` uses sourced detection functions and cached fixtures, `tests/no-internal-leaks.sh` runs one grep per pattern over the file list (37s to 4s), `tests/supply-chain-scan.sh` reuses its file lists.
- Doctor's doc-link check prefetches `git ls-tree` once instead of one git spawn per link; `detect_languages` is cached per process; the settings reports share one python parse.
- CHANGELOG condensed to terse bullets; `IMPLEMENTATION-PLAN.md` removed, with README's reading order now starting at `docs/01-architecture.md`.
- `skills/write-prd` questionnaire is mode-keyed so only the applicable section is read; the managed CLAUDE.md block no longer repeats router text the session hook injects.
- Fixed: CI's older shellcheck failed the suite on SC2317 for the indirectly-invoked lint function; both SC2317 and SC2329 are now disabled at the definition.
- The audit behind all of this is `docs/audits/2026-08-19-efficiency.md`.

## 0.13.0 - 2026-08-19

- Trimmed the managed CLAUDE.md block template from 598 to 421 tokens on the `node-ts` fixture, keeping every rule; `###` headings became bold run-in leads.
- Added an assertion in `tests/test-keel.sh` for the 450-token target (only the 700-token ceiling was checked before).
- Corrected `docs/standards.md`, which had recorded the overrun as a permanent departure.
- Rendered size still varies per project; this repo renders 469 tokens due to a longer `verify.lint` command.

## 0.12.1 - 2026-08-19

- Fixed: an eval fixture log file was gitignored by `*.log` and never committed, so a clone staged the incident scenario with no evidence.
- `.gitignore` now carves eval fixtures out of `*.log`, matching the existing carve-out for `tests/fixtures/apex`.
- Added `tests/test-eval-harness.sh` case 18, asserting no fixture file is gitignored.

## 0.12.0 - 2026-08-19

- `write-docs` step 3 now dispatches concurrent `Explore` agents for code reading when no snapshot/PRD/architecture doc exists (added `Agent` to `allowed-tools`). Body grows to 738 words; passing eval arm recorded. `refactor` and `optimize-performance` deliberately left unchanged (no wide-read phase).
- `write-prd` step 5: "as choices" governs a question's form, not its count; batching several open questions in one message is still disallowed. Body grows to 759 words, passing eval arm recorded.
- Added fixtures for all six eval scenarios (one had none); found and fixed 3 defects the new fixtures exposed.
- `done-without-verifying` restored to the eval gate, scored on the plan file left behind rather than the reply. All six arms pass.

## 0.11.0 - 2026-08-18

- Added: `keel init` writes `gates.context_window: 200000`; upper bound `LONG_WINDOW` (1,000,000) applied to every window source. `keel doctor` reports the window it will actually use and why.
- Added `docs/profile-keys.md`, a generated reference for every `.keel/profile.json` key; descriptions added for all 35 previously-undescribed keys.
- Added: `keel init` writes `plugins.recommended`; `keel doctor` names any recommended-but-disabled plugin with its install command.
- Added PL/SQL detection: the 14th language, and the first inferred rather than read from a manifest, when `.sql`/`.plsql` dominate with an Oracle-exclusive token; verify commands stay null.
- Added `conventions.explain_level` (`technical` default, `plain` opt-in): chat replies define a technical term on first use; artifacts unaffected.
- Changed: `gates.context_window` is now a floor, not a ceiling. `SCHEMA_VERSION` moves to 2, for `conventions.explain_level`; re-run `keel init` to pick it up, it merges, so your own values survive.
- Fixed: the session-prefix size check in `tests/test-session-start.sh` used a relative path with no lower bound, so it passed even with the hook deleted; `keel doctor` no longer leaks "integer expression expected" on an oversized `gates.context_window`.
- Fixed: a repo with an existing `.claude/settings.json` received no plugins from `keel init`; `keel doctor` now merges every settings scope, so user-scope plugins are no longer reported missing.
- Known gaps: resuming from a handoff is still manual; an enabled-but-not-installed plugin looks identical to a working one; `plugins.recommended` does not follow a project that changes stack; seven declared profile keys are read by nothing (`gates.tdd`, `gates.coding_standards`, `gates.review`, `gates.observability`, `gates.docs_updated`, `plugins.excluded`, `conventions.working_branch`).

## 0.10.0 - 2026-08-17

- keel is now public: `gbi-solutions-ltd/keel`, MIT licensed, 158 files, CI green. The former repository is `gbi-solutions-ltd/keel-internal`, kept private.
- History was swept before publishing: all 27 deny-pattern hits cleaned from six content files, the deny list's own history, and two commit messages. `docs/audits/` is deliberately withheld.
- License changed from all-rights-reserved to MIT; third-party attributions moved to `NOTICE`. The internal client-name deny list moved out of the tree to `KEEL_DENY_FILE`; an absent list degrades to generic patterns, not silence.
- Removed the `GBI_ALLOWED` exemption mechanism; shipped content now carries no organisation name. `gbai-defaults.md` renamed to `house-defaults.md`.
- Fixed two GitHub push-protection false positives by changing the fixtures rather than allowlisting the detections, plus a marketplace description, a license field, and a plan document with real client names.
- Fixed `tests/no-internal-leaks.sh`: a `grep | head -1` pipeline dropped a real match past roughly 5,000 matching lines due to SIGPIPE.
- The em/en-dash and broken-link writing rules now also apply under `docs/` and the repository root; starts green across 48 files.
- Eval run 2026-08-17 against `852e373`: 5 of 6 scenarios pass (`done-without-verifying` invalid, not run).

## 0.9.0 - 2026-08-17

- Folds in the perf work and go-public prep that had sat under `## Unreleased`.
- Decision 2's GBi-name extraction list is now enforced: 8 missed files neutralised; the scanner now fails on `\bGBi` outside the 5 declared files.
- Model pins documented in `README.md`: the four fan-out briefs use `sonnet`, `execute-plan`'s implementation and both reviews stay `inherit`; no brief uses `haiku`.
- Corrected 7 false claims in root docs (suite runtime, `keel doctor` runtime, hook count, the word ceiling, `SOURCES.md` credits, the project's own name, and a `gh`-only install requirement). Added `tests/test-doc-claims.sh`, deriving 5 counts from the tree.
- `repo-snapshot` section 10 now cites a per-language tool table across 13 languages. Added `docs/runbooks/going-public.md`.
- Performance: test suite 351.7s to 270.0s; `keel init` on a node project 2.021s to 0.818s, by caching two functions that previously spawned a fresh `python3` per read.
- Fixed 4 defects found reviewing the perf work: a newline in an npm script value lost the whole script; a literal dotted key was mishandled by the new cache; the script cache marked itself loaded before checking the file existed; two spawn-count assertions passed at zero.
- Known gap: behavioural evals not re-run for 0.9.0, deferred to whoever cuts the tag.

## 0.8.0 - 2026-08-17

- The "re-run keel init" warning now compares a new `schema_version` field (bumped only when a field is added, removed, renamed, or moved) instead of `keel_version`, firing only when the profile actually needs a change. Comparison is three-way: a profile from a newer keel says to upgrade the plugin, not re-run `init`.
- Added a validator: changing `templates/profile.schema.json`'s field set without bumping `schema_version` fails the build.
- `repo-snapshot` section 10 now requires a `security-audit --full` item and a `coding-standards` item on a first look at an unfamiliar repository, and the handoff names what was not checked.
- Declined: folding both audits directly into the snapshot (`docs/ideas/snapshot-surfaces-remediation-gaps.md`).
- Not gated on behavioural evals: `done-without-verifying` does not discriminate between arms.

## 0.7.1 - 2026-08-17

- `execute-plan` now ticks a checkbox only on output it read, and notes any step it did not witness rather than assuming a resumed step was done. From an eval finding on 2026-08-16, where an arm ticked "write the failing test" and "watch it fail" without doing either.
- `hooks/done-guard` unchanged (reads only one turn's tool calls). Not gated on behavioural evals: `done-without-verifying` still does not discriminate between arms.

## 0.7.0 - 2026-08-16

- `write-plan` now requires a `Done when:` line per task; `execute-plan` ticks a checkbox only on output it read; the compliance review gains a 5th question for missing `Done when:` output.
- Install is documented from the marketplace only: a plugin's `bin/` is on the Bash tool's PATH, so the two `/plugin` commands are a complete install. The PATH symlink is now optional.
- Added `conventions.response_style` (`terse` default, `verbose` opt-out): replies are short by default, artifacts unaffected.
- Added `hooks/done-guard` (`Stop`/`SubagentStop`): fires when a turn edited code and never ran the test command, not on keyword matching. Fails open, unlike `sensitive-guard`. Silent unless `gates.done_verified` is set; `keel init` writes `warn`.
- Added `output-styles/keel-terse.md`, `tests/test-cache-install.sh`, and `tests/test-session-start.sh` (6 cases).
- Every subagent brief now names its model: the four wide-reading fan-outs use `sonnet`; `execute-plan`'s implementation and both reviews stay `inherit`. No complexity router built (no hook event exposes model selection).
- SessionStart injection: 300 to 356 tokens, against a 250 target and 400 ceiling.
- Fixed: an unreadable `.keel/profile.json` no longer silences the whole session injection; `hooks/done-guard` no longer leaks "Permission denied" to stderr.
- Not covered: neither new eval scenario had been run yet; reply length unmeasured; `keel init` does not write `outputStyle`.

## Also in 0.7.0: the work that preceded these four suggestions

- Managed CLAUDE.md block at 628 tokens against a 450 target recorded as a departure, not silenced. ADR-0001 accepted. Lint now runs after every file edit, not once at the end.
- Documentation made part of the quality gate (`ship` check 6, review rubric). ADR alternatives must be stated as properties, never as episodes.
- `design-architecture --existing` gets its own reference, `existing-mode.md`; its library-fact fallback now reads vendor documentation directly when `context7` is unavailable.
- Added `hooks/sensitive-guard`: a `PreToolUse` hook emits `ask` when a `git commit` stages a file matching `hard_block_paths`; fails safe on any read or parse error.
- Sum of all skill descriptions bounded at 1,320 tokens. `write-docs` now prefers a generator (OpenAPI, JSDoc/docstrings, Conventional Commits) over hand-written prose where one exists, and a document is rewritten from the code rather than patched to argue with a past mistake.
- `keel doctor` now checks that every repo-relative markdown link in `README.md`, `CLAUDE.md`, `AGENTS.md`, and the docs root resolves against `HEAD`.
- All five behavioural evals re-run 2026-08-16, all passing. Skill body ceiling raised to 900 words; 700 becomes an enforced warning requiring a passing eval arm to exceed.

Found running the first `keel init` on an existing GBi service and a greenfield pilot:
- `keel init` corrupted a `.gitignore` with no trailing newline; now terminates the file first. `stack.datastores` was a hardcoded empty list; now detected from dependency manifests and compose files.
- `keel doctor` accepted a developer's global `.gitignore` in place of the repository's own; both checks now use `repo_ignores`.
- The plugin-less nudge fired even when the plugin was loaded; it now checks the reader's own skill list instead of `CLAUDE_PLUGIN_ROOT`, which project-registered hooks never receive.
- `keel init` no longer commits a per-machine marketplace source, or tells a greenfield project to run `repo-snapshot`, or warns about a missing test command for `project.kind: docs`.
- `write-prd --from-idea` now writes settled answers back to the source idea record. `write-user-stories` now asks only what the user can settle now, deferring the rest to a `decide` story.
- `keel profile get` printed Python's `True`/`False` instead of JSON `true`/`false`; `keel doctor` printed warnings and then said "no problems". Both fixed.
- `design-architecture` no longer requires an ADR for every `decide` story before an answer exists, and a design can no longer pass self-review while naming no stack.
- `write-plan`'s greenfield task 1 now creates the toolchain and writes real verify commands; `execute-plan` excepts a plan whose task 1 creates them.
- The ADR status table replaces ambiguous `proposed` with "Nobody has agreed it". The skill link check no longer rejects a link carrying an anchor, and `revise` mode's trigger now reads "vague, contradictory, or overtaken".

## 0.6.1 - 2026-08-14

- Fixed: the remedy message for a gitignored docs root printed a recipe git cannot honour; now prints the correct ordered recipe built from `docs_root`'s own path segments.
- Fixed: two lockfiles at once (`bun.lockb` and `package-lock.json`) were read as a `bun` declaration; now read as none, and `stack.package_manager` becomes `null`, distinct from `"none"`.
- Fixed: a project with no tests failed `keel doctor` on the derived `verify.test_one` field rather than warning on the root cause, `verify.test`.
- Added: `deploy.ci` and `deploy.target` are now detected from committed CI config and deploy target files, instead of always written null.

## 0.6.0 - 2026-08-13

### Breaking: renamed to `keel`

  | Was | Is |
  |---|---|
  | plugin `gbaiutils` | plugin `keel` |
  | marketplace `gbai` | marketplace `gbi` |
  | `/plugin install gbaiutils@gbai` | `/plugin install keel@gbi` |
  | skill refs `gbaiutils:tdd` | `keel:tdd` |
  | `bin/gbai`, the `gbai` command | `bin/keel`, the `keel` command |
  | `.gbai/profile.json` | `.keel/profile.json` |
  | `gbaiutils_version` in the profile | `keel_version` |
  | `GBAI_CONTEXT_WATCH`, `GBAI_APEX_CONN`, and the rest | `KEEL_*` |
  | `~/.gbai/apex-targets.json` | `~/.keel/apex-targets.json` |
  | default docs root `docs/gbai` | `docs/keel` |
  | `@@@GBAI-SECTION:` in APEX capture scripts | `@@@KEEL-SECTION:` |
  | `github.com/gbi-solutions-ltd/gbaiutils` | `github.com/gbi-solutions-ltd/keel` |

No compatibility fallback: nothing reads `.gbai/` any more. Four manual steps: rename the GitHub repository, re-point the `keel` PATH symlink, run `/plugin marketplace remove gbai` then add `gbi`, and rename any local clone directory.

Entries below 0.6.0 keep the old names on purpose.

- Added: keel now runs `keel init` on itself.
- Added: plugin keywords expanded from 7 to 35, covering the full skill catalogue.

## 0.5.0 - 2026-08-13

- Added `shape-idea`: turns a rough idea into a recorded decision `write-prd` can consume, or a decision not to build it. Writes `<docs_root>/ideas/<slug>.md`.
- Added `port-assess`: assesses moving an existing codebase to another stack. Writes `<docs_root>/port/<service>-assessment.md`. `write-prd --from-idea` now reads the idea record and skips questions it already answers.
- Push guard now refuses a push to the default branch, not only one the supply chain scan flags. Escape hatches: `git push --no-verify` or `conventions.protect_default_branch: false`.
- Fixed: `gbai init --team` staged everything it wrote except `.gitignore` itself, the file the flag exists to protect; the router and shipped cheatsheet had drifted, so the validator now requires every router destination to appear in the cheatsheet.
- Fixed: a `Read` deny rule did not stop `Bash` reading the same file; `gbai init` now also denies `cat`/`head`/`tail`/`less`/`more`/`strings` against `.env`, `secrets/`, `id_rsa*`. `port-assess` no longer shares `apex-port-plan`'s template.
- Documentation sweep: SessionStart injection now names all 24 skills (5 were missing). Skill descriptions: 55 tokens/request recovered; `DESC_MAX_CHARS` tightened from 260 to 216.

## 0.4.0 - 2026-08-13

- Added 8 new coding-standards references (rate-limiting, caching, authorisation, resilience, async-work, time-and-dates, api-contracts, data-protection), enforced via `review-code` and `security-audit`.
- Added `tests/supply-chain-scan.sh` (19 pattern, 4 structural rules) and `gbai scan`/`gbai guard install|status|uninstall`, an opt-in pre-push hook.
- Added plugin boundary detection in `gbai doctor`, and the context watchdog (`hooks/context-watch`): silent below 70% of the context window, warns 70-85%, denies tool calls past 85% until a handoff is written. Off via `GBAI_CONTEXT_WATCH=off`. `gbai doctor` now also enforces the managed CLAUDE.md block's token budget (warns over 450, fails over 700).
- First run against a real repository found and fixed: the watchdog would have hard-stopped every 1M-context session (fixed with an explicit override plus upward-only correction); `structural-binary` produced 20 false positives on a service repo, now scoped to plugin repositories; scan runtime cut from 7.9s to 1.75s.
- Fixed: `VERSION` and `.claude-plugin/plugin.json` had drifted (0.3.0 vs 0.2.0), so the APEX release reached nobody installed; both now move together, pinned by a test.
- Fixed: the supply chain scan read tracked files only, missing untracked new files; and two rules used a GNU-only regex that failed silently on other greps, so the scanner now refuses to start if any rule fails to compile.

## 0.3.0 - 2026-08-13

- Added `gbai apex-export`, `apex-export`, `apex-port-plan`: exports one Oracle APEX application via the dictionary views into a directory an agent can grep, with `xref.tsv` mapping every database object to every referencing page.
- Added `tests/test-apex-export.sh`, 39 cases, fixture-driven.
- Found and fixed against a live APEX 22.2 instance: roughly 20 wrong hand-written column names (now selects every catalog column except a small denylist); dependency scanning missed all triggers, now transitive (44 units became 169, 0 triggers became 87); long values in unrecognised columns were silently clipped; a fatal-error scan false-matched the application's own source; short source values were dropped entirely; an object named `JOIN` flooded `xref.tsv` with 54 false references (now 2); section markers were silently swallowed by SQLcl.
- Proved end to end against a 156-page application: zero warnings, 309 objects reached three levels deep, 169 PL/SQL units including 87 triggers, 104 tables.
- Known gaps: APEX automations, scheduled jobs, queue DDL, and sequences not extracted; only APEX 22.2 exercised; difficulty bands unvalidated against independent judgement.

## 0.2.0 - 2026-08-12

Released to move the plugin cache off `0.1.0` (Claude Code's plugin cache is keyed by version).

- Added the initial 20 skills: `repo-snapshot`, `write-prd`, `write-user-stories`, `design-architecture`, `write-plan`, `tdd`, `debug`, `execute-plan`, `coding-standards`, `review-code`, `security-audit`, `refactor`, `optimize-performance`, `setup-deployment`, `ship`, `write-docs`, `create-skill`, `context-budget`, `gbai` (router), `incident-response`.
- Added `tests/validate-skills.sh`, `tests/run-tests.sh`, a CI workflow, `templates/profile.schema.json`, `SOURCES.md`/`THIRD-PARTY-LICENSES.md`, `gbai new <name>` scaffolding, `tests/no-internal-leaks.sh` (found and fixed 8 leaks before shipping), an evals harness with 4 pressure scenarios (all passed), and the plugin-less nudge hook.
- Added `gbai init` permission guardrails: `deny` rules for secrets, `ask` rules for destructive commands in a committed `.claude/settings.json`; `bypassPermissions` isolated to a gitignored `.claude/settings.local.json`.
- Skill body budget split: 400 words single-path, 600 fan-out/multi-mode, 700-word hard ceiling.
- Fixed: `gbai` invoked through a symlink resolved its own install directory wrong; install instructions omitted PATH entirely; VS Code ignores `permissions.defaultMode`; `gbai doctor`'s `gh` check was wrong and now checks marketplace registration instead.
- Corrected: private-repo install works over HTTPS via the git credential helper, `gh` not required; a locally-sourced plugin install is a versioned copy, not a live link.
- Known gaps: no eval scenario combines multiple pressures; artifact-producing skills tested against real repositories rather than evals; several modes written but never run.
