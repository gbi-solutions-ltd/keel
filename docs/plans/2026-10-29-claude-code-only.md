# Remove Codex support: keel on Claude Code only Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** this repository serves Claude Code only: every Codex path is gone, `keel init` writes no
`AGENTS.md`, and keel states and checks the minimum Claude Code version its gates need.
**Stories:** none. Bernard chose on 2026-10-29 to plan from the design instead of writing a PRD and
stories first, so write-plan's stories step is skipped by that decision. The requirements are the
design's goals G1 to G4 and the verification clauses of ADR-0013 and ADR-0014.
**ADRs:** ADR-0013 (Claude Code is the only harness), ADR-0014 (the manifest becomes a Claude Code
feature ledger), ADR-0012 (a task carries two steps), ADR-0011 (task 8 edits skill bodies and
references, so the release that ships this owes a gate arm for skill text)
**Architecture:** [`docs/architecture/claude-code-only.md`](../architecture/claude-code-only.md).
A probe settles first whether Codex would still run keel's hooks once its manifest is gone. Then
the Codex branches leave the hooks, the multi-harness plumbing leaves `bin/keel`, the Codex rows
leave the ledger and its generated artifacts, and only then does the ledger gain its new consumer,
the derived minimum version. Skill wording, the eval tooling and the documents follow.
**Implementer routing:** inherit
**Delivery:** pull-request
**Concurrent batches:** none. Every task repairs the citations its own edits break, wherever they
are, so no task's files are fully known before it runs and none may share a tree with another.
`keel plan batches` output is recorded under "Notes for the coordinator".

## Global constraints

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}` (for example
  `tests/test-sensitive-guard.sh`), lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh
  lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh
  tests/evals/isolation-check.sh hooks/session-start hooks/context-watch hooks/sensitive-guard
  hooks/done-guard hooks/review-guard`. No typecheck or format command exists.
- Never start on `main`. Work on `design/claude-code-only` or a branch cut from it.
- `hard_block_paths` in `.keel/profile.json`: `hooks`, `lib/harness`, `settings.json`,
  `.github/workflows`, `templates/ci-review.yml`, `lib/context_watch.py`. Tasks 2, 3, 4, 6 and 7
  touch them, which is why routing is `inherit`.
- **History is not edited to remove Codex.** History is `CHANGELOG.md` entries for released
  versions, `docs/plans/`, `docs/audits/`, `docs/ideas/`, `docs/decisions/`, `tests/evals/results.md`,
  `docs/architecture/tiered-multi-harness-support.md`,
  `docs/architecture/tiered-multi-harness-claim-inventory.md` and
  `docs/stories/tiered-multi-harness-support.md`. Bernard decided on 2026-10-29 that ADR-0013's
  verification clause, which lists changelog, plans, audits and superseded documents, is read as
  covering every record directory. ADRs are never edited beyond a status row.
- **Every task repairs every citation its own edits break, wherever it is, history included.**
  `tests/validate-citations.sh` checks `path:line` citations, and `tests/validate-skills.sh` checks
  the `x-keel-read-by` markers in `templates/profile.schema.json`. Repointing a pointer in a record
  is allowed (`tests/validate-citations.sh:165-167`). A citation into a file a task deletes becomes
  the backticked path without a line, followed by "(deleted after v0.26.0)". Both validators run in
  every task's `Done when:`, because removing lines is what this plan does and moved lines are what
  they catch. A red from either during a task is that task's, never "a red this task did not cause".
- ADR-0014: a `provides|claude` row grants its primitive only with source, version and date all
  present. Absent evidence fails, never passes.
- A schema bump lands in one commit with its fingerprint in `tests/validate-skills.sh`
  (`schema_fingerprint_for`), its pin in `tests/test-doc-claims.sh`, and this repository's own
  `.keel/profile.json`.
- `docs/standards.md`: scripts parse under bash 3.2; prose wraps at 100 columns; every rule carries
  its reason; shipped prose states the current state and history lives in the changelog; a check is
  never stricter than correct output.
- No em dash or en dash anywhere, in code, comments, docs or commit messages.
- Commits are conventional, signed off (`git commit -s`), with no attribution footer. Never
  `git add -A`, `git add .` or `git commit -a`: stage named paths.

---

### Task 1: Probe whether Codex runs keel's hooks without `.codex-plugin/`, and how a Codex user installs v0.26.0

**Story:** G3, ADR-0013
**Files:**
- Modify: `docs/architecture/claude-code-only.md`

**Interfaces:**
- Consumes: Codex CLI on this machine (`codex-cli 0.153.4` on 2026-10-29)
- Produces: a probe record in `docs/architecture/claude-code-only.md` section 7, with a verdict line
  reading exactly `Codex loads keel's hooks without .codex-plugin: yes` or `... : no`, and an
  install line reading `Codex install at v0.26.0: <the command>`. Tasks 2 and 10 read both lines

**Depends on:** none

**Behaviours:**

1. The probe runs against a throwaway `CODEX_HOME` and a copy of this repository at the current
   commit with `.codex-plugin/` removed, never against `~/.codex`. Example: after the probe,
   `~/.codex/config.toml` is byte-identical to before it, and the throwaway directory is deleted.
2. The copy's `hooks/hooks.json` has one extra `SessionStart` or `PreToolUse` hook that writes a
   marker file, and the probe trusts the plugin's hooks as Codex requires. Example: the record says
   whether the marker file existed after one `codex exec` run of a harmless prompt such as
   `echo hi`.
3. The verdict line follows the evidence. Example: Codex refuses to install the copy, or installs it
   and the marker is absent after trusting: `no`. The marker is present: `yes`.
4. The install line is a command the probe ran. Example: the command installs keel from
   `gbi-solutions-ltd/keel` at the `v0.26.0` tag into a second throwaway `CODEX_HOME`, and the
   record quotes the output line showing the plugin installed at that ref. If no command can pin a
   ref, the line names the fallback the probe ran instead, such as cloning the tag and installing
   from the local path.
5. The record carries the date, the Codex version, and the exact commands, so it can be re-run.

**Done when:** there is no command. This is a probe against an external tool, and its output is the
record; the reviewer checks the record names its commands and that `~/.codex` was not touched.

- [x] **Step 1.1: There is no test for this** Note: probe run by the implementer, not witnessed by the coordinator; spec reviewer re-checked the ~/.codex checksum and the tag commit

This task is a probe of Codex's behaviour, which no test in this repository can exercise. Run it as
the behaviours say, then write the record. Run `tests/validate-citations.sh` after writing it.
Expected: OK.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES, three wording points noted (install line joins two commands)

```bash
git add docs/architecture/claude-code-only.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -s -m "docs(architecture): record whether Codex runs keel's hooks without its manifest"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 2: `sensitive-guard` drops the Codex block, or keeps only a refusal, per the probe

**Story:** G1, ADR-0013
**Files:**
- Modify: `hooks/sensitive-guard`
- Test: `tests/test-sensitive-guard.sh`

**Interfaces:**
- Consumes: task 1's verdict line
- Produces: nothing new. The hook no longer sources `lib/harness/resolve.sh`

**Depends on:** task 1

**Behaviours:**

1. The hook no longer sources the resolver or reads the capability ledger. Example: `grep -c
   resolve.sh hooks/sensitive-guard` prints 0, and the cases in `tests/test-sensitive-guard.sh` for
   an unresolvable or unreadable manifest are removed, since they would pass while testing nothing.
2. **If task 1's verdict is `no`:** the hook does not detect Codex, and its `EXIT` trap answers
   `ask` on every exit but 0. Examples: with `CODEX_VERSION=0.153.4` set, a profile listing
   `src/auth` and `src/auth/t.go` staged, `git commit -m x` gets the same `ask` and exit 0 as without
   the variable; a `python3` shim earlier on `PATH` that exits 2 makes the same commit print the
   `ask` decision with "the guard failed unexpectedly" and exit 0; `grep -ic codex
   hooks/sensitive-guard tests/test-sensitive-guard.sh` prints 0 for both.
3. **If task 1's verdict is `yes`:** the hook keeps one refusal, with no resolver, at the point it
   refuses today: after the cheap gate and the empty-list check, so only a command that looks like a
   commit in a repository declaring a non-empty `hard_block_paths` reaches it, keeping the header's
   rule that a repository asking for nothing is never blocked. There, `CODEX_VERSION` set makes it
   print to stderr that Codex discards `ask` and that Codex users stay on v0.26.0, and exit 2. A
   comment above it cites task 1's record. The trap keeps exempting 0 and 2. Examples: with
   `CODEX_VERSION=0.153.4` set, a profile listing `src/auth` and `git commit -m x`, the hook exits 2
   and its stderr names v0.26.0; with the same variable and `ls`, or with a profile declaring
   `"hard_block_paths": []`, it exits 0 with no output.
   (Corrected by the coordinator on 2026-10-30, before task 2 was dispatched: the first wording
   refused every Bash event on Codex, which contradicted the hook's own invariant.)
4. Everything the hook did on Claude Code is unchanged. Example: the existing cases that set no
   `CODEX_VERSION` and do not depend on the resolver pass unchanged, including the crash case and
   the unreadable-profile case.

**Done when:** `tests/test-sensitive-guard.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

- [x] **Step 2.1: Build it test first** Note: built by the implementer; red quoted (25 passed, 2 failed) and reproduced by the spec reviewer against HEAD's hook

