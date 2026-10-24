# A deny list pattern that is not valid refuses the scan Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** a deny list pattern that is not a valid extended regular expression stops every leak
scan with a message naming its deny list line, instead of silently checking nothing.
**Stories:** none. The input is the coordinator's decided design below, relayed on 2026-10-24;
the task has more than 5 behaviours because the coordinator designed it and a plan reviewer read
it, so the short path's limit does not apply.
**ADRs:** ADR-0012 (a task carries two steps), ADR-0008 (the implementer is routed to
`keel-implementer`), ADR-0011 (no task edits a skill body or a reference a skill reads, so no
release gate arm is owed for skill text)
**Architecture:** `deny_load` in `lib/deny-list.sh` tries each pattern it reads from the file with
`grep -E` over empty input, in the caller's locale and in the C locale, leaves out each one that
does not compile in either, and lists it in a new array, `DENY_INVALID`. Each caller refuses
while that array is not empty: `keel scan --leaks` and `--leaks-message` exit 2 after the mode
line, which the `pre-push` and `commit-msg` hooks already treat as a refusal,
`tests/no-internal-leaks.sh` exits 1 before it scans, and `keel guard status` says so. One task,
with its documents and the changelog clause.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. The plan has one task, which runs alone and hands over for the
coordinator to commit. `keel plan batches` printed:

```text
alone: 1
check: in each batch, every Done when names only its task's own test, and each last step commits
```

## The decided design

Decided by the coordinator and relayed on 2026-10-24. The task does not reopen it.

1. Every pattern read from the file is validated at load time, in `deny_load`. A pattern is invalid
   when `grep -E -q -- "$pattern"` over empty input, its errors discarded, exits 2 in the caller's
   locale **or** under `LC_ALL=C`; exit 1 means valid and no match. Both, because `keel scan` greps
   under `LC_ALL=C` and `tests/no-internal-leaks.sh` in the caller's locale, and what compiles
   differs between them (amended after plan review, 2026-10-24). The two generic patterns are not
   tried.
2. Invalid patterns are collected and not added to `DENY`. `deny_load` sets one more name,
   `DENY_INVALID`, an array of `deny list line <n>` strings numbered as `DENY_WHERE` numbers them;
   it is an empty array when nothing is invalid or the file is absent. `DENY_LOADED` counts only
   the valid patterns.
3. `keel scan --leaks` and `--leaks-message` print, after the mode line and before any scan, one
   line per invalid pattern, `leak guard: <where>: not a valid pattern, so it checked nothing`,
   then `leak guard: refusing to scan: fix the deny list at <path>`, with `<path>` written as the
   mode line writes it, and exit 2.
4. `tests/no-internal-leaks.sh` prints `FAIL  <where>: not a valid pattern` for each and exits 1
   before scanning.
5. No output prints the pattern text.
6. `keel guard status`, with the leak guard on and an invalid pattern in the list, reads
   `leak guard: on, but <n> deny list pattern(s) are not valid, so scans refuse. See 'keel scan
   --leaks-message <file>'`.

## What the tree says

Read while planning, on branch `fix/deny-list-invalid-pattern` at `8315426`.

