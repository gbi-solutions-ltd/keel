# Adopt the agreed Claude Code features Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1 to 4. Tasks 5 and 6 change CI and records and say
> under their behaviours why they carry no failing test.

**Goal:** build the items agreed in `docs/ideas/claude-code-features-assessed-2026-10-29.md` that
never got built: a `sensitive-guard` that blocks when it fails to answer, `keel init` writing the
keel terse output style, the required plugins declared as `dependencies`, `claude plugin validate`
in CI, and the two doc corrections.
**Stories:** none. Items 1, 2, 3, 4 and 9 of
`docs/ideas/claude-code-features-assessed-2026-10-29.md`, agreed by Bernard on 2026-10-29 with its
four open questions answered there. The `EXIT` trap that item 1 waited on landed in `771c7a6`
(PR #7).
**ADRs:** ADR-0004 (a guarantee belongs to a repository and harness pair), ADR-0012 (a task carries
two steps), ADR-0013 (Claude Code is the only harness), ADR-0014 (the ledger: a primitive with no
source, version and date is not provided).
**Architecture:** one key on one generated hook entry, a ledger row for it, an init change with
the session-start change it pays for, two manifest fields, one CI step, and doc corrections. No new
component.
**Implementer routing:** inherit
**Delivery:** pull-request
**Concurrent batches:** none. Tasks 1 and 2 both write `lib/harness/capabilities` and the generated
`docs/harness-support.md`, four of six tasks touch `hard_block_paths`, and the Files blocks carry
notes, so `keel plan batches` runs every task alone; its output is under "Notes for the
coordinator".
**Decided:** Bernard, 2026-11-02, choosing among options put to him: CI runs `claude plugin
validate .` (errors fail, warnings do not) plus `claude plugin validate --strict
.claude-plugin/marketplace.json`; `dependencies` names the three required plugins only; `keel
init` adds `outputStyle` to an existing `.claude/settings.json` only when the key is absent, and
`hooks/session-start` stops injecting the terse paragraph when the style is set, which is where the
56 tokens are saved.
**Kept, not replaced:** the idea record's item 3 says `dependencies` replaces the `enabledPlugins`
that `keel init` writes. This plan keeps `enabledPlugins` unchanged: it is also how `keel@gbi`
itself, `context7`, `claude-md-management` and the detected language servers are enabled, and
`expected_plugins` feeds `keel doctor`. `dependencies` adds an install path for the three required
plugins; it removes nothing.
**Approved:** by Bernard, 2026-11-02: routing `inherit`, delivered to a pull request.
**Shape:** behaviours with examples.
**Reviewed:** by a dispatched plan reviewer on 2026-11-02: nothing blocking, seven should-fix and
three to consider. Every should-fix is folded in, and "What the review changed" records each.

## Evidence gathered while planning, 2026-11-02, Claude Code 2.1.316

Each of these replaces a "not checked" in the idea record's assumptions table.

- **`onFailure: "block"` blocks a timed-out PreToolUse hook.** A throwaway plugin loaded with
  `--plugin-dir` gave a Bash PreToolUse hook `sleep 20`, `timeout: 2` and `onFailure: "block"`,
  under `--permission-mode bypassPermissions`. The `touch` it guarded did not run, and the session
  reported `PreToolUse:Bash hook error: [...]: timed out; blocking because onFailure is "block"`.
  The control, the same hook without the key, let the `touch` run.
- **`outputStyle: "keel:keel terse"` in a project's `.claude/settings.json` takes effect.** With
  keel loaded by `--plugin-dir`, a session asked whether its system prompt held the heading
  `# Terse chat, full artifacts` (from `output-styles/keel-terse.md`, and absent from
  `hooks/session-start`) answered yes with the key set and no with `{}`.
- **An unresolvable style name falls back silently.** The same project settings, with keel not
  loaded, ran a `-p` session that answered normally with exit 0 and no warning. A teammate without
  keel installed loses nothing but the style.
- **The style carries everything `BREVITY` says.** `hooks/session-start`'s `BREVITY` paragraph says
  replies stay brief and artifacts full; say what changed, where, and what needs a decision; never
  omit checks run or skipped, assumptions, deviations, or a Done when command's output. Each is in
  `output-styles/keel-terse.md`, under its opening paragraphs and "Never compress". So task 3 drops
  no rule.
- **`@anthropic-ai/claude-code@2.1.316` is published.** `npm view` returned `2.1.316`.
- **`claude plugin validate` runs with no credentials.** Run with `HOME` set to an empty directory:
  `validate .` exits 0; `validate --strict .` exits 1 on one warning, "CLAUDE.md at the plugin root
  is not loaded as project context", because this repository's `CLAUDE.md` is its development
  guide and not shipped context; `validate --strict .claude-plugin/marketplace.json` exits 0. A
  missing-icon notice is a directory check and does not change the result. An empty `HOME` on macOS
  does not rule out a Keychain credential, so task 5's evidence is the Linux runner.
- **The dependency shape validates.** Copies of both manifests with `dependencies` (three
  `name@claude-plugins-official` strings) and `allowCrossMarketplaceDependenciesOn:
  ["claude-plugins-official"]` passed `validate --strict` each.
- **Plugin dependencies, from the docs** (code.claude.com/docs/en/plugins/dependencies and
  manifest-reference): entries are `"name"`, `"name@marketplace"` or an object; a `plugin.json`
  dependency on a marketplace not in the root marketplace's `allowCrossMarketplaceDependenciesOn`
  "install completes without the dependency and your plugin then fails to load"; the allowlist
  check "doesn't apply to a dependency that is already enabled"; dependencies install "at the same
  scope". **No minimum Claude Code version is documented** for `dependencies` or the allowlist.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`.
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Tasks 1, 2, 3 and 5 touch them, which is why
  routing is `inherit`.
- **keel's minimum Claude Code version stays 2.1.302.** `harness_min_version`
  (`lib/harness/resolve.sh:184`) takes the highest version over the `provides` rows a `requires`
  row names. A new row a gate requires is stamped with the version its source names, never the
  2.1.316 these probes ran on, unless Bernard decides to move the minimum.
- `hooks/hooks.json` and `docs/harness-support.md` are generated by
  `tests/generate-harness-artifacts.sh`; edit the generator or the ledger and regenerate, never the
  outputs by hand (`tests/test-harness-claims.sh:32-35` fails otherwise).
- A change lands with the documents it makes wrong, each stating what is true now. Repair any
  `path:line` citation your edit shifts (`tests/test-validate-citations.sh`).
- No em or en dashes anywhere, conventional commit messages, no attribution footers.
- Never `git stash`, in any form: the stash is shared by every worktree of this repository.
- `tests/test-harness-claims.sh:232` fails any line in `README.md` or `docs/NN-*.md` that names
  `session-start`, `sensitive-guard` or `hard_block_paths` without a `keel:claim` tag within three
  lines. Tasks 2, 4 and 6 edit those files: tag what you write the way the surrounding text does.
- New cases in `tests/test-harness-claims.sh` work on copies, never on `hooks/hooks.json` itself:
  `tests/run-tests.sh` runs four files at once (`tests/test-harness-claims.sh:41-44`).
- `tests/run-tests.sh` took 5m20s on 2026-11-02, so each task's boundary run costs about that.

---

### Task 1: `sensitive-guard` blocks when it fails to answer

**Story:** item 1 of the idea record
**Files:**
- Modify: `tests/generate-harness-artifacts.sh`
- Modify: `hooks/hooks.json` (regenerated)
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md` (regenerated)
- Modify: `hooks/sensitive-guard` (comments only: the header, and `:206-207`)
- Modify: `tests/test-sensitive-guard.sh` (the comment at `:589`)
- Test: `tests/test-harness-claims.sh`

**Interfaces:**
- Produces: the ledger primitive name `pretooluse_on_failure_block`

**Depends on:** none

**Behaviours:**

1. The `sensitive-guard` entry in `hooks/hooks.json` carries `"onFailure": "block"`. Example:
   reading `hooks/hooks.json` as JSON, the PreToolUse `Bash` hook whose command ends
   `hooks/sensitive-guard"` has `onFailure` equal to `"block"`.
2. No other hook entry carries `onFailure`. Example: `review-guard`, `context-watch`, `done-guard`
   and `session-start` entries have no `onFailure` key, because `review-guard` runs on every Bash
   call of every session and a failure there would block the main session too (the idea record,
   item 1).
3. The ledger records the primitive with a source, a version and a date, as a `provides` row and
   **no** `requires` row: the guard works without `onFailure`, and the ledger's rule is that "a gate
   requires what it cannot function without, not everything it can use"
   (`lib/harness/capabilities:57-63`, with `subagent_transcript_path` as the precedent). A
   `requires` row would stop the whole guard being generated if this evidence were withdrawn.
   Example: `lib/harness/capabilities` holds
   `provides|claude|pretooluse_on_failure_block|vendor:code.claude.com/docs/en/hooks onFailure block on a timed-out PreToolUse command hook, probed on 2.1.316 in docs/plans/2026-11-02-adopt-the-agreed-claude-code-features.md|2.1.295|2026-11-02`,
   and no line starts `requires|sensitive-guard|pretooluse_on_failure_block`.
3a. The generator emits the key from the ledger. `entry()` (`tests/generate-harness-artifacts.sh:125`)
   takes a hook and a timeout today; it gains an optional third argument, the failure policy, which
   the `sensitive-guard` group passes as `block` only when `harness_provides claude
   pretooluse_on_failure_block` holds. Example: a copy of the ledger with that row removed generates
   a `hooks.json` whose `sensitive-guard` entry has no `onFailure`, and the guard is still
   generated.
4. The minimum does not move. Example: `docs/harness-support.md`, regenerated, still reads
   "Minimum Claude Code version: 2.1.302".
5. The hook's comments say what happens on each failure: a crash is answered `ask` by the `EXIT`
   trap; a timeout or a hook that cannot start is blocked by `onFailure`, and the user retries.
   Example: the header names both and cites `hooks/hooks.json`; `hooks/sensitive-guard:206-207`
   no longer says "a killed hook gives no answer, so the command runs", and
   `tests/test-sensitive-guard.sh:589` no longer says "the commit goes through". The deadline
   inside the timeout stays, because a block costs a retry where an `ask` answers in time.

**Done when:** `tests/test-harness-claims.sh` and `tests/test-harness-resolve.sh` pass, and the
profile's lint command passes.

- [x] **Step 1.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 3a: add the cases to `tests/test-harness-claims.sh`, run it,
and watch them fail because no entry carries `onFailure` and no row names the primitive. Then add
the key in the generator for `sensitive-guard` alone, add the ledger row, regenerate
`hooks/hooks.json` and `docs/harness-support.md` with the generator, and write behaviour 5's
comment.
Run: `tests/test-harness-claims.sh`
Expected before the implementation: FAIL on behaviours 1, 3 and 3a. Expected after: PASS. Quote the
failing output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules. Then confirm behaviour 4 by reading the
regenerated `docs/harness-support.md`.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality nothing blocking, consider: the ledger row mixes vendor and probe evidence, the exact-row test is brittle to re-verification, the others check excludes sensitive-guard on every event; step 1.1 said two ledger rows where behaviour 3 says one, corrected in the plan

```bash
git add tests/generate-harness-artifacts.sh hooks/hooks.json lib/harness/capabilities \
        docs/harness-support.md hooks/sensitive-guard tests/test-sensitive-guard.sh \
        tests/test-harness-claims.sh
git status --porcelain
```

Stage exactly those paths, plus any doc whose citation you repaired, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "feat(sensitive-guard): block the call when the guard fails to answer"`. Paste the
`git status --porcelain` output into your report.

---

### Task 2: `keel init` writes the keel terse output style

**Story:** item 2 of the idea record
**Files:**
- Modify: `lib/harness/claude.sh` (`write_settings` and `merge_permissions_into_settings`)
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md` (regenerated)
- Modify: `README.md` (the output style paragraph, `README.md:85-87`)
- Modify: `docs/05-token-and-memory-design.md` (`:357`, the style's role)
- Modify: `docs/04-plugin-strategy.md` (the example settings `keel init` writes, `:136-151`)
- Test: `tests/test-keel-3.sh`

**Interfaces:**
- Produces: the settings key and value `"outputStyle": "keel:keel terse"`, read by task 3

**Depends on:** none

**Behaviours:**

1. A fresh project gets the style. Example: `keel init` in a repository with no
   `.claude/settings.json` writes one whose `outputStyle` is `"keel:keel terse"`, beside the
   existing `enabledPlugins`, `permissions` and `hooks`.
2. An existing settings file without the key gains it, and nothing else in the file changes beyond
   what the merge already adds. Example: `{ "enabledPlugins": { "someone-elses@thing": true } }`
   comes out with `outputStyle` `"keel:keel terse"` and `someone-elses@thing` still enabled.
3. A user's choice is never overwritten. Example: an existing file with `"outputStyle":
   "Explanatory"` still reads `"Explanatory"` after `keel init`.
4. Re-running init is a no-op for the key. Example: a second `keel init` leaves exactly one
   `outputStyle` key with the same value.
5. The ledger records the observation, with no `requires` row, so the minimum does not move.
   Example: `provides|claude|plugin_output_style_setting|probe:outputStyle keel:keel terse in a project .claude/settings.json loaded the plugin style and {} did not, docs/plans/2026-11-02-adopt-the-agreed-claude-code-features.md|2.1.316|2026-11-02`.
6. `README.md` says `keel init` selects the style for the project and that
   `.claude/settings.local.json`, which is git-ignored, overrides it for one developer. Example: the
   paragraph no longer calls the style "machine-wide rather than per-project", and the example in
   `docs/04-plugin-strategy.md:136-151` shows the `outputStyle` key.

**Done when:** `tests/test-keel-3.sh` and `tests/test-harness-claims.sh` pass, and the profile's
lint command passes.

- [ ] **Step 2.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 4 in `tests/test-keel-3.sh`, beside the existing case at
`tests/test-keel-3.sh:385`: run it and watch them fail because no `outputStyle` is written. Then
change both writers, add behaviour 5's row, regenerate `docs/harness-support.md`, and make the doc
edits in behaviour 6 and `docs/05-token-and-memory-design.md:357`.
Run: `tests/test-keel-3.sh`
Expected before the implementation: FAIL on behaviours 1 and 2. Expected after: PASS. Quote the
failing output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 2.2: Hand over**

```bash
git add lib/harness/claude.sh lib/harness/capabilities docs/harness-support.md README.md \
        docs/05-token-and-memory-design.md docs/04-plugin-strategy.md tests/test-keel-3.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(init): select the keel terse output style"`. Paste the
`git status --porcelain` output into your report.

---

### Task 3: `session-start` stops injecting the terse rule when the style carries it

**Story:** item 2 of the idea record, the saving decision 10 counts
**Files:**
- Modify: `hooks/session-start`
- Modify: `tests/validate-skills.sh` (the size loop at `tests/validate-skills.sh:582-610`)
- Modify: `docs/05-token-and-memory-design.md` (`:320` and `:355`, "four forms")
- Modify: `docs/prd/plain-language-chat.md` (FR-04 at `:86`, NFR-02 and NFR-05 at `:134` and `:137`)
- Test: `tests/test-session-start.sh` (including the four-form size case at `:246`)

**Interfaces:**
- Consumes: `"outputStyle": "keel:keel terse"`, from task 2

**Depends on:** task 2

**Behaviours:**

1. With the style set in the project's `.claude/settings.json` and a terse, technical profile, the
   `BREVITY` paragraph is not injected. Example: settings `{"outputStyle":"keel:keel terse"}` and
   no `conventions` keys: the output holds the router text and the version line, and not the
   `BREVITY` text.
2. Without the key, nothing changes. Example: settings `{}` with the same profile injects
   `BREVITY` exactly as before.
3. `.claude/settings.local.json` wins when it sets the key. Example: project settings set the
   style and local settings set `"outputStyle": "default"`: `BREVITY` is injected, because the
   developer turned the style off and the profile still asks for terse.
4. The plain forms are unchanged, since the style does not carry the plain-language rule. Example:
   `explain_level: plain` with the style set still injects `PLAIN_TERSE`.
5. The settings files are read from the `.claude/` beside the `.keel/` where the profile was
   found, not by a second walk, and matched with a builtin `case`, no python3. With no profile,
   nothing is read. Example: a session started in a subdirectory of a project with the style set
   omits `BREVITY`.
5a. The user-level settings file in the home directory is not read. Example: the style set only
   there still injects `BREVITY`, which duplicates the rule and costs the 56 tokens, the safe
   direction; the header says so.
6. The header's bound still holds and says so: the output gains one form, and it moves only when a
   person edits a settings file. Example: the header comment names the fifth form and that bound,
   and `docs/05-token-and-memory-design.md` and the PRD's FR-04, NFR-02 and NFR-05 say five forms
   and that the form depends on the settings file as well as the profile.
7. The size check covers the new form. Example: `tests/validate-skills.sh` sizes the output with
   the style set as well as the four profile combinations, and `tests/test-session-start.sh:246`
   measures five forms. The new form is strictly smaller than the terse technical one, so this case
   guards against a regression rather than one that can fail today; say so in your report.

**Done when:** `tests/test-session-start.sh` and `tests/validate-skills.sh` pass, and the profile's
lint command passes.

- [ ] **Step 3.1: Build it test first**

Follow `keel:tdd` for behaviours 1 to 5a in `tests/test-session-start.sh`: run it and watch
behaviours 1 and 5 fail because `BREVITY` is always injected for a terse profile. Then change the
hook, its header (behaviour 6) and the size loop (behaviour 7).
Run: `tests/test-session-start.sh`
Expected before the implementation: FAIL on behaviours 1 and 5. Expected after: PASS. Quote the
failing output in your report.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 3.2: Hand over**

```bash
git add hooks/session-start tests/validate-skills.sh tests/test-session-start.sh \
        docs/05-token-and-memory-design.md docs/prd/plain-language-chat.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(session-start): leave the terse rule to the output style when it is set"`.
Paste the `git status --porcelain` output into your report.

---

### Task 4: the required plugins install with keel

**Story:** item 3 of the idea record
**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `docs/04-plugin-strategy.md`
- Modify: `docs/03-install-and-distribution.md` (where it says how the required plugins arrive)
- Test: `tests/test-keel-4.sh` (beside the `VERSION` and `plugin.json` check at `:590-608`)

**Depends on:** none

**Behaviours:**

1. `plugin.json` declares exactly the three plugins `docs/04-plugin-strategy.md` marks **Install,
   required**. Example: `dependencies` is `["security-guidance@claude-plugins-official",
   "code-review@claude-plugins-official", "skill-creator@claude-plugins-official"]`, and a test
   reads both files and fails if a required row and the list disagree.
2. `marketplace.json` allows the official marketplace. Example: a top-level
   `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]` beside `plugins`. Without
   it, per the docs, keel installs and then fails to load.
3. `keel init`'s `enabledPlugins` is unchanged. Example: `expected_plugins`
   (`lib/harness/claude.sh`) still lists `keel@gbi`, the five static plugins and the detected
   language servers, and `keel doctor` still reports them.
4. Both manifests validate. Example: `claude plugin validate --strict
   .claude-plugin/marketplace.json` exits 0 and `claude plugin validate .` exits 0.
5. The docs state the cost Bernard accepted: a required plugin that cannot install now stops keel
   loading, where before it cost a `keel doctor` warning, and no minimum Claude Code version for
   `dependencies` is documented. Example: `docs/04-plugin-strategy.md` says this under its verdicts.

**Done when:** `tests/test-keel-4.sh` passes and `claude plugin validate .` exits 0.

- [ ] **Step 4.1: Build it test first**

Follow `keel:tdd` for behaviour 1 in `tests/test-keel-4.sh`: run it and watch it fail
because `plugin.json` has no `dependencies`. Then edit both manifests and the two docs.
Run: `tests/test-keel-4.sh`
Expected before the implementation: FAIL on behaviour 1. Expected after: PASS. Quote the failing
output in your report. Then run behaviour 4's two commands and quote their last lines.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.

- [ ] **Step 4.2: Hand over**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json docs/04-plugin-strategy.md \
        docs/03-install-and-distribution.md tests/test-keel-4.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plugin): declare the required plugins as dependencies"`. Paste the
`git status --porcelain` output into your report.

---

### Task 5: CI validates the manifests

**Story:** item 4 of the idea record
**Files:**
- Modify: `.github/workflows/ci.yml`

**Depends on:** task 4

**Behaviours:**

1. A new job of its own, `manifests`, not a step in `validate`, so the required "Validate skills
   and templates" check does not come to depend on the npm registry. It follows the workflow's
   pattern for new checks: advisory until it has a week of green runs, as `test-macos` was. Example:
   the job installs `@anthropic-ai/claude-code@2.1.316`, an exact version, and runs `claude plugin
   validate .` then `claude plugin validate --strict .claude-plugin/marketplace.json`, each failing
   the job on a non-zero exit.
2. The job uses no secret. Example: it references no `secrets.`, and the workflow's
   `permissions: contents: read` is unchanged.
3. The comment above the job says why the directory check is not `--strict` (the root `CLAUDE.md`
   is this repository's development guide, and strict treats the warning about it as an error),
   why it is advisory, and that the version is pinned by an exact version and not a hash, unlike
   the ruff install. Example: the comment names all three.

There is no failing test for this task: the evidence is a CI run. `tests/supply-chain-scan.sh`
already reads workflows; if it flags the install line, fix the line rather than suppressing it.

**Done when:** there is no local command. The `validate` job passes on the pull request with no
secrets, and the job log shows both `Validation passed` lines.

- [ ] **Step 5.1: Add the step and run what can run locally**

Add the step. Run the two validate commands and `tests/run-tests.sh` locally, and quote the last
lines. The job's own pass is checked on the pull request.

- [ ] **Step 5.2: Hand over**

```bash
git add .github/workflows/ci.yml
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "ci: validate the plugin and marketplace manifests"`. Paste the
`git status --porcelain` output into your report.

---

### Task 6: the records state what is true now

**Story:** item 9 of the idea record, and the records items 1 to 4 make wrong
**Files:**
- Modify: `docs/04-plugin-strategy.md` (`:8` and `:158`)
- Modify: `docs/07-open-decisions.md` (`:5-8`, the table rows 2 and 10, decision 2 at `:54`,
  decision 10's "STILL OPEN" paragraph)
- Modify: `docs/ideas/claude-code-features-assessed-2026-10-29.md` (Status, Next, assumptions)
- Modify: `CHANGELOG.md` (an Unreleased section)

**Depends on:** tasks 1 to 5

**Behaviours:**

1. `docs/04-plugin-strategy.md:8` no longer says every plugin is in `claude-plugins-official`.
   Example: it says each is listed there, and that Context7 and Playwright are external plugins the
   official marketplace lists, matching the `(external)` marks at `:24` and `:28`. `:158` no longer
   says "private repo".
2. `docs/07-open-decisions.md` says the repository is public. Example: row 2 and decision 2 read
   public, citing `docs/plans/2026-10-22-public-first-development.md` for when it changed, and the
   original private decision stays recorded as history.
3. Decision 10 is fully resolved. Example: the summary at `:5-8` no longer lists it as open, row 10
   reads resolved 2026-11-02, and the "STILL OPEN" paragraph is replaced by what tasks 2 and 3 did.
4. The idea record says what was built. Example: Status reads built 2026-11-02 for items 1 to 4
   and 9, Next reads nothing, and the assumptions rows this plan probed cite its evidence section.
5. `CHANGELOG.md` has an Unreleased entry per user-visible change: the guard blocking on failure,
   the output style, the dependencies, the CI check.

There is no failing test for this task: it changes records. `tests/test-validate-citations.sh` and
`tests/test-doc-claims.sh` check what can be checked.

**Done when:** `tests/run-tests.sh` passes.

- [ ] **Step 6.1: Edit the records and run the suite**

Make the edits, then run `tests/run-tests.sh` and quote its summary.

- [ ] **Step 6.2: Hand over**

```bash
git add docs/04-plugin-strategy.md docs/07-open-decisions.md \
        docs/ideas/claude-code-features-assessed-2026-10-29.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs: record the adopted Claude Code features and correct two docs"`.
Paste the `git status --porcelain` output into your report.

---

## Notes for the coordinator

- **Concurrent batches.** `keel plan batches` on 2026-11-02 printed every task alone, with these
  reasons:

  ```
  why: task 1 has a Files block not in the strict form, so its paths are unknown
  why: task 2 has a Files block not in the strict form, so its paths are unknown
  why: task 3 has a Files block not in the strict form, so its paths are unknown
  why: task 4 has a Files block not in the strict form, so its paths are unknown
  why: task 5 edits shared config .github/workflows/ci.yml
  why: task 6 has a Files block not in the strict form, so its paths are unknown
  ```
- **Release.** This plan does not bump the version. `ship` does, after task 6.
- **What the review changed.** The ledger row for `onFailure` is `provides` only, with the generator
  reading it (task 1, behaviours 3 and 3a); the guard's body comment and a test comment that say a
  timeout lets the commit through join task 1; the five-form docs and PRD requirements join task 3,
  with where the settings file is read settled (behaviours 5 and 5a); task 4's test moved to
  `tests/test-keel-4.sh`, beside the existing manifest check; the vocabulary scan joined the global
  constraints; task 5 became its own advisory job; the settings example and a "private repo" in
  `docs/04-plugin-strategy.md` joined tasks 2 and 6; `enabledPlugins` is kept, and the header says
  why; each Done when line names lint where the task edits shell.
- **Not in this plan:** items 5 to 8 of the idea record, and the implementer `git stash` question,
  which is `docs/ideas/implementers-run-git-stash.md`.