Follow `keel:tdd` for each behaviour that applies under task 1's verdict: write its test from the
example, run it, and watch it fail for the reason the behaviour names, then write the minimal
implementation and watch it pass.
Run: `tests/test-sensitive-guard.sh`
Expected before the implementation: FAIL. Under `no`, the case for behaviour 2 fails because the
hook exits 2 with `CODEX_VERSION` set. Under `yes`, the case for behaviour 3 fails because the hook
reads the ledger and its message does not name v0.26.0. Expected after: PASS. Quote the failing
output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 2.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES after a retry (first reviewer lost to a network error); quality: no blocking, four should-fix carried into task 2b and task 10

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh
git status --porcelain
```

Stage those paths, and any file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "fix(sensitive-guard): drop the Codex branch the probe allows"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 2b: `sensitive-guard` detects Codex by a signal its hook actually receives

Added by the coordinator on 2026-10-30 from task 2's quality review, which found the refusal keys on
`CODEX_VERSION` while ADR-0004 records that variable as set for shell commands Codex's exec tool
runs, and names the `turn_id` field of a hook's stdin payload as the hook-side signal. If the hook
process does not inherit the variable, the refusal never fires on Codex and the sensitive commit
goes through with its `ask` discarded.

**Story:** G1, ADR-0013
**Files:**
- Modify: `hooks/sensitive-guard`
- Modify: `docs/architecture/claude-code-only.md` (the probe record in section 7 only)
- Test: `tests/test-sensitive-guard.sh`

**Interfaces:**
- Consumes: task 2's refusal block
- Produces: two lines in section 7's probe record: `Codex hook environment has CODEX_VERSION: no`
  and `Codex hook payload has turn_id: not measured`, each followed by its evidence

**Depends on:** task 2

**Behaviours:**

1. The record says what was and was not measured. Example: section 7 gains the two Interfaces lines.
   The evidence for the first is the 2026-10-30 run: Codex's `SessionStart` hook ran with no
   `CODEX_VERSION` in its environment, and its payload keys were `cwd`, `hook_event_name`, `model`,
   `permission_mode`, `session_id`, `source` and `transcript_path`. The second says `PreToolUse`
   never fired because the run's `codex exec` failed authentication, so `turn_id` was not observed,
   and that Bernard chose on 2026-10-30 to detect both signals rather than probe again. No further
   probe is run.
   (Revised by the coordinator on 2026-10-30: the first probe cost the user's Codex login, see the
   notes.)
2. The refusal fires on either signal. Examples: an event containing `"turn_id":"t1"` with no
   `CODEX_VERSION`, a profile listing `src/auth` and `git commit -m x` exits 2 with stderr naming
   keel v0.26.0; the same with `CODEX_VERSION=0.153.4` set and no `turn_id` also exits 2; a Claude
   Code event with neither still gets `ask` and exit 0. The `turn_id` match is a builtin `case` on
   the raw event for the JSON key `"turn_id"`, in the style of the commit filter.
3. The refusal names keel's release once, unambiguously. Example: its stderr reads that keel v0.26.0
   is the last keel release that supports Codex and gives the install line from section 7's probe
   record; it does not say "stay on v0.26.0" next to the word Codex alone.
4. The dead CDPATH guard goes. Example: line 34's `unset CDPATH` and its comment are removed, since
   no `cd` remains in the hook, and the CDPATH case in `tests/test-sensitive-guard.sh` is either
   removed or kept as a plain "run by a relative path" case whose comment names no resolver.

**Done when:** `tests/test-sensitive-guard.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

- [x] **Step 2b.1: Build it test first** Note: built by the implementer after a revision mid-task (detect both signals); reds quoted for behaviours 2 to 4; the first probe run failed auth and was not repeated

Write behaviour 1's record first; then follow `keel:tdd` for behaviours 2 to 4: write each test
from its example, watch it fail for the reason it names, then implement.
Run: `tests/test-sensitive-guard.sh`
Expected before the implementation: FAIL, the case for behaviour 3 fails because the message says
"stay on v0.26.0", and the case for behaviour 2 fails because the hook asks instead of exiting 2 on
a `turn_id` event. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 2b.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, five should-fix or consider carried into task 2c and task 10

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh docs/architecture/claude-code-only.md
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "fix(sensitive-guard): detect Codex by the signal its hooks receive"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 2c: `sensitive-guard` never reads a Claude Code session as Codex

Added by the coordinator on 2026-10-30 from task 2b's quality review. Claude Code 2.1.314's
`MessageDisplay` hook input already carries `turn_id`, so if its `PreToolUse` input ever gains one,
the refusal would hard-block sensitive commits on Claude Code. Bernard chose on 2026-10-30 to gate
the refusal on `CLAUDE_PROJECT_DIR` being empty: Claude Code exports it to hook processes, and the
Codex 0.153.4 binary has no such variable.

**Story:** G1, ADR-0013
**Files:**
- Modify: `hooks/sensitive-guard`
- Modify: `docs/architecture/claude-code-only.md` (the "Probe: what a Codex hook receives" record only)
- Test: `tests/test-sensitive-guard.sh`

**Interfaces:**
- Consumes: task 2b's refusal and its two detection signals
- Produces: nothing new

**Depends on:** task 2b

**Behaviours:**

1. The refusal fires only when `CLAUDE_PROJECT_DIR` is empty or unset, and then on either signal.
   Examples, each with a profile listing `src/auth`, `src/auth/t.go` staged and `git commit -m x`:
   `CLAUDE_PROJECT_DIR` unset and `"turn_id":"t1"` in the event exits 2; `CLAUDE_PROJECT_DIR` unset
   and `CODEX_VERSION=0.153.4` exits 2; `CLAUDE_PROJECT_DIR=/repo` with `"turn_id":"t1"` in the event
   prints the `ask` decision and exits 0; `CLAUDE_PROJECT_DIR=/repo` with `CODEX_VERSION=0.153.4`
   prints the `ask` decision and exits 0. Every Codex case sets or unsets the variable explicitly,
   so the result does not depend on the environment the suite runs in.
2. The `turn_id` match is on the key, not a value. Example: the pattern is `*'"turn_id":'*`, an
   event whose `tool_input.description` is exactly `turn_id` (so the raw event holds
   `"description":"turn_id"`) with `CLAUDE_PROJECT_DIR` unset and no `CODEX_VERSION` gets `ask`, and
   the compact `"turn_id":"t1"` event still exits 2.
3. The hook's comment states what is known and cites it. Example: it says Codex's `PreToolUse`
   input requires `turn_id` per its schema (the citation already used in
   `docs/decisions/ADR-0004-a-guarantee-belongs-to-a-repository-and-harness-pair.md`), that its
   `SessionStart` input has none, that Claude Code's `PreToolUse` input had none on 2.1.314 while its
   `MessageDisplay` input does, and that `CLAUDE_PROJECT_DIR` is why that cannot turn into a block.
   The probe record gains one sentence saying the observed `SessionStart` keys are consistent with
   a schema that requires `turn_id` on `PreToolUse` and not on `SessionStart`.
4. The CDPATH case asserts behaviour, not text. Example: the case added by task 2b that greps the
   hook for `CDPATH` is removed, or replaced by one that fails only when the hook contains a `cd`
   and no `CDPATH` guard; the plain relative-path case stays.

**Done when:** `tests/test-sensitive-guard.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

- [x] **Step 2c.1: Build it test first** Note: built by the implementer; red quoted (33 passed, 3 failed) and reproduced by the spec reviewer against HEAD's hook

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-sensitive-guard.sh`
Expected before the implementation: FAIL, the cases for behaviour 1 with `CLAUDE_PROJECT_DIR=/repo`
fail because the hook exits 2, and the case for behaviour 2 fails because a `"turn_id"` value is
read as the key. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 2c.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, the CDPATH text check is stricter than correct output and the gate's limit is unstated, both in the follow-ups

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh docs/architecture/claude-code-only.md
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "fix(sensitive-guard): never read a Claude Code session as Codex"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 3: `done-guard` and the context watch read Claude Code transcripts only

**Story:** G1, ADR-0013
**Files:**
- Modify: `hooks/done-guard`
- Modify: `lib/context_watch.py`
- Modify: `templates/profile.schema.json` (its `x-keel-read-by` markers into the two files)
- Test: `tests/test-done-guard.sh`
- Test: `tests/test-context-watch.sh`
- Plus each file whose citation into `hooks/done-guard` or `lib/context_watch.py` this task's edits
  break. The review found these: `lib/harness/capabilities:66`, `docs/snapshot.md:72`,
  `docs/profile-keys.md:59`, `tests/validate-skills.sh:885`,
  `docs/ideas/declared-profile-keys-take-effect.md:83` and
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md` lines 402 and 810

**Interfaces:**
- Consumes: nothing new
- Produces: nothing new. `is_codex_rollout`, `_codex_turn_id`, `codex_turn_tool_calls`,
  `_measure_codex`, `declared_window`, `_window_over` and the `codex` value of `transcript_kind` are
  removed

**Depends on:** none

**Behaviours:**

1. `done-guard` reads the turn's tool calls from a Claude Code transcript as before. Example: the
   existing Claude Code transcript cases in `tests/test-done-guard.sh` pass unchanged.
2. A rollout-shaped transcript is no longer read as one, so the guard stays silent on it, which is
   its fail-open behaviour for a transcript it cannot read. Example: a transcript written inline in
   the test, one row in the rollout shape the old reader recognised (a `turn_context` row then a
   `custom_tool_call` row for `apply_patch` editing `src/a.py`, and no test run), under
   `gates.done_verified: required`, makes `done-guard` block before this task and produce no output
   and exit 0 after it. (Corrected by the coordinator on 2026-10-30 from task 3's report: the old
   reader picks up `custom_tool_call` rows only, so a `function_call` row was silent before the task
   and its test could not have gone red.)
3. The context watch measures Claude Code transcripts as before. Example: the existing Claude Code
   cases in `tests/test-context-watch.sh` pass unchanged, and the cases for a declared window on a
   rollout are removed.
4. The rollout readers and their cases are removed. Example: `grep -ic codex hooks/done-guard
   lib/context_watch.py tests/test-done-guard.sh tests/test-context-watch.sh` prints 0 for each.
5. Every citation and schema marker into the two files still resolves. Example:
   `tests/validate-citations.sh` reports OK and `tests/validate-skills.sh` reports no FAIL for
   `gates.context_warn_pct` or any other `code:lib/context_watch.py` marker.

**Done when:** `tests/test-done-guard.sh` and `tests/test-context-watch.sh` pass, and
`tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 3.1: Build it test first** Note: built by the implementer; red quoted (22 passed, 1 failed) and reproduced by the spec reviewer against HEAD; behaviour 2's row type corrected in the plan from the implementer's finding

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-done-guard.sh`
Expected before the implementation: FAIL, the case for behaviour 2 fails because `done-guard` reads
the rollout row and blocks. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 3.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, three should-fix (snapshot.md:173 citation moved to task 10, a test comment, the schema sentence task 4 owns) and six consider, in the final report

```bash
git add hooks/done-guard lib/context_watch.py templates/profile.schema.json \
        tests/test-done-guard.sh tests/test-context-watch.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "refactor(hooks): read Claude Code transcripts only"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 4: `bin/keel` serves one harness, and `harnesses` is retired in schema 7

