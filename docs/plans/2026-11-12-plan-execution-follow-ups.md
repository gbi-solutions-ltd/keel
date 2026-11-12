# Plan execution follow-ups Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close the follow-ups PR #12 lists: `done-guard` sees a scoped test run the way a shell
does and judges an edit against every checkout of the repository, and `context_watch` keeps only
its own session's handoff, cannot be steered outside its state directory by a session id, and
cannot leave a stale stop marker behind.
**Stories:** none. The "Follow-ups" section of PR #12's body, from the per-task reviews, the
`review-code` passes and the security audit of 2026-11-12 (items W-01 to W-03); Bernard directed
on 2026-11-12: "fix the open follow-ups".
**ADRs:** ADR-0017 (suite checkpoints; why a scoped run satisfies `done-guard`); ADR-0012 (a task
carries two steps).
**Architecture:** two tasks, one per file. `hooks/done-guard` tokenises each Bash command with
`shlex` (punctuation as tokens) and reads it as simple commands, so quoting is respected and the
common wrappers (`bash`, `sh`, `./`, `env`, `time`, `VAR=value`) are seen through; the old regex is
the fallback when a command does not tokenise. It works out the repository's checkouts lazily,
only when the turn edited something. `lib/context_watch.py` builds every per-session state path
through one helper that refuses an unsafe id, marks the handoff it asks for with the session id,
and touches the marker when it cannot remove it.
**Implementer routing:** inherit
**Delivery:** pull-request (onto PR #12's branch, `feat/faster-plan-execution`)
**Concurrent batches:** none. Every task touches `hard_block_paths` and `CHANGELOG.md`.
**Suite checkpoints:** none; each task runs its boundary as written.
**Decided:** in this plan, put to Bernard at approval:
- A nested git repository that is neither a submodule nor a worktree of this one is a stated limit
  (W-01's first case): telling it from an unrelated repository would mean walking up the tree on
  every stop.
- The handoff is attributed by a `session: <id>` line the stop text asks for, since the hook cannot
  see who wrote the file.
**Reviewed:** by a dispatched plan reviewer on 2026-11-12: three blocking (shlex reads a newline as
whitespace; `os.utime` succeeds on the directory the existing failed-removal case uses; the existing
keep cases carry no `session:` line), and should-fix items on test setup (JSON escaping in
`row_bash`, a git shim, a committed profile for the worktree, a nested `TMPDIR`, an older s-2
marker), `hooks/context-watch:74` and the documents the match rule appears in. All folded in.
**Approved:** by Bernard, 2026-11-12: routing `inherit`, onto PR #12's branch, with the decisions
above as written.
**Task 3 added:** 2026-11-12, from the `review-code` re-review of tasks 1 and 2; Bernard approved
fixing every finding as one task, routing `inherit`.
**Shape:** behaviours with examples.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`. This plan runs on `feat/faster-plan-execution` (PR #12).
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Tasks 1 and 2 touch them.
- Hooks parse under `/bin/bash` 3.2 (`docs/standards.md`, "Scripts parse under bash 3.2"): python
  stays in the heredoc read into a variable, never inside `$( )`.
- **No `SKILL.md` body gains words.** All three this plan touches sit at the validator's 700-word
  body ceiling. New rules go in a reference (ADR-0011); a body line may be reworded to point at it, and
  its `wc -w` after the task is at most its count before.
- A change lands with the documents it makes wrong, each stating what is true now. Repair any
  `path:line` citation your edit shifts (`tests/test-validate-citations.sh`). Add one line for the
  task under `## Unreleased` in `CHANGELOG.md`.
- `tests/test-harness-claims.sh` fails any line in `README.md` or `docs/NN-*.md` that names
  `review-guard` or `hard_block_paths`, or uses gate or ceiling vocabulary, without a `keel:claim`
  tag within three lines: tag what you write the way the surrounding text does.
- `tests/run-tests.sh` takes about 5 minutes; each task's boundary run costs that.
- No em or en dashes anywhere, conventional commit messages, no attribution footers.
- Never `git stash`, in any form: the stash is shared by every worktree of this repository.

---


---

### Task 1: `done-guard` reads a command as a shell does, and knows every checkout

**Story:** PR #12 follow-ups 1, 2 (audit W-01), 4 (audit W-03) and 7; quality findings on lazy git
**Files:**
- Modify: `hooks/done-guard`
- Modify: `templates/profile.schema.json`
- Modify: `docs/profile-keys.md`
- Modify: `docs/snapshot.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-done-guard.sh`

**Depends on:** none

**Behaviours:**

1. A scoped prefix counts when a simple command begins with it after shell tokenising
   (`shlex.shlex(cmd, posix=True, punctuation_chars=True)` with `whitespace` set to `" \t\r"`, so
   a newline is a token: shlex otherwise reads it as whitespace and would stop splitting there, which
   the current regex does): simple commands are split at `;`, `&&`, `||`, `|`, `|&`, `&`, `(`, `)`,
   `{`, `}`, newlines and the words `then`, `do`, `else`; before
   matching, leading `VAR=value` words, `env` (with its `VAR=value` words), `time`, `command`, and a
   `bash` or `sh` followed by a path are dropped, and a leading `./` is removed from the first word.
   The prefix matches when the command's words begin with the prefix's words, its last word as a
   string prefix. Example: with `verify.test_one` `tests/{name}`, each of `bash tests/x.sh`,
   `./tests/x.sh`, `env CI=1 tests/x.sh`, `X=1 time tests/x.sh`, `make lint & tests/x.sh` and
   `if true; then tests/x.sh; fi`, `echo hi` newline `tests/x.sh`, and `$(tests/x.sh)` counts as a
   run (exit 0, no output, after an `Edit` of `<repo>/lib/foo.sh` under `required`).
2. Quoted text is not a command. Example: `echo "a;tests/x"` and `grep -n 'tests/x' f` do not count
   (the edit blocks); `shellcheck -x lib/foo.sh tests/*.sh` still does not count. `row_bash`
   (`tests/test-done-guard.sh:210`) does not escape JSON, so these cases build their Bash row with a
   JSON encoder (`python3 -c 'import json,sys; print(json.dumps(...))'`) and assert the command
   arrived intact; a malformed row is skipped silently and would block for the wrong reason.
3. A command `shlex` cannot tokenise (an unbalanced quote) falls back to the current regex, so the
   hook never errors on it. Example: Bash `tests/x.sh 'oops` counts as a run and the hook exits 0.
4. An edit is inside the repository when it resolves inside any checkout of it: git's top level for
   the event's `cwd`, every path `git worktree list --porcelain` names, and the superproject when
   `git rev-parse --show-superproject-working-tree` names one. Example: `cwd` in a linked worktree
   at `<tmp>/wt` and an `Edit` of `<repo>/lib/foo.sh` in the main checkout, no test run, under
   `required`, blocks; an `Edit` of `/tmp/elsewhere/x.py` still passes. Every checkout path goes
   through `realpath`, and `in_repo` returns the path relative to the checkout that holds the file,
   so `is_code` reads `docs_root` against the right root. The case needs a committed repository: a
   git identity set as `tests/keel-test-lib.sh:69` does, the profile committed so the worktree has
   it (the hook finds the profile from `$PWD` upward, `hooks/done-guard:63-73`), then
   `git worktree add`.
5. git runs only when the turn edited something. Example: with a `git` shim first on `PATH` that
   records each call to a file and then runs the real git, a Stop whose calls hold no `Edit`,
   `Write` or `NotebookEdit` exits 0 with no output and the shim records no call; a Stop with an
   `Edit` records at least one. (Removing git from `PATH` proves nothing: the hook already catches
   `OSError`, `hooks/done-guard:230`.)
6. The "ITS LIMIT" header states the tokenised match, the fallback, the checkouts it knows and the
   one it does not (a nested repository that is neither a submodule nor a worktree), and what
   tokenising cannot see: a run inside backticks, anything after an unquoted `#`, and a
   backslash-newline continuation read as one word. Example: the header contains `shlex`,
   `nested repository` and `backticks`.
7. The `gates.done_verified` description in `templates/profile.schema.json` and
   `docs/snapshot.md:69-71` state the tokenised match, and `docs/profile-keys.md` is regenerated
   (`tests/generate-profile-keys.sh`). Example: none of them says the scoped prefix is matched where
   it begins a command by a regular expression alone.
8. `CHANGELOG.md`'s done-guard entry under `## Unreleased` reads as a sentence and states the
   tokenised match. Example: it no longer contains "a prefix the two share once".
9. Any citation into `hooks/done-guard` the edit shifts is repaired, wherever it lives (a citation
   in a plan under `docs/plans/` is reported to the coordinator rather than edited). Example:
   `tests/test-validate-citations.sh` and `tests/test-harness-claims.sh` pass.

**Done when:** `tests/test-done-guard.sh`, `tests/test-validate-citations.sh` and
`tests/test-harness-claims.sh` pass.

- [x] **Step 1.1: Build it test first** Note: implementer resumed fresh after a /clear; red for behaviours 1-5 reproduced by the spec reviewer at HEAD (65/11), round-2 red witnessed (77/2); 2 rounds (spec DEVIATES on evidence only, quality 2 should-fix fixed); routing inherit; loop full; coordinator ran run-tests.sh green on the final tree

Follow `keel:tdd`. Write cases for behaviours 1 to 5 in `tests/test-done-guard.sh`, after the
existing cases.
Run: `tests/test-done-guard.sh`
Expected before the implementation: FAIL, behaviour 1's wrapper cases, behaviour 2's quoted case,
behaviour 4's worktree case and behaviour 5's shim case (git called on a Stop with no edit) fail. Expected after: PASS. Quote the
failing output in your report.

Run: `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: staged by the implementer; coordinator added plan citation repairs

```bash
git add hooks/done-guard tests/test-done-guard.sh templates/profile.schema.json docs/profile-keys.md \
        docs/snapshot.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any citation repairs by name, and stop. **Do not commit.** The
coordinator commits after both review passes, with
`git commit -m "fix(done-guard): read a command as a shell does, know every checkout"`.

---

### Task 2: `context_watch` keeps its own handoff and its own state paths

**Story:** PR #12 follow-ups 3 (audit W-02), 5 and 6
**Files:**
- Modify: `lib/context_watch.py`
- Modify: `hooks/context-watch`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-context-watch.sh`

**Depends on:** task 1

**Behaviours:**

1. Every per-session state path (`.stop`, `.measure`) is built by one helper, and a session id
   holding `/`, `\`, `..` or a NUL is read as `nosession`. `hooks/context-watch:74` builds the
   `.measure` path in bash for its cached shortcut, so it applies the same rule. Example: with
   `TMPDIR` set to a nested temp directory for the case, a PreCompact event with `session_id`
   `../../victim`, where `<state dir>/../../victim.measure` exists, leaves that file in place; a
   normal id still gets `<state dir>/<id>.measure` removed at PreCompact as today.
2. The stop text asks for a `session: <id>` line in the handoff, and PreCompact keeps a handoff only
   when it is newer than the marker and carries this session's line. Example: a handoff written
   after the stop with `session: s-1` is kept at s-1's PreCompact; the same handoff is replaced by
   the render at s-2's PreCompact, s-2 having its own stop marker older than the handoff (without
   one the render is written anyway, so the case would pass before the change); the stop text
   contains `session: ` followed by the session id. The existing keep cases
   (`tests/test-context-watch.sh:371` and `:676`) gain the `session:` line, since without it their
   handoffs are now replaced. Test session ids carry `$$`, so they do not collide with a live
   session's state.
3. When the marker cannot be removed, PreCompact sets its mtime to now (`os.utime`), so the kept
   handoff no longer releases the next stop; only if that fails too is the stderr line written.
   Example: with the marker a directory (removal fails, `os.utime` succeeds), after PreCompact its
   mtime is newer than the handoff and a `Bash` PreToolUse past the threshold is denied; this
   replaces the directory case once at `:668-683` (now `tests/test-context-watch.sh:815-860`). The stderr line
   stays tested by running the library through `runpy` with `os.remove` and `os.utime` replaced by
   functions that raise `OSError`, expecting the line and exit 0.
4. `docs/05-token-and-memory-design.md` states the session line and the touch fallback where it
   describes PreCompact. Example: it contains `session:` and `mtime`.
5. Any citation into `lib/context_watch.py` or `tests/test-context-watch.sh` the edit shifts is
   repaired, wherever it lives (a citation in a plan under `docs/plans/` is reported to the
   coordinator rather than edited). Example: `tests/test-validate-citations.sh` and
   `tests/test-harness-claims.sh` pass.

**Done when:** `tests/test-context-watch.sh`, `tests/test-validate-citations.sh` and
`tests/test-harness-claims.sh` pass.

- [x] **Step 2.1: Build it test first** Note: red witnessed in both rounds (92/6, then 100/6); 2 rounds (spec COMPLIES; quality 2 should-fix fixed: lenient session line, empty id keeps old rule); routing inherit; loop full; coordinator ran run-tests.sh green on the final tree

Follow `keel:tdd`. Write cases for behaviours 1 to 3 in `tests/test-context-watch.sh`, after the
existing cases.
Run: `tests/test-context-watch.sh`
Expected before the implementation: FAIL, behaviour 1's traversal case (the file outside is
removed), behaviour 2's other-session case and session-line case, and behaviour 3's touch case
fail. Expected after: PASS. Quote the failing output in your report.

Run: `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 2.2: Hand over** Note: staged by the implementer; coordinator repaired this plan's citations

```bash
git add lib/context_watch.py hooks/context-watch tests/test-context-watch.sh \
        docs/05-token-and-memory-design.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any citation repairs by name, and stop. **Do not commit.** The
coordinator commits after both review passes, with
`git commit -m "fix(context-watch): own handoff, safe state paths, no stale marker"`.

---

### Task 3: review fix, pin the surviving mutants and tidy what the review found

**Story:** the `review-code` rubric re-review of 37c5d43 and 417a1a3 on 2026-11-12: three surviving
mutants (Blocking), one untested behaviour (Should fix), three Consider items. Bernard directed on
2026-11-12 that all of them be fixed as one task.
**Files:**
- Modify: `hooks/done-guard`
- Modify: `lib/context_watch.py`
- Modify: `CHANGELOG.md`
- Test: `tests/test-done-guard.sh`
- Test: `tests/test-context-watch.sh`

**Depends on:** tasks 1 and 2

**Behaviours:**

1. The bash session-id rule in `hooks/context-watch:72` is observed by a test. Example: with
   `TMPDIR` nested for the case, a fresh low reading (`"$(date +%s) 1 200000"`) written to
   `<state dir>/../../victim.measure` resolved inside that nested tree, no `nosession.measure`, and
   a `python3` shim first on `PATH` that records each call and then runs the real one, a PreToolUse
   `Edit` with `session_id` `../../victim` records a python call. Deleting the `case` line at `:72`
   turns the case red (bash reads the planted file and exits before python runs). No production
   change is expected.
2. An escaped separator is not a separator. Example: `shell_case block 'echo \; tests/x.sh'`;
   dropping the backslash clause at `hooks/done-guard:169` turns it red.
3. A quoted `#` is not a comment. Example: `shell_case quiet "echo '#'; tests/x.sh"`; dropping
   `bare and` at `hooks/done-guard:173` turns it red.
4. An edit in the superproject, made from a submodule's `cwd`, is in the repository. Example: a
   committed superproject with a submodule added (`git -c protocol.file.allow=always submodule add`),
   `cwd` in the submodule, an `Edit` of `<super>/lib/foo.sh`, no test run, under `required`,
   blocks; deleting the superproject line at `hooks/done-guard:238` turns it red.
5. Telling a bare token from a quoted one costs time linear in the command, not quadratic. Example:
   a Bash command of about 440 KB (a heredoc of repeated short lines) followed by `; tests/x.sh` is
   judged a run, and the hook finishes in under 2 s (it took 3.7 s with the prefix slice at
   `hooks/done-guard:168`). Compare characters at indices into `cmd` instead of slicing and
   stripping a prefix per token; the existing quoted and escaped cases stay green.
6. `CHANGELOG.md`'s older `## Unreleased` line (`CHANGELOG.md:28`), which says `PreCompact` writes
   the stderr line whenever it cannot remove the marker, is reworded or merged so it agrees with
   the newer entry: the line is written only when the touch fails too. Example: no line under
   `## Unreleased` says the line is written on a failed removal alone.
7. With no session id, the stop text does not ask for a `session:` line. Example: a stop fired with
   `"session_id":""` under a nested `TMPDIR` produces text without `session: `; with an id, the
   text still contains `session: <id>`.
8. Any citation the edit shifts is repaired, wherever it lives (a citation in a plan under
   `docs/plans/` is reported to the coordinator rather than edited). Example:
   `tests/test-validate-citations.sh` and `tests/test-harness-claims.sh` pass.

**Done when:** `tests/test-done-guard.sh`, `tests/test-context-watch.sh`,
`tests/test-validate-citations.sh` and `tests/test-harness-claims.sh` pass.

- [ ] **Step 3.1: Build it test first**

Follow `keel:tdd`. Write cases for behaviours 1 to 5 and 7 after the existing cases.
Run: `tests/test-done-guard.sh` and `tests/test-context-watch.sh`
Expected before the implementation: behaviours 5 and 7 fail; behaviours 1 to 4 pin code that is
already right, so each is proved instead by deleting the line it names, watching the case go red,
and restoring the line. Quote each red in your report. Expected after: PASS.

Run: `tests/run-tests.sh` and the lint command.
Expected: PASS, or reds this task did not cause, each named. This is the one boundary run the task
schedules.

- [ ] **Step 3.2: Hand over**

```bash
git add hooks/done-guard lib/context_watch.py CHANGELOG.md tests/test-done-guard.sh \
        tests/test-context-watch.sh
git status --porcelain
```

Stage exactly those paths, and any citation repairs by name, and stop. **Do not commit.** The
coordinator commits after both review passes, with
`git commit -m "fix(watchdogs): pin the surviving mutants, linear token check"`.