| Finding | Where |
|---|---|
| The fail-open, measured: with a deny list holding `Quillbank`, `Quill(bank`, `\bQBK\b` and `zephyr[ledger`, `keel scan --leaks-message` on a message holding `Quill(bank and zephyr[ledger` prints `deny list loaded from ~/broken.txt (4 patterns)` and `message checked, no findings`, exit 0, and `tests/no-internal-leaks.sh` on a tree holding `Quill(bank` prints `(4 patterns)` and `OK`, exit 0 | a scratch fixture |
| The two greps that discard the error: `keel scan`'s per-pattern grep, and the scanner's per-pattern grep | line 2487 of `bin/keel`; line 140 of `tests/no-internal-leaks.sh` |
| GNU grep 3.11 exits 2, over empty input, for `Quill(bank`, `zephyr[ledger`, a trailing backslash, `[[:alpha:]` and `a{2,1}`, and 1 for `a{1`, `a)`, `*abc`, `\-x` and `\bQBK\b`; the same under `LC_ALL=C` and as `printf '' \| grep` | measured while planning |
| What compiles depends on the locale. `[ä-é]` exits 1 under `LC_ALL=C` and 2 under `LC_ALL=C.utf8` (measured here); the plan reviewer measured `[[=é=]]` compiling under `en_US.UTF-8` and exiting 2 under `C`, where `keel scan` would then skip it in silence. This machine has only `C`, `C.utf8` and `POSIX`, so the second was not repeated here: `caf[[=é=]]` exits 2 under both installed locales | the `LC_ALL=C` in the grep at line 2487 of `bin/keel`; measured |
| `lib/` and `bin/` may hold no quiet grep pipeline: `printf '' \| grep -E -q` in `lib/deny-list.sh` fails rule 3 of the lint in `tests/test-grep-quiet.sh`. `grep -E -q -- "$p" < /dev/null` reads the same empty input and gave the same exit status for every pattern above | the "Rule 3" block of `tests/test-grep-quiet.sh` |
| `deny_load` is the function at lines 36 to 52 of `lib/deny-list.sh`; the comment block above it (lines 5 to 13, 23 to 26 and 34) describes the names it sets and the file format | `lib/deny-list.sh` |
| `leak_scan` prints its mode line in the `if [ -f "$DENY_FILE" ]` block, lines 2442 to 2446 of `bin/keel`, and checks its arguments in the `case "$mode"` that starts at line 2447; `$shown` already holds the path with `$HOME/` written `~/` | `bin/keel` |
| The `pre-push` hook refuses on any non-zero exit of `keel scan --leaks` (line 2955 of `bin/keel`, inside `guard_hook_body`) and prints `keel guard: push refused by the leak guard.` (line 2958). The `commit-msg` hook's `*)` branch (lines 3092 and 3093, inside `guard_commit_msg_body`) prints `keel guard: the leak guard is on and the keel on PATH cannot check a message, so nothing was checked. Commit refused.` and exits 1 for exit 2. Both hooks call the `keel` on PATH, so an installed hook needs no reinstall | `bin/keel` |
| `keel guard status` builds its leak guard line in the `if guard_leak_on` block, lines 3358 to 3370 of `bin/keel`: commit-msg missing first, then `elif [ -f "$DENY_FILE" ]` (line 3365), then the warning | `bin/keel` |
| Case 15 of `tests/test-leak-guard.sh` counts every `grep` the scan starts through a wrapper first on PATH and expects 6 (lines 417 and 418). The validation runs inside the same `keel` process, two calls per loaded pattern (the caller's locale and `C`), so the three loaded patterns add six calls: 12 | `tests/test-leak-guard.sh` |
| A loader case of `tests/test-no-leaks.sh` fails any name the loader leaves behind that does not start with `DENY` or `deny_` | the case "every name the loader sets starts with DENY or deny_" |
| Citations. The highest line of `bin/keel` any file cites is 2174; of `docs/03-install-and-distribution.md`, 227 (the range 210 to 227, cited from two plans; an idea cites 212 to 222); `CHANGELOG.md` is cited at lines 3, 10 to 18 and 12. Nothing cites a line of `lib/deny-list.sh`, `tests/no-internal-leaks.sh`, `tests/test-no-leaks.sh` or `tests/test-leak-guard.sh`; one phrase citation names the `list_files` comment of `tests/no-internal-leaks.sh`, which this plan does not touch. Inserting lines at every place this plan inserts them was measured in a copy of the tree: `tests/validate-citations.sh` passed, 1,760 citations | `git grep`; a scratch copy |
| Baselines: `tests/test-leak-guard.sh` 169 passed, `tests/test-no-leaks.sh` 31 passed, `tests/validate-citations.sh` OK | measured while planning |

## Decided while planning

- **The empty input is `< /dev/null`, not a `printf ''` pipeline,** for the lint finding in the
  table above. It is the decided test with the same input and the same exit status.
- **Each pattern is tried twice,** `grep -E -q -- "$p" < /dev/null` and the same under
  `LC_ALL=C`, and is invalid when either exits 2. Only `C` would reopen the hole for
  `tests/no-internal-leaks.sh`, which greps in the caller's locale; only the caller's locale leaves
  it open for `keel scan`.
- **The refusal comes straight after the mode line,** before the argument checks and before the
  `nothing pushed, nothing checked` short cut, so `keel scan --leaks origin`, which the `pre-push`
  hook runs when started by hand or for a push that only deletes, also refuses and names the line.
- **`tests/no-internal-leaks.sh --list-patterns` prints the valid patterns and exits 0.** It runs
  before the mode line and is a listing for the coverage case of `tests/test-no-leaks.sh`, not a
  scan; the refusal follows the mode line.
- **`keel guard status` is in:** one `elif` and one `say`, two lines.
- **The changelog extends the existing `## Unreleased` entry** rather than adding a bullet: the
  leak guard is itself unreleased, so this is part of what that entry describes.
- **One task, not two.** The documents change four paragraphs and the changelog one clause,
  each stating what the code does; a test case pins the document's new paragraph, and a reviewer
  who rejects the behaviour rejects the text that describes it. `docs/standards.md` ("Documentation
  lands with the change") asks for them in the same commit.

## Risks

1. **Locale.** `keel scan --leaks` greps under `LC_ALL=C` and `tests/no-internal-leaks.sh` in the
   caller's locale, and what compiles differs: `[ä-é]` compiles under `C` and not under `C.utf8`
   (measured here), and `[[=é=]]` compiles under `en_US.UTF-8` and not under `C` (measured by the
   plan reviewer; that locale is not installed here). Probing in both locales closes this for the
   two scanners as they are. What stays open: a third locale (a scan run under a locale other than
   the probe's), and a pattern that compiles in both but means something else in each, such as a
   range read by bytes under `C` and by characters under UTF-8, which matches differently rather
   than not at all.
2. **GNU and BSD grep disagree on what compiles** (`a)` and `a{1` pass GNU grep 3.11). The check
   uses the grep that scans, so on each machine it agrees with its own scan, but a list that loads
   on Linux can refuse on macOS. That is the fail-closed answer, and it may surprise. The test
   samples, an unclosed parenthesis and an unclosed bracket, are errors in both; macOS was not run
   while planning, and the CI macOS job runs the suite under bash 3.2 and BSD grep.
3. **Both hooks' refusal text misleads for this cause.** The `commit-msg` line says the keel on
   PATH cannot check a message; the `pre-push` block goes on, "Each finding above names a commit, a
   field or a file, and the deny list line whose pattern matched" (lines 2960 to 2963 of
   `bin/keel`), when there is no finding. The scan's own lines above each name the deny list line
   and the file. Left as is by the decided design. The follow-up: give exit 2 its own line in both
   hooks, which changes the generated hook bodies and so needs `keel guard install` re-run in each
   clone.
4. **A broken list refuses every push,** a push that only deletes a branch included, and every
   commit in a repository with the leak guard on. `git push --no-verify` and
   `git commit --no-verify` remain the deliberate way past, as for any refusal.
5. **The fix reaches a machine only through the `keel` on its PATH.** Until that clone is updated
   after the merge, the fail-open stands there.
6. **A valid pattern that matches nothing is still silent.** This catches patterns that do not
   compile, not typos that compile. The likeliest way a list goes quiet is a line ending in a
   carriage return, a list saved with Windows line endings: `Quillbank` followed by a carriage
   return compiles and then matches only where a carriage return follows the name. The loader keeps
   the carriage return as it does today; this plan does not change that. `lib/deny-list.sh` already
   records the reduction and the `pattern<TAB>sample` format that would close it.
7. **Cost:** two `grep` calls per pattern line on every load, about 50 on the owner's list of 25;
   25 calls took 39 milliseconds here.

## Global constraints

From the global constraints of `docs/plans/2026-10-22-public-first-development.md`, which still
apply, restated for this plan.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` over the files `verify.lint` names. `verify.test_affected` is null.
- The task runs on the branch `fix/deny-list-invalid-pattern`, never on `main`. Where the working
  copy is reached through the remote device shell, each call is a fresh shell stopped at 180
  seconds: run the task's Done-when commands there and leave `tests/run-tests.sh` (which runs
  `tests/test-keel.sh`, longer than that) to the coordinator. Where it is not, the boundary run is
  `tests/run-tests.sh`.
- Shell runs on bash 3.2 (macOS `/bin/bash`) and on bash 5: no `${var,,}`, `${var^^}`, `mapfile`,
  `readarray`, `declare -A`, `[[ -v name ]]`, `local -n`, `realpath` or `readlink -f`. An array that
  can be empty expands under `set -u` as `${a[@]+"${a[@]}"}`. No `sed -i`: BSD sed needs a suffix
  and GNU sed refuses one, so a file is rewritten through a temporary file. Generated hook bodies
  obey the same rules, because they run under whatever `bash` the owner's PATH finds.
- `shellcheck -x` runs at default severity, so an info finding fails the lint.
- A test file holding a quiet grep pipeline loads the shim on its `set -uo pipefail` line, exactly
  `set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"`, and `lib/` and `bin/` hold
  no quiet grep pipeline at all: `tests/test-grep-quiet.sh` enforces both.
- `docs/standards.md`: no em or en dashes anywhere, fenced blocks included; prose lines at most 100
  columns; no `@` links; relative links resolve. No task edits `docs/standards.md`: other documents
  cite its line numbers. `CHANGELOG.md` entries wrap at 100 columns with a two-space continuation
  indent.
- **Citations.** `tests/validate-citations.sh` fails a citation that lands on a blank line or past
  the end of its file. `tests/validate-skills.sh`, `tests/validate-citations.sh` and
  `tests/run-tests.sh` keep their line counts; this plan edits none of them, and a new `add` call in
  `tests/run-tests.sh` would join an existing line after `; `. **`bin/keel` grows only below its
  scan walk:** the last line of it any document cites is line 2174, so every new line of `bin/keel`
  goes after line 2180, and no line at or above 2180 moves. **The task runs
  `tests/validate-citations.sh` before its last step, and a report from it stops the task:** the
  task does not repair another file's citation, because its staging list names only its own files.
  The report names each stale citation, and the coordinator adds a task for it. Write any line
  reference in prose as "line N of `file`", never in the citation form.
- **No literal developer home path in anything committed**, tests, documents and this plan's tick
  notes alike: the leak guard's generic patterns would refuse the push. Output quoted in a document
  or a `--note` writes the home directory as `<home>` or `~`.
- A test file that makes commits or runs a hook isolates git configuration itself: it exports
  `GIT_CONFIG_SYSTEM=/dev/null` and a `GIT_CONFIG_GLOBAL` pointing at a file it writes (with
  `user.name`, `user.email` and `commit.gpgsign = false`), unsets `GIT_CONFIG_COUNT` and any
  `GIT_CONFIG_KEY_*` and `GIT_CONFIG_VALUE_*`, and every leak-guard case sets `KEEL_DENY_FILE` and
  `HOME` explicitly, so the owner's real list and identity never reach a test.
  `tests/test-leak-guard.sh` already does all of this; new cases use its helpers.
- `keel guard install --leak-guard` is run only in the main working copy or a test fixture, never
  inside a batch worktree: worktrees share `.git/hooks`.
- Tests use invented identifiers only, never a real client, partner, repository or schema name:
  `Quillbank`, `zephyr-ledger`, `QBK` and the like. A sample of a generic pattern (a developer home
  path) is assembled from pieces in the test, `"/ho""me/someone"`, so `tests/no-internal-leaks.sh`
  never reports the test file itself. A deny list a test writes lives outside the fixture tree, as
  `tests/test-no-leaks.sh` explains.
- Nothing the leak guard prints contains the text a pattern matched, the pattern itself, a commit
  subject, or a path or ref name that itself matches a pattern. This covers the new lines: they
  name a deny list line, never its pattern.
- `hard_block_paths` are `hooks`, `lib/harness`, `settings.json`, `.github/workflows`,
  `templates/ci-review.yml` and `lib/context_watch.py`. This plan touches none; the generated hooks
  live in `bin/keel`, not under `hooks/`, and this plan does not change them. `keel plan risk` over
  the task's files printed `loop: light`, exit 0.
- No task edits anything under `skills/`, `agents/`, `templates/` or `output-styles/`, so no
  release gate arm is owed by this plan.
- Documents state the current state; history goes to `CHANGELOG.md` (`docs/standards.md`, "Shipped
  prose states the current state").
- Exact text given in a task is used exactly, rewrapped to 100 columns where it replaces wrapped
  prose. If a text this plan says to replace is not found exactly once, stop and report.
- Do not edit this plan file, other than ticking it.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. The implementer
  stages and never commits; the coordinator commits after both review passes, with `git commit -s`.
- No implementer or coordinator task pushes, merges, creates or archives a repository, changes a
  repository setting, or deletes anything outside the tracked tree.

---

### Task 1: Refuse to scan when a deny list pattern is not valid (implementer)

**Files:**
- Modify: `lib/deny-list.sh`, `tests/no-internal-leaks.sh`, `bin/keel`,
  `docs/03-install-and-distribution.md` and `CHANGELOG.md`
- Test: `tests/test-no-leaks.sh` and `tests/test-leak-guard.sh`

**Interfaces:**
- Consumes: `deny_load` and the four names it sets today (`DENY`, `DENY_WHERE`, `DENY_FILE`,
  `DENY_LOADED`), lines 36 to 52 of `lib/deny-list.sh`; `$shown` and `say` inside `leak_scan` in
  `bin/keel`; `guard_leak_on` and the status block of `cmd_guard`.
- Produces: `deny_load` sets a fifth name. The contract, with the four existing names as they read
  after this task:

```bash
deny_load      # no arguments; sets the five names below; returns 0
DENY           # array: '/Users/[a-z]' '/home/[a-z]', then each VALID pattern line of the file
DENY_WHERE     # array, same length: 'generic pattern 1' 'generic pattern 2' 'deny list line <n>'...
DENY_FILE      # ${KEEL_DENY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/keel/internal-deny-list.txt}
DENY_LOADED    # how many VALID patterns came from the file; 0 when it is absent
DENY_INVALID   # array: 'deny list line <n>' for each pattern line that does not compile, in file
               # order; () when none does or the file is absent, reset on every call
```

  A pattern line does not compile when either of these exits 2, the first in the caller's locale:

```bash
grep -E -q -- "$line" < /dev/null 2>/dev/null
LC_ALL=C grep -E -q -- "$line" < /dev/null 2>/dev/null
```
- Produces: these output lines, exactly, `<where>` being a `DENY_INVALID` entry and `<path>` the
  deny list path with a leading `$HOME/` written `~/`:

```text
leak guard: <where>: not a valid pattern, so it checked nothing
leak guard: refusing to scan: fix the deny list at <path>
FAIL  <where>: not a valid pattern
leak guard: on, but <n> deny list pattern(s) are not valid, so scans refuse. See 'keel scan --leaks-message <file>'
```

**Depends on:** none

**Behaviours:**

Every example below uses this deny list, written by the test outside any fixture tree and called
the broken list. Line 1 is a comment, line 2 `Quillbank`, line 3 an unclosed parenthesis, line 4
`\bQBK\b`, line 5 an unclosed bracket:

```text
# invented identifiers, two of them not valid
Quillbank
Quill(bank
\bQBK\b
zephyr[ledger
```

1. **The loader validates what it reads.** With `KEEL_DENY_FILE` naming the broken list,
   `deny_load` returns 0 and leaves `DENY` as `/Users/[a-z]`, `/home/[a-z]`, `Quillbank`,
   `\bQBK\b`; `DENY_WHERE` as `generic pattern 1`, `generic pattern 2`, `deny list line 2`,
   `deny list line 4`; `DENY_LOADED` 2; and `DENY_INVALID` as `deny list line 3`,
   `deny list line 5`. With the five-pattern list the existing loader cases use, and with an absent
   file, `printf '%s' "${#DENY_INVALID[@]}"` under `set -u` prints `0` with no `unbound variable`
   error. Called first with the broken list and then, in the same shell, with the five-pattern list,
   it leaves `DENY_INVALID` empty. The two generic patterns are never tried. Every name it sets
   still starts with `DENY` or `deny_`, so the existing name case passes. The test is the pair in
   Interfaces, written without a pipeline because `lib/` may hold no quiet grep pipeline.
   **Locale examples**, each run in a child shell with `LC_ALL` set explicitly, over a list holding
   `caf[[=é=]]` on line 1 and `[ä-é]` on line 2:
   - `caf[[=é=]]` is in `DENY_INVALID` as `deny list line 1` whatever the caller's locale: under
     `LC_ALL=C` always, and under `en_US.UTF-8` and under `C.utf8` where each is installed. The
     plan reviewer measured it compiling under `en_US.UTF-8` and failing under `C`, so a probe in
     the caller's locale alone fails this case there.
   - For `[ä-é]` the case takes its expectation from grep itself: under each locale it runs, the
     line is in `DENY_INVALID` exactly when `grep -E` over empty input exits 2 under that locale or
     under `C`. With GNU grep 3.11 under `C.utf8` that is invalid (2 under `C.utf8`, 1 under `C`),
     so a probe under `C` alone fails this case; under `LC_ALL=C` it is loaded.
   - A locale is installed when `locale -a` lists it, compared case-insensitively with hyphens
     dropped (`C.UTF-8` and `C.utf8` are one name), using `tr`, never `${var,,}`; the child shell
     uses the name as `locale -a` prints it. Where a locale is not installed, its cases print
     `  SKIP  <case>: locale <name> is not installed` and count as neither pass nor fail, so the
     file stays green on a machine with only `C`, where the `LC_ALL=C` cases still run.

   The cases
   go in `tests/test-no-leaks.sh` after its last case and before its summary `printf` (line 357),
   each sourcing the loader in a child shell as `probe` does; `probe` and the existing cases are not
   edited.
2. **The comment block of `lib/deny-list.sh` says what is true now.** "sets four names" (line 5)
   becomes "sets five names"; the `DENY` line says "each valid pattern line of the file"; the
   `DENY_LOADED` line says "how many valid patterns came from the file"; a `DENY_INVALID` entry is
   added after it, aligned with the others: `'deny list line <n>' for each pattern line that is not
   a valid ERE, numbered as DENY_WHERE is; empty when there is none or the file is absent`. After
   the paragraph ending "each caller prints which mode it ran in before any finding." (line 26) a
   paragraph is added, as comment lines:

   ```text
   A pattern line that is not a valid ERE is not loaded. grep exits 2 on it and each caller
   discards grep's errors, so it would match nothing and say nothing: a name never checked, under a
   guard that reports a clean scan. Each line is tried with `grep -E` over empty input as it is
   read, in the caller's locale and under LC_ALL=C, because `keel scan` greps under C and
   tests/no-internal-leaks.sh in the caller's locale and what compiles differs between them. Exit 2
   in either means it does not compile, and it is listed in DENY_INVALID; every caller refuses to
   scan while that list is not empty, so a broken list fails closed rather than open.
   ```

   The comment on line 34 names `DENY_INVALID` with the others the sourcing scripts read. Example:
   `grep -c DENY_INVALID lib/deny-list.sh` prints at least `3`, and no comment line is over 100
   columns.
3. **`tests/no-internal-leaks.sh` refuses before it scans.** Directly after its mode line (the
   `printf 'mode  %s\n'` on line 85), when `DENY_INVALID` is not empty it prints one
   `FAIL  <where>: not a valid pattern` per entry, in order, and exits 1, printing nothing else.
   Example: in a fixture tree whose skill names `Quillbank`, with `KEEL_DENY_FILE` naming the broken
   list, the whole output is exactly these three lines, exit 1:

   ```text
   mode  internal deny list loaded from <the broken list's path> (2 patterns)
   FAIL  deny list line 3: not a valid pattern
   FAIL  deny list line 5: not a valid pattern
   ```

   and holds no `project-specific identifier` line, no `Quill(` and no `zephyr[`. With the broken
   list, `--list-patterns` prints the four valid patterns, generic first, exit 0. With the
   five-pattern list or no list, every existing case passes unchanged. The loop over
   `DENY_INVALID` sits inside the check that `${#DENY_INVALID[@]}` is above 0, or expands the array
   as `${DENY_INVALID[@]+"${DENY_INVALID[@]}"}`, since bash 3.2 under `set -u` fails on a bare
   `"${DENY_INVALID[@]}"` when it is empty. Line 13 of the file,
   `# Exits 0 when clean, 1 on any match.`, becomes these two comment lines:

   ```text
   # Exits 0 when clean, 1 on any match, and 1 before scanning when a deny list pattern is not a
   # valid regular expression.
   ```

   The cases go in `tests/test-no-leaks.sh` beside those of behaviour 1.
4. **`keel scan --leaks` and `--leaks-message` refuse after the mode line.** The new lines go in
   `leak_scan`, directly after the `fi` that closes the mode-line block (line 2446 of `bin/keel`)
   and before `case "$mode" in` (line 2447): when `${#DENY_INVALID[@]}` is above 0, one `say` per
   entry, then the refusing line using `$shown`, then `return 2`. The loop sits inside that check
   (or expands the array as `${DENY_INVALID[@]+"${DENY_INVALID[@]}"}`), for bash 3.2 under
   `set -u`. Examples, in a `tests/test-leak-guard.sh`
   fixture with `HOME` the case's home `H` and `KEEL_DENY_FILE=H/broken.txt` holding the broken
   list:
   - `keel scan --leaks origin` exits 2 and prints exactly:

     ```text
     leak guard: deny list loaded from ~/broken.txt (2 patterns)
     leak guard: deny list line 3: not a valid pattern, so it checked nothing
     leak guard: deny list line 5: not a valid pattern, so it checked nothing
     leak guard: refusing to scan: fix the deny list at ~/broken.txt
     ```

   - A branch with one commit whose message names `Quillbank`, pushed as
     `<sha>:refs/heads/topic`: exit 2 and the same four lines, so no finding and no `checked` line.
   - `keel scan --leaks-message` on a file holding `chore: tidy`, a blank line and `QBK follow-up`:
     exit 2 and the same four lines.
   - None of the three outputs holds `Quill(` or `zephyr[`.
   The header comment of the block (lines 2227 and 2228, "Exit 0 with no finding, 1 with any, 2 on
   a usage error or a history that cannot be read.") becomes "Exit 0 with no finding, 1 with any, 2
   on a usage error, a history that cannot be read, or a deny list holding a pattern that is not
   valid." Every existing case of `tests/test-leak-guard.sh` passes, case 15 as behaviour 7 says.
5. **The hooks fail closed with their existing handling, unchanged.** No line of `guard_hook_body`
   or `guard_commit_msg_body` changes. Examples, in a fixture with `keel guard install --leak-guard`
   run and the broken list as `KEEL_DENY_FILE`:
   - `hook_push "$KP" clean` (a branch whose commit names nothing) exits 1; the output holds
     `leak guard: refusing to scan: fix the deny list at ~/broken.txt` and
     `keel guard: push refused by the leak guard.` (line 2958 of `bin/keel`), and not
     `keel guard: scanning before push`, so the supply chain scan never ran.
   - `.git/hooks/pre-push` run by hand with no arguments and empty input, as case "guard 4" does,
     exits 1 with the refusing line: the path a delete-only push takes.
   - A commit with the clean message `feat: clean` through `cm "$KP"` exits 1, `HEAD` is unchanged,
     and the output holds the refusing line and `keel guard: the leak guard is on and the keel on
     PATH cannot check a message, so nothing was checked. Commit refused.` (lines 3092 and 3093).
6. **`keel guard status` says the scans refuse.** In the status block, after the commit-msg check
   and before `elif [ -f "$DENY_FILE" ]; then` (line 3365 of `bin/keel`), an `elif` on
   `${#DENY_INVALID[@]}` above 0 says the fourth Interfaces line with `<n>` that count. Two lines,
   and no loop over the array: the count is all it reads, and `${#a[@]}` of an assigned empty
   array is safe under `set -u`.
   Examples, leak guard on: with the broken list, the output holds
   `leak guard: on, but 2 deny list pattern(s) are not valid, so scans refuse. See 'keel scan
   --leaks-message <file>'`, as one line; with the broken list and `commit-msg` removed, it holds
   the commit-msg line and not `are not valid`; with the three-pattern list, the existing case
   still gives `leak guard: on, deny list loaded (3 patterns)`.
7. **Case 15 counts the validation.** Its expectation (lines 417 and 418 of
   `tests/test-leak-guard.sh`) becomes `12`, with the label `15: two validity checks per loaded
   pattern, one binary test and one grep per pattern, 12 calls, not one per file`: three loaded
   patterns tried twice each at load (the caller's locale and `C`), the binary test, and five
   pattern greps. Example: the case passes, and still fails if a grep runs per file.
8. **`docs/03-install-and-distribution.md` says what is true now.** Four edits, all below line 384:
   - The exit sentence of the `keel scan --leaks` section (lines 390 to 392) becomes: "Exit 0 with
     no finding, 1 with any, and 2 on a usage error, an object that is neither a commit nor a tag,
     a message file that cannot be read, a history walk that fails, or a deny list holding a
     pattern that is not a valid regular expression."
   - After the paragraph that begins "The deny list is one file of patterns" and ends "client names
     are not checked on this machine." (lines 394 to 401), a new paragraph:

     ```text
     A pattern that is not a valid extended regular expression, such as one with a parenthesis left
     open, is refused rather than skipped. grep cannot compile it, so it would match nothing, and
     the scan would print its mode line and no findings while that name went unchecked. The loader
     tries each pattern from the file with `grep -E` over empty input as it reads it, once in the
     caller's locale and once in the C locale `keel scan` greps in, since what compiles can differ
     between them, and leaves out each one that does not compile in either; the count in the mode
     line is of the valid patterns. After the
     mode line the scan prints `leak guard: deny list line <n>: not a valid pattern, so it checked
     nothing` for each, then `leak guard: refusing to scan: fix the deny list at <path>`, and exits
     2 having checked nothing. The pattern itself is never printed: open the file at line `<n>`.
     `tests/no-internal-leaks.sh` prints `FAIL  deny list line <n>: not a valid pattern` for each,
     after its mode line, and exits 1 before it scans.
     ```

   - After the paragraph that begins "Both hooks fail closed." and ends "the hook runs only the
     checks listed above." (lines 898 to 906), a new paragraph:

     ```text
     A deny list holding a pattern that is not valid fails closed as well: `keel scan` exits 2 after
     naming the deny list line to fix, and the `pre-push` hook refuses with `keel guard: push
     refused by the leak guard.`, a push that only deletes a branch included, while the
     `commit-msg` hook refuses with its `nothing was checked. Commit refused.` line.
     ```

   - In the `keel guard status` paragraph (lines 908 to 910), "or on with `commit-msg` missing or
     not keel's." becomes "on with `commit-msg` missing or not keel's, or on with the number of deny
     list patterns that are not valid, so that every scan refuses."
   Example: a case in `tests/test-leak-guard.sh` reads the scan section as behaviour 16's case does
   (the `awk` from `^keel scan --leaks <` to `^keel plan status` over the document) and finds
   `not a valid pattern`, which that section does not hold today; `tests/test-doc-claims.sh` and
   `tests/test-harness-claims.sh` pass.
9. **`CHANGELOG.md`** extends the existing `## Unreleased` entry, since the leak guard it
   describes is itself unreleased: in its clause "and fails closed when it cannot run;" (line 21),
   ", or a deny list pattern is not valid" goes before the semicolon. Lines 21 to 24, the end of
   that paragraph, are rewrapped at 100 columns with the two-space continuation indent, and read
   exactly:

   ```text
     and fails closed when it cannot run, or a deny list pattern is not valid; a `commit-msg` hook
     checks each message, removes `Claude-Session:` trailers and adds a sign-off. Pull requests are
     checked for a DCO `Signed-off-by` line by `tests/check-dco.sh`. `.claude/` is published. See
     `CONTRIBUTING.md` and `SECURITY.md`.
   ```

   Example: `git diff -U0 CHANGELOG.md` shows one hunk, lines 21 to 24 replaced by four lines;
   lines 1 to 20 and 25 to the end are unchanged, so the file's line count is unchanged, and no
   line of the entry is over 100 columns.
10. **No cited line moves.** Every new or changed line of `bin/keel` lies below line 2220: the
    header comment of behaviour 4 (lines 2227 and 2228, which may rewrap to three lines),
    `leak_scan` (from line 2433) and the status block of behaviour 6. Example:
    `sed -n 2174p bin/keel` prints the same line as before the task, `git diff -U0 bin/keel` shows
    hunks only in those three places, and `tests/validate-citations.sh` passes.

**Done when:** `tests/test-no-leaks.sh`, `tests/test-leak-guard.sh` and `tests/no-internal-leaks.sh`
pass, `bash -n bin/keel` exits 0, and `shellcheck -x lib/deny-list.sh tests/no-internal-leaks.sh
tests/test-no-leaks.sh tests/test-leak-guard.sh bin/keel` reports nothing where `shellcheck` is
installed.

- [x] **Step 1.1: Build it test first** Note: tests first: test-no-leaks 33 passed 10 failed and test-leak-guard 174 passed 19 failed before; 43 and 193 after; en_US.UTF-8 cases skip in the cloud (locale not installed)

Follow `keel:tdd` for behaviours 1, 3 to 7 and the document case of behaviour 8: write the cases in
`tests/test-no-leaks.sh` and `tests/test-leak-guard.sh` (the new cases before each file's summary
`printf`, at line 357 and line 688, and the changed expectation of case 15), run them, and watch
them fail; then change `lib/deny-list.sh`, `tests/no-internal-leaks.sh` and `bin/keel`, and watch
them pass. Then behaviours 2, 8 and 9, the text.
Run: `tests/test-no-leaks.sh; tests/test-leak-guard.sh`
Expected before the implementation: FAIL, for the bug's own reason. The loader cases fail because
`DENY_INVALID` is unbound and `DENY_LOADED` is 4 (the `caf[[=é=]]` case fails, or skips where no
UTF-8 locale is installed, for the same reason); the scanner case fails on its output, not its exit,
which is already 1: the mode line says `(4 patterns)` and a `project-specific identifier` finding
for `Quillbank` is printed where the three exact lines are expected, since both broken patterns
make grep exit 2 in silence; the `--list-patterns` case fails because it prints all six patterns,
the two broken ones included (measured while planning); the scan cases exit
1 or 0 with no `not a valid pattern` line (the `Quillbank` commit gives a `deny list line 2`
finding, exit 1); the `pre-push` case exits 0 and the clean commit is made, which is the
fail-open; the status case prints `deny list loaded (4 patterns)`; case 15 counts 6 where it now
expects 12; the document case finds no `not a valid pattern`. Today's counts are 31 passed in
`tests/test-no-leaks.sh` and 169 in `tests/test-leak-guard.sh`. Expected after: PASS, both. Quote
the failing output in your report.

Run: `tests/no-internal-leaks.sh && tests/test-doc-claims.sh && tests/test-harness-claims.sh`
Run: `tests/validate-citations.sh && tests/validate-skills.sh && tests/test-grep-quiet.sh`
Run: `bash -n bin/keel`, then the lint the Done-when line names.
Expected: PASS, and nothing from `shellcheck`. If `tests/validate-citations.sh` reports anything,
stop and report it rather than repair another file. `tests/test-grep-quiet.sh` passing is what
shows the loader's grep is not a pipeline.

Run: `tests/run-tests.sh`, unless the working copy is reached through the remote device shell, as
the global constraints say.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: committed by the coordinator after the spec review (one fix pass: two comment lines rewrapped); rounds: 2; routing: keel-implementer; loop: light; the reviewer built the change independently and confirmed the refusals in a throwaway repository

```bash
git add lib/deny-list.sh tests/no-internal-leaks.sh bin/keel docs/03-install-and-distribution.md \
        CHANGELOG.md tests/test-no-leaks.sh tests/test-leak-guard.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -s -m "fix(scan): refuse to scan when a deny list pattern is not valid"`.
Paste the `git status --porcelain` output into your report; it shows this plan file as untracked
if the coordinator has not committed it yet, which stays unstaged. If it lists anything else this
task did not touch, say so and leave it unstaged.

## Left out on purpose

- The release runbook's Symptoms table (`docs/runbooks/cutting-a-release.md`) gains no row: the
  refusal names its cause and the file, and nothing the runbook says becomes untrue.
- `CONTRIBUTING.md`'s deny list paragraph is unchanged for the same reason.
- No separate command to check the deny list: `keel scan --leaks-message <file>` on any file
  prints the invalid lines, which is what the status line points at.