**Story:** G1, G3, ADR-0013, ADR-0014
**Files:**
- Modify: `bin/keel`
- Modify: `bin/keel-fleet`
- Modify: `lib/harness/claude.sh`
- Modify: `templates/profile.schema.json`
- Modify: `tests/generate-profile-keys.sh`
- Modify: `docs/profile-keys.md` (regenerated by `tests/generate-profile-keys.sh`)
- Modify: `.keel/profile.json` (`schema_version` only)
- Modify: `tests/validate-skills.sh` (the `schema_fingerprint_for` entry for 7)
- Modify: `tests/test-doc-claims.sh` (the `SCHEMA_VERSION` pin)
- Test: `tests/test-keel.sh`, `tests/test-keel-2.sh`, `tests/test-keel-3.sh`, `tests/test-keel-4.sh`,
  `tests/test-keel-5.sh`, `tests/test-keel-fleet.sh`
- Plus each file whose citation into `bin/keel` or `lib/harness/claude.sh` this task's edits break,
  including the `code:lib/harness/claude.sh` markers in `templates/profile.schema.json`

**Interfaces:**
- Consumes: nothing new
- Produces: `SCHEMA_VERSION=7` in `bin/keel`; a `retired_keys` row `harnesses|7|<message>` whose
  message reads "This plugin serves Claude Code only, and Codex support ended at v0.26.0. Delete the
  key."; `keel doctor --json` without a `harnesses` field; `keel-fleet` output without a harnesses
  column

**Depends on:** none

**Behaviours:**

1. `--harness` is refused with a reason rather than silently ignored, since init ignores unknown
   flags (`bin/keel:1450`) and a user passing it expects it to do something. Example: `keel init
   --harness codex` exits 1 with a message naming `--harness`, "Claude Code only" and v0.26.0, and
   writes nothing.
2. `keel init` writes no `harnesses` key and no `.codex/` file. Example: `keel init` in a fresh
   repository that also contains a tracked `.codex/config.toml` produces a `.keel/profile.json`
   with `"schema_version": 7` and no `harnesses` key, and creates no file under `.codex/`.
3. A schema 6 profile that lists `harnesses` still loads, and doctor reports the key as retired.
   Example: `keel doctor` on a profile with `"schema_version": 6` and `"harnesses": ["claude",
   "codex"]` prints a warning naming `harnesses`, "retired in schema 7" and v0.26.0, alongside the
   existing schema 6 warning.
4. Doctor reports the agent files keel wrote for Codex as no longer managed. Example: `keel doctor`
   in a repository with `.codex/agents/keel-fanout.toml` or `.codex/agents/keel-implementer.toml`
   prints one warning that this plugin no longer manages them, naming v0.26.0; a repository with
   only its own `.codex/config.toml` gets no such line.
5. Doctor drops its harness detection. `harness_running`, the "running under" and "cannot determine
   which harness" lines, the Codex trust parser, the Codex install warning and the `running = codex`
   branches of the context window messages are removed. Example: with `CODEX_HOME` pointing at a
   `config.toml` containing `[hooks.state."keel"]` and `CODEX_VERSION` set, `keel doctor` prints the
   same lines as without them, and the `HSECTION` filter in `tests/test-keel-4.sh` is updated to the
   lines that remain.
6. `keel doctor --json` and `keel-fleet` lose the harness set. Example: `keel doctor --json` after
   init has no `harnesses` key, and `keel-fleet` over one repository prints no harnesses column;
   `tests/test-keel-2.sh` and `tests/test-keel-fleet.sh` assert both.
7. The multi-harness plumbing is gone. Example: `grep -nE
   'harness_each|HARNESS_SET|harness_set_for_repo|harness_hooks_trusted|HARNESS_FLAG|harness_running'
   bin/keel` prints nothing. `grep -ni codex bin/keel` prints only the message lines of behaviours
   1, 3 and 4, and each carries a trailing comment `# names Codex: the v0.26.0 notice`.
8. `lib/harness/claude.sh` keeps its writers and loses the "six functions, and codex.sh implements
   the same six" contract language. Example: the test asserting claude.sh implements the contract by
   name is removed, `grep -ic codex lib/harness/claude.sh` prints 0, and `keel init` writes the same
   `.claude/settings.json` as before this task for a Claude-only repository.
9. The schema, its fingerprint, its pin, its generated page and this repository's profile move to 7
   together. Example: `templates/profile.schema.json` has no `harnesses` property and no Codex text
   (today at lines 348, 378 and 518); `tests/validate-skills.sh` reports no fingerprint failure;
   `tests/test-doc-claims.sh` passes with its pin at 7 and the dogfood check reading 7 from
   `.keel/profile.json`; regenerating `docs/profile-keys.md` produces no diff.

**Done when:** `tests/test-keel-4.sh`, `tests/test-keel-2.sh` and `tests/test-keel-fleet.sh` pass,
and so do `tests/test-keel.sh`, `tests/test-keel-3.sh`, `tests/test-keel-5.sh` and
`tests/test-doc-claims.sh`; `tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 4.1: Build it test first** Note: built by the implementer; red reproduced by the spec reviewer against HEAD's bin/keel (test-keel-4 90 passed, 22 failed); report's red came from an earlier test-file state

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass. The
Codex sections of `tests/test-keel-4.sh` ("which harnesses a repository serves" and "a repository
that serves Codex") are removed in this step, after the new cases for behaviours 1 to 6 are written
and seen failing.
Run: `tests/test-keel-4.sh`
Expected before the implementation: FAIL, the cases for behaviours 1, 2 and 3 fail because init
accepts `--harness`, writes `harnesses` and schema 6, and doctor reports no retired key. Expected
after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 4.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, parser blindness moved to task 4b, doc lines and citation drift sweep to task 10

```bash
git add bin/keel bin/keel-fleet lib/harness/claude.sh templates/profile.schema.json \
        tests/generate-profile-keys.sh docs/profile-keys.md .keel/profile.json \
        tests/validate-skills.sh tests/test-doc-claims.sh tests/test-keel.sh tests/test-keel-2.sh \
        tests/test-keel-3.sh tests/test-keel-4.sh tests/test-keel-5.sh tests/test-keel-fleet.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
`lib/harness/codex.sh` stays until task 6, because `tests/test-harness-claims.sh` still resolves
the delegation profiles through it. **Do not commit.** The coordinator commits after both review
passes, with `git commit -s -m "refactor(keel): serve one harness, and retire profile.harnesses in schema 7"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 4b: the retired-key checks read the register by running it

Added by the coordinator on 2026-10-30 from task 4's quality review: task 4 wrote the `harnesses`
row of `retired_keys` as a `printf` so it could carry a comment, and `tests/test-doc-claims.sh`
still parses the register's text, so its "this repository's own profile sets no retired key" case
reads the key as `printf '%s\n' 'harnesses` and cannot see it.

**Story:** G1, ADR-0013
**Files:**
- Modify: `tests/test-doc-claims.sh`
- Modify: `tests/validate-skills.sh`
- Modify: `lib/harness/claude.sh` (its header comment only)
- Test: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: `retired_keys` in `bin/keel`, which prints one `path|version|message` row per line
- Produces: nothing new

**Depends on:** task 4

**Behaviours:**

1. Both checks read the register by running `retired_keys` from `bin/keel`, not by parsing its
   source. Example: with a copy of `.keel/profile.json` that gains `"harnesses": []`, the
   test-doc-claims case for this repository's own profile fails naming `harnesses`; without it, the
   case passes. `tests/validate-skills.sh` still reports `harnesses` as declared.
2. A row spelled another way is still read. Example: in a fixture `bin/keel` whose `retired_keys`
   emits one row with `echo "foo.bar|7|gone"`, both checks read the key `foo.bar`; a
   test-validate-skills case pins it.
3. `lib/harness/claude.sh`'s header lists every function `bin/keel` calls from it. Example: the list
   names `harness_context_file` and `harness_config_dirs`, and says `cmd_doctor` calls
   `harness_context_file` as well as `harness_doctor_findings`.

**Done when:** `tests/test-doc-claims.sh` and `tests/test-validate-skills.sh` pass, and
`tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 4b.1: Build it test first** Note: built by the implementer; both reds reproduced by the spec reviewer against HEAD's parsers

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-doc-claims.sh` and `tests/test-validate-skills.sh`
Expected before the implementation: FAIL, the case for behaviour 1 passes on a profile that sets
`harnesses`, so its negative variant fails; the case for behaviour 2 fails because an `echo` row is
not parsed. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 4b.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, the extraction can fail silently and is duplicated, which task 4c removes

```bash
git add tests/test-doc-claims.sh tests/validate-skills.sh lib/harness/claude.sh tests/test-validate-skills.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "test: read the retired-key register by running it"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 4c: the retired-key register lives in a file both bin/keel and the checks source

Added by the coordinator on 2026-10-30 from task 4b's quality review. Task 4b's checks extract
`retired_keys` from `bin/keel` with a `sed` range and `eval`, and when that extraction fails (a
header written `retired_keys () {`, a row starting with `}`, an unbound variable) both read an empty
register and pass in silence, which is the blindness task 4b set out to close. The extraction is
also written twice.

**Story:** G1, ADR-0013
**Files:**
- Create: `lib/retired-keys.sh`
- Modify: `bin/keel`
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-doc-claims.sh`
- Modify: `lib/harness/claude.sh` (its header comment only)
- Modify: `CONTRIBUTING.md` (its sentence on where a removed key is registered)
- Test: `tests/test-validate-skills.sh`, `tests/test-keel-4.sh`
- Plus each file whose citation into `bin/keel` this task's edits break

**Interfaces:**
- Consumes: `retired_keys` as task 4 left it in `bin/keel`
- Produces: `lib/retired-keys.sh`, defining `retired_keys` (same output: one `path|version|message`
  row per line) and nothing else, with no top-level command; `bin/keel` sources it and lists it in
  its install check (`_need`)

**Depends on:** task 4b

(Corrected by the coordinator on 2026-10-30 after the first implementer stopped without editing:
behaviour 1 said `tests/test-keel-4.sh` passes unchanged, which its fixed count of Codex notices
in `bin/keel` makes impossible, and behaviour 2's example quoted the wrong `sed` form and could not
fail.)

**Behaviours:**

1. `bin/keel` behaves as before. Example: `keel doctor` on a schema 6 profile with `harnesses` still
   warns that it is retired in schema 7. `tests/test-keel-4.sh`'s count of Codex notices moves with
   the row: `bin/keel` names Codex on exactly 2 lines and `lib/retired-keys.sh` on exactly 1, each
   ending `# names Codex: the v0.26.0 notice`. `CONTRIBUTING.md` says a removed key gets a line in
   `lib/retired-keys.sh`.
2. Both checks source `lib/retired-keys.sh` and run `retired_keys`, with no `sed` and no `eval`.
   Example: `grep -cF "sed -n '/^retired_keys" tests/validate-skills.sh tests/test-doc-claims.sh`
   prints 0 for both, and neither file evaluates text taken from `bin/keel`.
3. A register that cannot be read, or reads empty, fails loudly. Example: in a
   `tests/test-validate-skills.sh` fixture whose `lib/retired-keys.sh` is missing, or defines
   `retired_keys` to print nothing, the validator fails with a message naming
   `lib/retired-keys.sh`; `tests/test-doc-claims.sh` fails the same way if the register reads empty.
4. The test-doc-claims canary does not hard-code a key. Example: it copies the profile, sets the
   first key `retired_keys` prints (today the dotted `gates.tdd`, so the edit creates nested
   objects), and expects that key named; its temporary directory is removed by an `EXIT` trap.
5. `lib/harness/claude.sh`'s header is accurate. Example: `harness_config_paths` is described as
   printing `committed|<path>` and `local|<path>` lines, `harness_doctor_findings` names its phase
   argument, and the paragraph after the list does not call `harness_context_file` "the last".

**Done when:** `tests/test-validate-skills.sh`, `tests/test-doc-claims.sh` and `tests/test-keel-4.sh`
pass, and `tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 4c.1: Build it test first** Note: built by the second implementer after the plan correction; reds reproduced by the spec reviewer against HEAD (124/5, 61/3, 112/4)

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-validate-skills.sh`
Expected before the implementation: FAIL, the case for behaviour 3 fails because a missing or empty
register passes in silence. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 4c.2: Hand over** Note: rounds: 2 (the first stopped on a plan defect, no edits); routing: inherit; loop: full; spec COMPLIES with the full suite green on the staged tree; quality: no blocking, a partially failing register still reads as shorter (follow-up)

```bash
git add lib/retired-keys.sh bin/keel tests/validate-skills.sh tests/test-doc-claims.sh \
        lib/harness/claude.sh CONTRIBUTING.md tests/test-validate-skills.sh tests/test-keel-4.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "refactor(keel): keep the retired-key register in a file the checks source"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 5: `keel init` stops writing `AGENTS.md`

**Story:** G1, ADR-0013
**Files:**
- Modify: `bin/keel`
- Delete: `AGENTS.md`
- Test: `tests/test-keel.sh`, `tests/test-keel-4.sh`
- Plus each file whose citation into `bin/keel` this task's edits break

**Interfaces:**
- Consumes: task 4's single-harness `bin/keel`
- Produces: nothing new

**Depends on:** task 4

**Behaviours:**

1. `keel init` writes the managed block to `CLAUDE.md` only. Example: `keel init` in a fresh
   repository creates `CLAUDE.md` with the `<!-- keel:start` block, creates no `AGENTS.md`, and its
   summary line names `CLAUDE.md` alone.
2. An existing `AGENTS.md` is left exactly as it was. Example: a repository whose `AGENTS.md` holds
   an older keel block and a user paragraph has a byte-identical `AGENTS.md` after `keel init`.
3. `keel doctor` no longer checks `AGENTS.md`. Example: `keel doctor` in a repository whose
   `AGENTS.md` has a stale keel block prints no line naming `AGENTS.md`.
4. This repository's own `AGENTS.md` is removed, since `CLAUDE.md` carries the same block. Example:
   `git ls-files AGENTS.md` prints nothing.

**Done when:** `tests/test-keel.sh` and `tests/test-keel-4.sh` pass, and
`tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 5.1: Build it test first** Note: built by the implementer; red reproduced by the spec reviewer against HEAD (303 passed, 6 failed)

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-keel.sh` and `tests/test-keel-4.sh`
Expected before the implementation: FAIL, the case for behaviour 1 fails because init creates
`AGENTS.md`. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 5.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; the plan's 'git add AGENTS.md' fails after git rm, the deletion was staged with git rm; doctor's link scan of AGENTS.md moved to task 5b

```bash
git add bin/keel AGENTS.md tests/test-keel.sh tests/test-keel-4.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "feat(init): write CLAUDE.md only, and leave AGENTS.md to other harnesses"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 5b: `keel doctor` reads no `AGENTS.md` at all

Added by the coordinator on 2026-10-30 from task 5's review. Bernard decided on 2026-10-29 that
`keel doctor` stops checking `AGENTS.md`; task 5 removed the marker check but kept `AGENTS.md` in
the referenced-docs scan, so a link in it to an uncommitted document still gets a doctor line.

**Story:** G1, ADR-0013
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel.sh`, `tests/test-keel-2.sh`
- Plus each file whose citation into `bin/keel` this task's edits break

**Interfaces:**
- Consumes: task 5's `bin/keel`
- Produces: nothing new

**Depends on:** task 5

**Behaviours:**

1. Doctor's referenced-docs scan reads `CLAUDE.md`, `README.md` and the docs folder as before, and not
   `AGENTS.md`. Example: a repository whose `AGENTS.md` links `docs/missing.md` (an uncommitted file)
   gets no doctor line naming `AGENTS.md`; the same link in `CLAUDE.md` still gets its line.
2. `keel new` writes no `AGENTS.md`. Example: after `keel new` in an empty directory, `AGENTS.md` does
   not exist and `CLAUDE.md` carries the `<!-- keel:start` block.
3. The comment in `tests/test-keel-2.sh` that calls `AGENTS.md` one of "the two keel writes into
   itself" says what is true now. Example: it names `CLAUDE.md` as the one file keel writes the block
   into.

**Done when:** `tests/test-keel.sh` and `tests/test-keel-2.sh` pass, and `tests/validate-citations.sh`
and `tests/validate-skills.sh` report OK.

- [x] **Step 5b.1: Build it test first** Note: built by the implementer; red reproduced by the spec reviewer against HEAD (310 passed, 1 failed); behaviour 2 held on arrival and was proven able to fail

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-keel.sh`
Expected before the implementation: FAIL, the case for behaviour 1 fails because doctor prints a
line beginning `AGENTS.md links`. Behaviour 2's case passes on arrival, since task 5 already
removed the writer; say so in the report and prove it able to fail by putting the writer back.
Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 5b.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES

```bash
git add bin/keel tests/test-keel.sh tests/test-keel-2.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "fix(doctor): read no AGENTS.md at all"`. Paste the `git status --porcelain`
output into your report; if it lists anything this task did not touch, say so and leave it
unstaged.

### Task 6: the ledger, its generator and its claims hold Claude Code rows only

**Story:** G1, G2, ADR-0013, ADR-0014
**Files:**
- Modify: `lib/harness/capabilities`
- Modify: `tests/generate-harness-artifacts.sh`
- Modify: `docs/harness-support.md` (regenerated)
- Delete: `hooks/hooks.codex.json`
- Delete: `.codex-plugin/plugin.json`
- Delete: `lib/harness/codex.sh`, which nothing sources after task 4
- Delete: `tests/fixtures/transcripts/codex.jsonl`
- Modify: `tests/supply-chain-scan.sh`
- Modify: `docs/05-token-and-memory-design.md`, `docs/07-open-decisions.md` (their
  `harness=codex` claim markers only)
- Modify: `docs/06-repo-layout.md` (the link to `.codex-plugin/` only)
- Modify: `lib/harness/claude.sh` (the comment near `harness_context_file` only)
- Test: `tests/test-harness-resolve.sh`, `tests/test-harness-claims.sh`, `tests/test-supply-chain.sh`
- Plus each file whose citation into a deleted or changed file breaks. The review found these for
  `lib/harness/codex.sh`: `tests/validate-skills.sh:348`, `tests/test-validate-skills.sh:178`,
  `docs/ideas/harness-held-dispatch-guarantees.md:94`,
  `docs/ideas/independence-of-a-delegated-review.md:109`,
  `docs/ideas/declared-profile-keys-take-effect.md:88` and
  `docs/plans/2026-09-07-declared-profile-keys-take-effect.md:135`

**Interfaces:**
- Consumes: tasks 2 to 4, after which nothing outside `lib/harness/` and the tests names `codex` as
  a harness
- Produces: a ledger with `provides|claude|...` and `requires|...` rows only

**Depends on:** tasks 2, 2b, 2c, 3, 4, 4b, 4c and 5b

**Behaviours:**

1. The ledger has no Codex rows and no Codex commentary. Example: `grep -ic codex
   lib/harness/capabilities` prints 0, and `harness_active_gates claude` lists the same five gates as
   before the task.
2. The generator produces Claude Code artifacts only. Example: `tests/generate-harness-artifacts.sh
   codex` exits non-zero with its usage message, `tests/generate-harness-artifacts.sh claude`
   produces a `hooks/hooks.json` identical to the committed one, and `hooks/hooks.codex.json`,
   `.codex-plugin/` and `lib/harness/codex.sh` do not exist.
3. `docs/harness-support.md` is regenerated with one harness column. Example: its gates table has
   the columns `Gate` and `claude`, its provenance table has no `codex` row, and the "What Tier B
   cannot claim" section is gone; regenerating produces no diff.
4. No current document carries a `harness=codex` claim marker. Example: `grep -rln 'harness=codex'
   --include=*.md README.md docs/0*.md docs/harness-support.md docs/profile-keys.md` prints nothing,
   and `tests/test-harness-claims.sh` passes.
5. The resolver's evidence rule still holds for Claude Code rows. Example: in
   `tests/test-harness-resolve.sh` a `provides|claude` fixture row with a blank version makes
   `harness_gate_active claude <its gate>` return non-zero, as before; the Codex fixtures and
   expectations are removed.
6. The delegation profile check resolves on Claude Code alone. Example: `tests/test-harness-claims.sh`
   reports "delegation profile keel-fanout resolves on claude" and no "on codex" case.
7. Item 9 of `tests/test-harness-claims.sh`, which requires `skills/security-audit/SKILL.md` to say
   "Claude Code" and exists only for ADR-0004, is deleted. The fresh-clone checks it sits beside
   (`if [ -f "$M" ]`, around lines 319 to 379) are kept by moving them out of that condition, since
   `$M` is the deleted manifest. Example: after the task, the fresh-clone cases still print PASS.
8. The supply chain scan no longer special-cases `hooks.codex.json`. Example: `grep -c codex
   tests/supply-chain-scan.sh tests/test-supply-chain.sh` prints 0 for both, and
   `tests/test-supply-chain.sh` passes.
9. Every citation into a deleted file reads as the backticked path without a line, followed by
   "(deleted after v0.26.0)". Example: `tests/validate-citations.sh` reports OK.
10. `lib/harness/claude.sh`'s comment near `harness_context_file` no longer says keel writes
    `AGENTS.md` for every repository. Example: `grep -n AGENTS.md lib/harness/claude.sh` prints no
    line claiming keel writes it. (Added by the coordinator on 2026-10-30 from task 5's report.)

**Done when:** `tests/test-harness-resolve.sh`, `tests/test-harness-claims.sh` and
`tests/test-supply-chain.sh` pass, and `tests/validate-citations.sh` and `tests/validate-skills.sh`
report OK.

- [x] **Step 6.1: Build it test first** Note: built by the implementer; reds reproduced by the spec reviewer against HEAD (58/6, 22/5)

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-harness-claims.sh` and `tests/test-harness-resolve.sh`
Expected before the implementation: FAIL, the cases for behaviours 1 and 2 fail because the ledger
still has Codex rows and the generator still accepts `codex`. Expected after: PASS. Quote the
failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 6.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking, four should-fix routed to tasks 7, 8 and 10

```bash
git add lib/harness/capabilities tests/generate-harness-artifacts.sh docs/harness-support.md \
        hooks/hooks.codex.json .codex-plugin/plugin.json lib/harness/codex.sh \
        tests/fixtures/transcripts/codex.jsonl tests/supply-chain-scan.sh \
        docs/05-token-and-memory-design.md docs/07-open-decisions.md docs/06-repo-layout.md \
        lib/harness/claude.sh tests/test-harness-resolve.sh tests/test-harness-claims.sh \
        tests/test-supply-chain.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "refactor(harness): hold Claude Code rows only in the capability ledger"`. Paste
the `git status --porcelain` output into your report; if it lists anything this task did not touch,
say so and leave it unstaged.

### Task 7: keel states and checks its minimum Claude Code version

**Story:** G2, ADR-0014
**Files:**
- Modify: `lib/harness/resolve.sh`
- Modify: `tests/generate-harness-artifacts.sh`
- Modify: `docs/harness-support.md` (regenerated)
- Modify: `bin/keel`
- Modify: `README.md` (the minimum version line only)
- Modify: `tests/keel-test-lib.sh`
- Modify: `lib/harness/capabilities` (its header comments only)
- Test: `tests/test-harness-resolve.sh`, `tests/test-harness-claims.sh`, `tests/test-keel-4.sh`
- Plus each file whose citation into `bin/keel` or `lib/harness/resolve.sh` this task's edits break,
  and each test file that runs doctor without `tests/keel-test-lib.sh`

**Interfaces:**
- Consumes: task 6's Claude-only ledger
- Produces, all in `lib/harness/resolve.sh`, pure bash with no python3 and no external command:
  - `harness_version_ge A B`: returns 0 when version `A` is at or above `B`, comparing each dotted
    field as a number, else 1.
  - `harness_gate_version GATE`: prints the highest version among the evidenced `provides|claude`
    rows for the primitives `GATE` requires; prints nothing and returns 1 if none.
  - `harness_min_version`: prints the highest `harness_gate_version` over every gate in a
    `requires` row; prints nothing and returns 1 if none.
- Produces in `bin/keel`: `KEEL_CLAUDE`, the command doctor runs as `"$KEEL_CLAUDE" --version`,
  defaulting to `claude`, following the `KEEL_CAPABILITIES` override pattern
  (`lib/harness/resolve.sh:47-56`).
- Produces in README: the value between `<!-- keel:min-claude-code -->` and
  `<!-- /keel:min-claude-code -->` on one line.

**Depends on:** task 6

**Behaviours:**

1. The minimum is derived from the ledger. Example: with today's rows, `harness_min_version` prints
   `2.1.302`, because `pretooluse_agent_type` is the highest required primitive (`validated_word_ceiling`
   has no `requires` row). In a fixture whose highest required row is `2.1.296`, it prints `2.1.296`;
   adding a `provides|claude` row at `2.1.310` for a primitive no `requires` row names leaves it at
   `2.1.296`; a required row with a blank version is ignored, so the fixture prints the next highest.
2. Versions compare numerically. Example: `harness_version_ge 2.1.302 2.1.99` returns 0,
   `harness_version_ge 2.1.99 2.1.302` returns 1, `harness_version_ge 2.1.302 2.1.302` returns 0.
3. The support page states the minimum. Example: the regenerated `docs/harness-support.md`
   contains the line "Minimum Claude Code version: 2.1.302, the highest version a gate's primitive
   was verified on."
4. README and the ledger agree, and the claims test fails when they do not. Example: README
   contains `<!-- keel:min-claude-code -->2.1.302<!-- /keel:min-claude-code -->`; changing it to
   `2.1.300` makes `tests/test-harness-claims.sh` fail with a message naming both values.
5. Doctor compares the installed Claude Code with the minimum, through `KEEL_CLAUDE`. Examples, with
   `KEEL_CLAUDE` set to a stub script:
   - the stub prints `2.1.312 (Claude Code)`: doctor prints a `good` line naming 2.1.312 and 2.1.302;
   - the stub prints `2.1.280 (Claude Code)`: doctor prints a `warn` line naming 2.1.280, 2.1.302,
     and each gate whose `harness_gate_version` is above 2.1.280;
   - `KEEL_CLAUDE` names a command that does not exist, or the stub prints `garbage`: doctor prints a
     `warn` that it cannot tell whether this Claude Code runs keel's gates, and no `good` line;
   - the stub sleeps 10 seconds: doctor kills it after 5 seconds, using a background process and a
     polling loop since neither `timeout` nor `gtimeout` can be assumed, and prints the same "cannot
     tell" warning; the doctor run finishes in under 7 seconds.
6. The version is parsed without python3, since `tests/test-keel.sh:887` caps doctor's python3
   starts. Example: that test passes with its cap unchanged.
7. The suite's doctor runs do not depend on the machine's Claude Code. Example: `tests/keel-test-lib.sh`
   exports `KEEL_CLAUDE` pointing at a stub that prints the current minimum, so the roughly 140
   doctor runs across the test files print the same line on a machine with `claude` and on CI
   without it, and the baseline diff at `tests/test-keel-4.sh` (around 983 to 994) and the warning
   count in `tests/test-keel-2.sh` are unchanged. Test files that run doctor without the library set
   the same variable.
8. The claim registry is proved to check the harness, not only the name. Example: a fixture in
   `tests/test-harness-claims.sh` tagging a known gate under an unknown harness,
   `<!-- keel:claim gate=session-start harness=ghost -->`, is reported as `ghost/session-start`; the
   fixture file named `ceiling.md` is renamed for what it now tests. (From task 6's quality review:
   its fixtures used only names the ledger never had, which fail whatever the harness.)
9. Comments state one harness. Example: `lib/harness/capabilities`' header no longer says "What each
   harness provides" or "on every harness lacking", and `tests/test-harness-resolve.sh`'s wire-format
   comment and its "every harness" / "some harness" wording use the ledger header's words; the "no
   Codex artifact remains" loop moves out of the `if [ -x "$GEN" ]` block it does not belong to.
   (From task 6's quality review.)

**Done when:** `tests/test-harness-resolve.sh`, `tests/test-harness-claims.sh` and
`tests/test-keel-4.sh` pass, and `tests/validate-citations.sh` and `tests/validate-skills.sh` report
OK.

- [x] **Step 7.1: Build it test first** Note: built by the implementer; reds reproduced by the spec reviewer against HEAD (68/9, claims 2, keel-4 7)

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-harness-resolve.sh`
Expected before the implementation: FAIL, the cases for behaviours 1 and 2 fail because
`harness_min_version` and `harness_version_ge` do not exist. Expected after: PASS. Quote the failing
output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 7.2: Hand over** Note: rounds: 1; routing: inherit; loop: full; spec COMPLIES; quality: no blocking as ranked, but a TERM-ignoring claude hangs doctor and an empty minimum reads as a pass; both fixed in task 7b

```bash
git add lib/harness/resolve.sh tests/generate-harness-artifacts.sh docs/harness-support.md bin/keel \
        README.md tests/keel-test-lib.sh lib/harness/capabilities tests/test-harness-resolve.sh \
        tests/test-harness-claims.sh tests/test-keel-4.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired or that now sets
`KEEL_CLAUDE`, by name, and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -s -m "feat(doctor): derive and check keel's minimum Claude Code version"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 7b: the version check never hangs and never passes on nothing

Added by the coordinator on 2026-10-30 from task 7's quality review: a `claude` that ignores SIGTERM
makes doctor wait without limit, which breaks task 7's "gives up within 5 seconds"; an unreadable
ledger makes the minimum empty and doctor print "meets keel's minimum, " with nothing after it.

**Story:** G2, ADR-0014
**Files:**
- Modify: `bin/keel`
- Test: `tests/test-keel-4.sh`, `tests/test-harness-resolve.sh`
- Plus each file whose citation into `bin/keel` this task's edits break

**Interfaces:**
- Consumes: task 7's doctor block, `harness_min_version` and `harness_gate_version`
- Produces: nothing new

**Depends on:** task 7

**Behaviours:**

1. A `claude` that ignores SIGTERM is still stopped. Example: a stub that runs `trap '' TERM; exec
   sleep 60` makes doctor print the timed-out warning and return within 30 seconds; no stub process
   is left running afterwards.
2. The hang test does not depend on doctor's own speed. Example: the existing "killed after 5
   seconds" case uses a stub sleeping 60 seconds and asserts doctor ends within 30, so it passes on
   a loaded machine.
3. The warning names its cause. Examples: `KEEL_CLAUDE` naming a missing command says it was not
   found; a stub that sleeps past the limit says it was stopped after 5 seconds; a stub printing
   `garbage` says its output named no version. None prints a `good` line.
4. Common version spellings parse. Examples: `v2.1.312`, `2.1.303-beta.1 (Claude Code)` and a
   version on the second line after a warning line each give the `good` line naming 2.1.312, 2.1.303
   or the version printed.
5. An empty minimum never reads as a pass. Example: with `KEEL_CAPABILITIES` pointing at an empty
   file, doctor prints a warning that it cannot read keel's minimum and no `good` line about Claude
   Code.
6. A malformed ledger version is caught by the ledger test, not by doctor's arithmetic. Example: a
   case in `tests/test-harness-resolve.sh` asserts every `provides` row's version matches
   `^[0-9]+(\.[0-9]+)+$`, and a fixture with `2.1.x` fails it.

**Done when:** `tests/test-keel-4.sh` and `tests/test-harness-resolve.sh` pass, and
`tests/validate-citations.sh` and `tests/validate-skills.sh` report OK.

- [x] **Step 7b.1: Build it test first** Note: built by the implementer; reds reproduced by the spec reviewer against HEAD (119 passed, 9 failed); first post-staging suite run failed the 30-second bound at load average about 43, rerun green

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-keel-4.sh`
Expected before the implementation: FAIL, the case for behaviour 1 fails because doctor waits on
the stub past 30 seconds, and the case for behaviour 5 fails because doctor prints the `good` line.
Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 7b.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; the wall-clock hang tests flake under load and cannot tell a kill from a stub that finished, task 7c replaces them

```bash
git add bin/keel tests/test-keel-4.sh tests/test-harness-resolve.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "fix(doctor): the version check never hangs and never passes on nothing"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 7c: the version check's hang tests prove the kill without timing it

Added by the coordinator on 2026-10-30 from task 7b's review. Task 7b's hang cases assert doctor ends
within 30 seconds; a loaded machine took 109 seconds once, and the reviewer showed that neither a
time bound nor "the warning printed and no stub is left" can tell a kill from a stub that finished
its own sleep: against the old TERM-then-wait code both passed after 62 seconds.

**Story:** G2, ADR-0014
**Files:**
- Test: `tests/test-keel-4.sh`

**Interfaces:**
- Consumes: task 7b's doctor block
- Produces: nothing new

**Depends on:** task 7b

**Behaviours:**

1. The hang cases prove the kill with a marker, not a clock. Example: the stub is a shell, not
   replaced by `exec`, that ignores TERM for behaviour 1's case, starts `sleep 60` in the background,
   waits for it, and only then writes an `ended` file. Each case asserts the "stopped after 5 seconds"
   warning, that `ended` does not exist, and that the stub's shell pid is gone; no case asserts a
   wall-clock bound. The orphaned `sleep` is killed by the test's cleanup.
2. The marker cases fail against task 7's code. Example: with `bin/keel`'s `kill -KILL` put back to
   a plain `kill` followed by `wait`, the behaviour 1 case fails because `ended` exists.
3. The pid check reads only this case's stub. Example: the pid file is emptied before each case, so
   a reaped pid from the case before cannot be checked again.
4. The test's cleanup chains to the library's `EXIT` trap rather than copying it, and removes every
   directory the version cases create.
5. The spelling cases check parsing, not today's minimum. Example: `v2.1.312`,
   `2.1.303-beta.1 (Claude Code)` and the second-line version each appear as the parsed version in
   either the `ok` line or the "older than" line, so a ledger row at 2.1.304 does not turn them red.

**Done when:** `tests/test-keel-4.sh` passes.

- [x] **Step 7c.1: Build it test first** Note: built by the implementer; red on a scratch copy with plain kill (124 passed, 1 failed) reproduced by the spec reviewer

Follow `keel:tdd`. For behaviours 1 and 2, write the marker cases, run them against a scratch copy of
`bin/keel` with the plain `kill` and `wait` put back, and watch them fail because `ended` exists;
then run them against the real `bin/keel` and watch them pass. Quote both runs. Behaviours 3 to 5
are test changes; show each still passes and, for 5, that it passes with a scratch ledger whose
highest required row is 2.1.304.
Run: `tests/test-keel-4.sh`
Expected before (on the scratch copy): FAIL, `ended` exists. Expected after: PASS.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 7c.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES

```bash
git add tests/test-keel-4.sh
git status --porcelain
```

Stage that path and stop. **Do not commit.** The coordinator commits after the review pass, with
`git commit -s -m "test(doctor): prove the version check's kill with a marker, not a clock"`. Paste
the `git status --porcelain` output into your report; if it lists anything this task did not touch,
say so and leave it unstaged.

### Task 8: skills and agents stop hedging for another harness

**Story:** G1, ADR-0013
**Files:**
- Modify: `skills/create-skill/SKILL.md`
- Modify: `skills/security-audit/SKILL.md`
- Modify: `skills/review-code/references/rubric-pass.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/keel/references/asking-questions.md`
- Modify: `skills/context-budget/SKILL.md` (its `AGENTS.md` line only)
- Modify: `agents/keel-reviewer.md`
- Modify: `tests/validate-skills.sh`
- Test: `tests/test-validate-skills.sh`

**Interfaces:**
- Consumes: task 6, which deletes the check that needed "Claude Code" in `security-audit`
- Produces: a rule in `tests/validate-skills.sh` that fails when a file under `skills/` or `agents/`
  names Codex

**Depends on:** task 6

**Behaviours:**

1. No skill or agent names Codex, and the validator holds that. Example: `tests/validate-skills.sh`
   gains a rule that lists any line under `skills/` or `agents/` matching `codex` case-insensitively
   and fails; a case in `tests/test-validate-skills.sh` shows it firing on a fixture skill containing
   "on Codex" and passing on one without.
2. The hedges for a harness without the plugin's features become plain statements for Claude Code,
   keeping the fallback for a session without the plugin where one is described. Example:
   `rubric-pass.md`'s "Where the agent type does not exist, on Codex or in a session without the
   plugin" reads "Where the agent type does not exist, in a session without the plugin"; the
   `security-audit` sentences "**Claude Code only.**" and "Neither has a Codex counterpart, so on
   that harness nothing watches between runs" are removed.
3. `plan-template.md`'s "Where the harness has a plan mode" names Claude Code's plan mode directly,
   and the sentence about a harness with no plan mode keeps only the headless or scheduled case.
   Example: the paragraph contains "plan mode" and does not contain "harness with no plan mode".
4. The model-pin rule in `tests/validate-skills.sh` (around lines 322 to 348) keeps its check and
   gets a reason that does not rest on Codex. Example: its comment says a dispatch names its model or
   a delegation profile because `docs/ideas/model-routing.md` measured which model the reading should
   run on, and the comment no longer cites `lib/harness/codex.sh`. The same goes for the comment
   around line 326 ("written for Codex at .codex/agents/keel-fanout.toml") and for
   `tests/test-validate-skills.sh` around line 178: each states today's reason, that `agents/*.md`
   is where Claude Code turns a delegation profile into a model, and none says what a deleted file
   relied on. (Widened by the coordinator on 2026-10-30 from task 6's quality review.)
5. `skills/context-budget/SKILL.md` no longer says keel writes `AGENTS.md`. Example: its line 23
   area names `CLAUDE.md` as the file the keel block lives in. (From task 5's report.)
6. The skills still validate under their budgets. Example: `tests/validate-skills.sh` reports
   "25 skills validated" and no FAIL, and every changed `SKILL.md` stays under the 700 word ceiling.

**Done when:** `tests/test-validate-skills.sh` passes, and `tests/validate-skills.sh` and
`tests/validate-citations.sh` report OK.

- [x] **Step 8.1: Build it test first** Note: built by the implementer; reds reproduced by the spec reviewer against HEAD (130 passed, 3 failed; five Codex lines, exit 1)

Follow `keel:tdd`. Write behaviour 1's rule and its case first, run it, and watch the rule fail on
the current files, listing the Codex lines in `create-skill/SKILL.md`, `security-audit/SKILL.md` and
the three references; then make the wording changes and watch it pass.
Run: `tests/test-validate-skills.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the new rule lists the Codex lines. Expected after: PASS.
Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 8.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; four wording points moved to task 10

```bash
git add skills/create-skill/SKILL.md skills/security-audit/SKILL.md \
        skills/review-code/references/rubric-pass.md skills/execute-plan/references/subagent-prompts.md \
        skills/write-plan/references/plan-review.md skills/write-plan/references/plan-template.md \
        skills/keel/references/asking-questions.md skills/context-budget/SKILL.md \
        agents/keel-reviewer.md tests/validate-skills.sh \
        tests/test-validate-skills.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "docs(skills): stop hedging for another harness"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.

### Task 9: the eval tooling stages Claude Code only

**Story:** G1, ADR-0013
**Files:**
- Modify: `tests/evals/stage.sh`
- Modify: `tests/evals/README.md`
- Modify: `tests/evals/gate-scenarios` (its comment only)
- Test: `tests/test-eval-harness.sh`
- Plus each file whose citation into `tests/evals/stage.sh` this task's edits break

**Interfaces:**
- Consumes: nothing
- Produces: nothing

**Depends on:** none

**Behaviours:**

1. `stage.sh` has no `--harness` option. Example: `tests/evals/stage.sh --harness codex <scenario>`
   exits non-zero and prints its existing "unknown flag" message (`tests/evals/stage.sh:54`), and a
   run without the option stages the Claude Code recipe exactly as before.
2. The eval README and scenario list describe Claude Code only. Example: `grep -ic codex
   tests/evals/README.md tests/evals/stage.sh tests/evals/gate-scenarios` prints 0 for each.
   `tests/evals/results.md` is history and is not edited.
3. The Codex recipe cases leave `tests/test-eval-harness.sh`. Example: `grep -ic codex
   tests/test-eval-harness.sh` prints 0, and the file's other cases pass unchanged.

**Done when:** `tests/test-eval-harness.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

- [x] **Step 9.1: Build it test first** Note: built by the implementer; red reproduced by the spec reviewer against HEAD (113 passed, 2 failed)

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-eval-harness.sh`
Expected before the implementation: FAIL, the case for behaviour 1 fails because `stage.sh` accepts
`--harness codex`. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 9.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES

```bash
git add tests/evals/stage.sh tests/evals/README.md tests/evals/gate-scenarios tests/test-eval-harness.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "test(evals): stage Claude Code only"`. Paste the `git status --porcelain` output
into your report; if it lists anything this task did not touch, say so and leave it unstaged.

### Task 10: the documents state Claude Code only, and the changelog names the last Codex release

**Story:** G3, G4, ADR-0013
**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md` (the Unreleased section only)
- Modify: `docs/01-architecture.md`, `docs/02-skill-catalog.md`, `docs/03-install-and-distribution.md`,
  `docs/04-plugin-strategy.md`, `docs/05-token-and-memory-design.md`, `docs/06-repo-layout.md`,
  `docs/07-open-decisions.md`
- Modify: `docs/snapshot.md`, `docs/standards.md`, `docs/runbooks/cutting-a-release.md`
- Modify: `docs/ideas/keel-on-codex.md`, `docs/stories/tiered-multi-harness-support.md` (a
  superseded status line at the top of each, nothing else)
- Modify: `docs/ideas/claude-code-features-assessed-2026-10-29.md` (its Next row and its case
  against, per behaviour 6)
- Modify: `docs/architecture/claude-code-only.md` (section 7's Codex rows, per behaviour 8)
- Test: `tests/test-doc-claims.sh`

**Interfaces:**
- Consumes: tasks 1 to 9; task 1's verdict and install lines
- Produces: nothing

**Depends on:** tasks 1 to 9

**Behaviours:**

1. No current document names Codex as supported. Example: `grep -rni codex README.md docs/0*.md
   docs/snapshot.md docs/standards.md docs/runbooks templates` prints only lines that state Codex
   support ended at v0.26.0, and each of those lines contains `v0.26.0`.
2. README says how a Codex user continues. Example: README contains a sentence that v0.26.0 is the
   last release with Codex support, task 1's install line verbatim, and that a separate keel Codex
   plugin is planned.
3. The release runbook no longer bumps a Codex manifest. Example: `grep -c codex-plugin
   docs/runbooks/cutting-a-release.md` prints 0.
4. The changelog's Unreleased section records the removal. Example: it has entries for the removal
   of Codex support naming v0.26.0, `keel init` no longer writing `AGENTS.md`, `profile.harnesses`
   retired in schema 7, `--harness` refused, the minimum Claude Code version check, and
   `sensitive-guard`'s change as task 2 made it.
5. The superseded records say so at the top. Example: the first lines of `docs/ideas/keel-on-codex.md`
   and `docs/stories/tiered-multi-harness-support.md` carry "Superseded on 2026-10-29 by ADR-0013";
   nothing else in them changes.
6. The idea record no longer waits on this decision. Example: its Next row names `write-plan` for
   items 1 to 4 and 9; its "Strongest argument" paragraph no longer rests on ADR-0004's two strengths
   of guarantee; item 8's verdict notes its ADR-0005 reason is gone and the item is reopened; and the
   minimum it names is 2.1.302, per task 7.
7. The README claims still check. Example: `tests/test-doc-claims.sh` passes.
8. The design's failure table matches task 1's probe. Example: the row for a Codex user installing
   from `main` no longer says "nothing loads"; it says Codex loads the Claude Code hook set from
   `hooks/hooks.json` and that `sensitive-guard` refuses a sensitive commit there, as tasks 2 and 2b
   left it. No line of the design says `sensitive-guard` loses its Codex arm or exit 2 block, or that
   its only decisions are `ask` and silence; task 2b's quality review found four (today around lines
   100, 186, 259 and 306). (Added by the coordinator on 2026-10-30 from the reports of tasks 1 and 2.)
9. `docs/snapshot.md`'s citation of `hooks/done-guard:114, 364-367` (today line 173) points at the
   block it describes, `251-254` after task 3. (Added by the coordinator on 2026-10-30 from task 3's
   quality review: `tests/validate-citations.sh` does not check the second number of that form.)
10. The design's probe record no longer says `sensitive-guard` "refuses on either" without the
    condition task 2c added: it refuses only when `CLAUDE_PROJECT_DIR` is empty. The changelog's
    Unreleased entry no longer says the hook unsets `CDPATH`, which task 2b removed. (Added by the
    coordinator on 2026-10-30 from task 2c's reviews.)
11. Two lines a Codex grep cannot find no longer describe the harness set:
    `docs/03-install-and-distribution.md`'s list of `keel-fleet` columns (today around line 1039)
    and `docs/07-open-decisions.md`'s "names the harness it is running under" (around line 196).
    The changelog notes that `keel doctor` reports one fewer warning outside Claude Code, since
    "cannot determine which harness is running" is gone. (From task 4's quality review.)
12. Citations that the line removals of this plan moved onto other content are repaired. Method:
    for each `path:line` citation into `bin/keel`, `lib/`, `hooks/` or `tests/validate-skills.sh`,
    in any document, read the cited lines at `main` and now; where they differ, find the cited
    content now and repoint. Example: `docs/prd/profile-sync.md`'s `bin/keel:941-950`, which held
    `profile_set` at `main`, points at `profile_set` again. A citation already wrong at `main` is
    left alone and listed in the report. (From task 4's quality review: `tests/validate-citations.sh`
    checks only that a cited line exists and is not blank.)
13. `docs/06-repo-layout.md`'s `lib/` tree names `lib/retired-keys.sh` (task 4c), and
    `docs/ideas/stack-plugins-on-existing-repos.md`'s "written at init, `bin/keel:444`" points at
    the `plugins.recommended` write. (From task 4c's quality review.)
14. No current document or template says keel writes `AGENTS.md`: `README.md` (around line 22),
    `docs/02-skill-catalog.md` (around 565), `docs/03-install-and-distribution.md` (around 1140 and
    1148), `docs/snapshot.md` (around 38), `docs/06-repo-layout.md`'s "Five files" sentence,
    `templates/project-claude-md-block.md` (line 3) and the comment in `lib/merge-claude-md.sh`
    (line 2). (From task 5's report.)
15. `templates/profile.schema.json` no longer says a key "applies on both harnesses" (around line
    308), and `docs/profile-keys.md` is regenerated; if `schema_fingerprint_for` moves with a
    description edit, it is updated in the same commit. `docs/ideas/concise-responses.md`'s citation of
    `docs/05-token-and-memory-design.md:278` for "634 against 450" points at the figure or loses its
    line number. (From task 6's quality review.)
16. Four wording points from task 8's review read true: `agents/keel-reviewer.md`'s "Where the hook
    is absent, in a session without the plugin" drops the narrowing clause, since the hook can be
    absent for other reasons; `tests/validate-skills.sh`'s "Of the five aliases Claude Code accepts, a
    skill may name one" says a skill may name only `inherit`; `skills/security-audit/SKILL.md`'s "Say
    which ran" fits a plugin that watches edits as well as a command that runs; and
    `skills/context-budget/SKILL.md`'s managed-block row says it is part of the `CLAUDE.md` row and
    is not added to the total. Each changed skill body stays under 700 words.
17. `tests/test-eval-harness.sh`'s 41c comment reads "The recipe closes the arm's stdin and says",
    not "say". (From task 9's review.)

**Done when:** `tests/test-doc-claims.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

**Review, 2026-10-30.** The first spec review returned DEVIATES on four points. Bernard chose a
targeted fix pass on the staged work instead of discarding it, and accepted by name the 13
citations the sweep repointed although they were already wrong at `main` (they were judged against
`d6c421a`), since each now lands on the content its sentence names. The fix pass names 2.1.302 in
the idea record, reverts the four `bin/keel:626` repoints (ADR-0004 and the 2026-09-05 design), and
restates the sweep's counts. The 13 accepted rows: `docs/07-open-decisions.md:578` and `:608`;
`docs/ideas/declared-profile-keys-take-effect.md:92`; `docs/ideas/leon-van-zyl-skill-collection.md:144`;
`docs/ideas/snapshot-records-its-own-path.md:85`; `docs/plans/2026-08-30-profile-sync.md:47`;
`docs/plans/2026-09-05-tiered-multi-harness-support.md:2140`;
`docs/plans/2026-09-07-declared-profile-keys-take-effect.md:50`, `:786` and `:2247`;
`docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:1888`; `docs/prd/profile-sync.md:112`;
`docs/stories/profile-sync.md:78`. A 14th, `docs/stories/profile-sync.md:76`, which the sweep moved
onto the same wrong lines, Bernard accepted on 2026-10-30 to be pointed at `profile_set` and its
unknown-path refusal.

- [x] **Step 10.1: Build it test first** Note: built by the implementer and two targeted fix passes Bernard chose over a discard; behaviour 1 grep 63 lines before, 9 after (each naming v0.26.0)

Follow `keel:tdd`. Behaviour 1's grep is the failing test: run it before the edits, watch it list
the current Codex sentences, then edit until it prints only lines containing `v0.26.0`.
Run: the grep in behaviour 1, then `tests/test-doc-claims.sh`
Expected before the implementation: the grep lists Codex lines in README, `docs/01` to `docs/07`,
`docs/snapshot.md`, `docs/standards.md` and the runbook. Expected after: every line it prints
contains `v0.26.0`, and `tests/test-doc-claims.sh` passes. Quote the first grep output in your
report.

Run: `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
A red in either validator is this task's. This is the one boundary run the task schedules.

- [x] **Step 10.2: Hand over** Note: rounds: 4 (one implementer, three fix passes); routing: inherit; loop: full; spec DEVIATES then COMPLIES on re-review with 14 accepted citation repoints; quality blocking (docs/01) fixed and re-reviewed

```bash
git add README.md CHANGELOG.md docs/01-architecture.md docs/02-skill-catalog.md \
        docs/03-install-and-distribution.md docs/04-plugin-strategy.md \
        docs/05-token-and-memory-design.md docs/06-repo-layout.md docs/07-open-decisions.md \
        docs/snapshot.md docs/standards.md docs/runbooks/cutting-a-release.md \
        docs/ideas/keel-on-codex.md docs/stories/tiered-multi-harness-support.md \
        docs/ideas/claude-code-features-assessed-2026-10-29.md docs/architecture/claude-code-only.md \
        templates/project-claude-md-block.md lib/merge-claude-md.sh templates/profile.schema.json \
        docs/profile-keys.md docs/ideas/concise-responses.md tests/validate-skills.sh \
        agents/keel-reviewer.md skills/security-audit/SKILL.md skills/context-budget/SKILL.md \
        tests/test-eval-harness.sh
git status --porcelain
```

Stage those paths, and each file whose broken citation this task repaired, by name, and stop.
**Do not commit.** The coordinator commits after both review passes, with
`git commit -s -m "docs: state Claude Code only, and name v0.26.0 as the last Codex release"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 11: close what the branch-wide reviews found

Added by the coordinator on 2026-10-30 from the branch's security audit, its `/code-review` pass and
its rubric pass. The audit's finding is on a `hard_block_paths` path, so it blocks shipping
whatever the gate says; the rubric pass's two surviving mutants are Blocking by its rules.

**Story:** G1, G2, ADR-0013, ADR-0014
**Files:**
- Modify: `hooks/sensitive-guard`
- Modify: `lib/harness/resolve.sh` (only if behaviour 3 needs it)
- Create: `docs/decisions/ADR-0015-sensitive-guard-keeps-a-codex-refusal.md`
- Modify: `docs/decisions/ADR-0013-claude-code-is-the-only-harness.md` (its status row only)
- Test: `tests/test-sensitive-guard.sh`, `tests/test-harness-resolve.sh`, `tests/test-keel-fleet.sh`
- Plus the six documents citing `bin/keel:648-649` (behaviour 5)

**Interfaces:**
- Consumes: everything tasks 1 to 10 left
- Produces: nothing new

**Depends on:** task 10

**Behaviours:**

1. A nested empty list does not turn the guard off (audit M-01). Example: a profile whose top-level
   `hard_block_paths` lists `auth` and which also holds `"_notes":{"hard_block_paths":[]}`, with
   `auth/x` staged, makes `git commit -m x` print the `ask` decision; a profile whose top-level list
   is `[]` still gets no output and exit 0.
2. A commit that stages `.keel/profile.json` asks. Example: in a repository whose profile lists `auth`,
   staging a change to `.keel/profile.json` alone and running `git commit -m x` prints the `ask`
   decision naming the profile, since that commit can change the list that judges it.
3. Version comparison is tested where it can break (rubric mutant 1). Example: `harness_version_ge
   2.1.10 2.1.09` returns 0 and `harness_version_ge 2.1.08 2.1.7` returns 0; removing `10#` from
   `resolve.sh` makes these cases fail.
4. A seven-field row is not evidence for the minimum (rubric mutant 2). Example: adding
   `provides|claude|p2|src|2.1.500|2026-01-01|extra` to the fixture whose minimum is 2.1.296 leaves
   `harness_min_version` at 2.1.296; removing the field-count check makes the case fail.
5. The six citations of `bin/keel:648-649` (ADR-0004 line 21, `docs/ideas/keel-on-codex.md` lines 141
   and 219, `docs/architecture/tiered-multi-harness-support.md` lines 257, 592 and 612), whose
   dual-write line task 5 deleted, read "`bin/keel` at v0.26.0" instead of a line number.
6. The fleet test reads the right column. Example: in `tests/test-keel-fleet.sh` the "problems column
   reflects the real count" case reads the problems field (the fifth, now that the harnesses column
   is gone) and fails when keel-fleet prints a wrong problems count.
7. ADR-0015 records the amendment to ADR-0013. It is `proposed`, names Bernard's decisions of
   2026-10-30 (keep a Codex refusal in `sensitive-guard`, detect `CODEX_VERSION` or a `turn_id`
   key only when `CLAUDE_PROJECT_DIR` is empty; name v0.26.0 wherever Codex users are told how to
   continue), and says ADR-0013's Consequences and Verification clauses on these two points are
   amended by it. ADR-0013's status row reads "accepted, amended by ADR-0015 (proposed)".

**Done when:** `tests/test-sensitive-guard.sh`, `tests/test-harness-resolve.sh` and
`tests/test-keel-fleet.sh` pass, and `tests/validate-citations.sh` and `tests/validate-skills.sh`
report OK.

- [x] **Step 11.1: Build it test first** Note: built by the implementer; reds quoted for behaviours 1 to 4 and 6 and reproduced by the spec reviewer for 1, 3 and 4; a fix pass restored the Codex refusal without python3

Follow `keel:tdd` for behaviours 1 to 4 and 6: write each test from its example and watch it fail
for the reason named (for 3 and 4, by removing `10#` or the field-count check in a scratch copy),
then implement. Behaviours 5 and 7 are documents.
Run: `tests/test-sensitive-guard.sh`
Expected before: FAIL, behaviour 1's case gets no output where it should ask. Expected after: PASS.

Run: `tests/run-tests.sh`.
Expected: PASS. This is the one boundary run the task schedules.

- [x] **Step 11.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; spec DEVIATES then fixed and re-checked; quality: no blocking, two pre-existing gaps recorded as follow-ups

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh tests/test-harness-resolve.sh \
        tests/test-keel-fleet.sh docs/decisions/ADR-0015-sensitive-guard-keeps-a-codex-refusal.md \
        docs/decisions/ADR-0013-claude-code-is-the-only-harness.md
git status --porcelain
```

Stage those paths, `lib/harness/resolve.sh` if changed, and each file whose citation this task
repaired, by name, and stop. **Do not commit.** The coordinator commits after both review passes,
with `git commit -s -m "fix(sensitive-guard): judge only the top-level list, and ask when the profile changes"`.

### Task 11b: a commit that changes the profile is asked before any early exit

Added by the coordinator on 2026-10-31 from the automated security review of task 11 and task 11's
quality review: the profile-staged ask runs after the early exits, so a commit that empties or
removes `hard_block_paths` exits silently and the next commit to a sensitive path is unguarded.
That defeats the fix audit M-01 asked for.

**Story:** G1, ADR-0013
**Files:**
- Modify: `hooks/sensitive-guard`
- Test: `tests/test-sensitive-guard.sh`

**Interfaces:**
- Consumes: task 11's hook
- Produces: nothing new

**Depends on:** task 11

**Behaviours:**

1. A commit staging `.keel/profile.json` asks, whatever the working-tree profile says. Examples, each
   in a repository whose committed profile lists `src/auth`: staging a profile with `"hard_block_paths":
   []`, staging one with the key removed, and staging one that does not parse each make `git commit -m
   x` print the `ask` decision naming the profile.
2. The list a commit is judged by includes the committed one. Example: with the committed profile
   listing `src/auth`, a working-tree profile (unstaged) listing nothing, and `src/auth/t.go` staged,
   `git commit -m x` asks.
3. A repository that declares nothing anywhere is still never asked. Example: no `hard_block_paths` at
   HEAD or in the working tree, a non-profile file staged: no output, exit 0.

**Done when:** `tests/test-sensitive-guard.sh` passes, and `tests/validate-citations.sh` and
`tests/validate-skills.sh` report OK.

- [x] **Step 11b.1: Build it test first** Note: built by the implementer; reds quoted (42/5, then 47/2 for the deleted profile) and reproduced by the reviewer for the first round

Follow `keel:tdd`: write each behaviour's tests from its examples, watch behaviours 1 and 2 fail on
task 11's hook (no output), then implement and watch them pass.
Run: `tests/test-sensitive-guard.sh`, then `tests/run-tests.sh` once at the boundary.

- [x] **Step 11b.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; combined review blocking on a deleted profile, fixed and re-reviewed

```bash
git add hooks/sensitive-guard tests/test-sensitive-guard.sh
git status --porcelain
```

Stage those paths and each file whose citation this task repaired, by name, and stop. **Do not
commit.** The coordinator commits with
`git commit -s -m "fix(sensitive-guard): ask on a profile change before any early exit"`.

## Notes for the coordinator

- **The minimum is 2.1.302, not 2.1.295.** The idea record proposed 2.1.295 because `onFailure`
  needs it. The ledger's rows record the version each primitive was verified on, and the highest a
  gate needs today is 2.1.302 (`pretooluse_agent_type`, for `review-guard`). That is conservative: a
  client between the true first version and 2.1.302 is warned without need. A row may record a lower
  version when the vendor's docs state "Requires vX".
- **ADR-0011.** Task 8 changes skill bodies and references, so the release that ships this plan owes
  the release gate's arm for skill text.
- **The plan review, 2026-10-29.** A reviewer found four blocking defects in the first draft: tasks
  that broke citations or a schema fingerprint that only a later task fixed, and a skill edit that
  broke a check owned by another task. Each task now owns its citation repairs and the schema bump
  carries its fingerprint, pin and profile. The reviewer also asked whether Codex would load keel's
  hooks without `.codex-plugin/`; Bernard chose to probe it first, which is task 1.
- **`keel plan batches`**, run on this version, printed:

  ```text
  alone: 1
  alone: 2
  alone: 3
  alone: 4
  alone: 5
  alone: 6
  alone: 7
  alone: 8
  alone: 9
  alone: 10
  why: task 2 depends on task 1
  why: task 3 has a Files block not in the strict form, so its paths are unknown
  why: task 4 has a Files block not in the strict form, so its paths are unknown
  why: task 5 has a Files block not in the strict form, so its paths are unknown
  why: task 6 has a Files block not in the strict form, so its paths are unknown
  why: task 7 has a Files block not in the strict form, so its paths are unknown
  why: task 9 has a Files block not in the strict form, so its paths are unknown
  why: task 10 has a Files block not in the strict form, so its paths are unknown
  check: in each batch, every Done when names only its task's own test, and each last step commits
  ```

- **Codex login, 2026-10-30.** Tasks 1 and 2b ran `codex exec` with a copy of the user's
  `~/.codex/auth.json` in a throwaway home. Codex rotated its refresh token there, and the rotated
  token was deleted with the throwaway home, so the user's real login was left with a revoked token
  (`refresh_token_reused`) and needs `codex login`. No later task runs Codex.
- **Follow-ups for the hooks, found during this run and not in it.** `sensitive-guard`: `git -c
  key=val commit` is not recognised as a commit; an unreadable profile on a commit exits 0 silently;
  the profile walk calls the external `dirname`; the walk starts from `$PWD`, which a cloud
  session's remote hook may set to the home directory; the CDPATH case task 2c added reads the
  hook's text and is stricter than correct output, so it should run the hook under a decoy
  `CDPATH` instead; the comment should state that a Codex process that inherited
  `CLAUDE_PROJECT_DIR` turns the refusal off. `done-guard`: a transcript whose rows parse but match
  no Claude Code shape reads as a clean turn instead of warning. `lib/context_watch.py`: on a
  non-Claude transcript `transcript_kind` reads the whole file on every call.
  The retired-key checks treat a register that prints some rows and then fails as a shorter
  register; both should read the subshell's exit status (task 4c's quality review).
  From task 6's quality review: the `harness=codex` grep in `tests/test-harness-claims.sh` has no
  test that it fires; the `cf_blank` resolver case repeats the `ghost` one; a stray
  `hooks/hooks.*.json` is now reported as an orphan hook and nothing pins that; the support page
  generator still loops over harnesses; the ledger and `resolve.sh` cite ADR-0003 for the evidence
  rule where ADR-0014 supersedes it.
  From task 7's quality review: when `claude` is a shell wrapper, the kill reaches only the shell
  and its child keeps running (doctor is not blocked); keel-fleet repeats the machine-wide version
  check per repository; a second ledger row for an already-verified primitive would raise the
  minimum.
- **From task 11's review, pre-existing:** (the commit that empties `hard_block_paths` is task 11b) a
  string value for
  `hard_block_paths` fails open on Claude Code (Python iterates its characters).
- **Not in this plan.** `keel-cursor`'s generator reads the archived `keel-internal` checkout; that
  is the port's to fix. The idea record's items are the next plan.
