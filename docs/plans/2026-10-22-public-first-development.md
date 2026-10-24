# Public-first development Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** develop keel directly in the public repository `gbi-solutions-ltd/keel`, with the
withheld audits in a private companion clone the validators tolerate, a local leak guard on every
push and every commit message, a DCO sign-off check on pull requests, and the two-repository
export retired.
**Stories:** none. The input is the owner's decisions below, relayed by the coordinator on
2026-10-22.
**ADRs:** ADR-0012 (a task carries two steps), ADR-0008 (the implementer is routed to
`keel-implementer`), ADR-0011 (no task edits a skill body or a reference a skill reads, so no
release gate arm is owed for skill text)
**Architecture:** Tasks 1 and 2 are the owner's: a private companion repository for the audits,
then a fresh clone of the public repository as the new working copy, proved identical to v0.26.0
before anything changes, with the audits cloned into an already ignored `docs/audits/`. Tasks 3
and 4 make the withheld paths one list (`tests/withheld.sh`), make the validators skip a path in
it only while it is absent, and retire `tests/export-public.sh` for a fresh-clone check run on a
tracked-files copy. Tasks 5 and 6 build the leak guard: one deny-list loader shared by
`tests/no-internal-leaks.sh` and `bin/keel`, a `keel scan --leaks` that checks every commit a push
carries using the walk `keel scan --push` already makes, and `keel guard install --leak-guard`,
which wires it into the pre-push hook and adds a `commit-msg` hook. Tasks 7 and 8 add the DCO
check and its CI job (the CI edit is the coordinator's: `.github/workflows` is a hard-block path).
Tasks 9 to 11 are the documents and the records. Task 12 is the coordinator's verification. Tasks
13 to 17 are the owner's, in his own terminal: push the first pull request, confirm CI runs,
protect `main` and merge, archive `keel-internal`, then a second pull request and a deliberately
refused push.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** tasks 4 and 5 may run at the same time; task 6 requires task 5. Tasks 6
and 7 may run at the same time; task 8 requires task 7, and task 9 requires tasks 6 and 7. Tasks 9
and 10 may run at the same time; task 11 requires both. Every other task runs alone, in plan order.
Each task in a batch works in its own worktree and its last step commits there; every other
implementer task hands over for the coordinator to commit. `keel plan batches` printed:

```text
batch: 4 5
batch: 6 7
batch: 9 10
why: task 1 has a Files block not in the strict form, so its paths are unknown
why: task 2 has a Files block not in the strict form, so its paths are unknown
why: task 3 depends on task 2
why: task 4 depends on task 3
why: task 6 depends on task 5
why: task 8 edits shared config .github/workflows/ci.yml
why: task 11 depends on task 9 and task 10
why: task 12 has a Files block not in the strict form, so its paths are unknown
why: task 13 depends on task 12
why: task 14 has a Files block not in the strict form, so its paths are unknown
why: task 15 has a Files block not in the strict form, so its paths are unknown
why: task 16 has a Files block not in the strict form, so its paths are unknown
why: task 17 depends on task 16
```

Tasks 1, 14, 15 and 16 change no tracked file. Task 2 commits nothing but leaves three untracked
paths (the two `.claude/` files and this plan) that task 11 adds; task 12 commits only this plan's
ticks. Tasks 1, 2 and 13 to 17 are the owner's; tasks 8 and 12 are the coordinator's.
**Batch gate:** after tasks 4 and 5 land, `tests/run-tests.sh` is green, which includes
`verify.lint`. On the remote device shell, where it cannot finish in 180 seconds, these pass
instead and the full suite runs in task 12: `tests/test-harness-claims.sh`,
`tests/test-leak-guard.sh`, `tests/test-no-leaks.sh`, `tests/no-internal-leaks.sh`,
`tests/test-doc-claims.sh`, `tests/validate-skills.sh`, `tests/validate-citations.sh`,
`tests/test-grep-quiet.sh`, `tests/supply-chain-scan.sh` and `verify.lint` where `shellcheck` is
installed. Task 5 changes `cmd_scan`, so `tests/test-keel.sh` (its `keel scan --push` cases) also
passes here, run as the next line says.
**Batch gate:** after tasks 6 and 7 land, `tests/run-tests.sh` is green; on the device shell,
`tests/test-leak-guard.sh`, `tests/test-check-dco.sh`, `tests/test-doc-claims.sh`,
`tests/test-harness-claims.sh`, `tests/validate-citations.sh`, `tests/test-grep-quiet.sh`,
`tests/supply-chain-scan.sh` and `verify.lint` where `shellcheck` is installed pass, and
`tests/test-keel.sh` passes (task 6 changes the guard output its cases pin).
**Where `tests/test-keel.sh` runs at a join,** since it outlasts the device's 180 seconds: the owner
runs `tests/test-keel.sh` in his own terminal in the working copy, about six minutes, and reports
its last line; or, if the owner prefers, the coordinator runs it in the cloud workspace from a
bundle the owner uploads, as task 12 behaviour 1 describes.
**Batch gate:** after tasks 9 and 10 land, `tests/run-tests.sh` is green; on the device shell,
`tests/test-doc-claims.sh`, `tests/validate-skills.sh`, `tests/validate-citations.sh`,
`tests/test-harness-claims.sh`, `tests/test-eval-harness.sh` and `tests/supply-chain-scan.sh`
pass.

## The owner's decisions

Decided by Bernard and relayed on 2026-10-22. No task reopens them.

1. **Workflow.** Short-lived branches and a pull request into `main`; `main` is always
   releasable. A release is a version-bump pull request (`VERSION`, both `.*-plugin/plugin.json`,
   the `CHANGELOG.md` heading, one commit `release: X.Y.Z`; the two expected red tests before that
   commit still apply), then an annotated tag on the merged commit and a GitHub release, all in the
   one public repository. Commits are no longer squashed to one per release. Branches are public
   while open, so the leak guard is the only preventive control.
2. **Withheld material.** The 27 files under `docs/audits/` live in a new private repository,
   cloned at `docs/audits/` inside the public working copy and ignored by `.gitignore`, so skills
   keep writing audits to the same path. `.keel/handoff.md` is already ignored. `.claude/` is
   decided in this plan (below).
3. **Leak guard.** Local only, plus the release-time sweep; CI stays in generic mode with no deny
   list and no Actions secret. The existing push guard is extended so that, where the deny list
   exists, a push is refused when a pushed commit's files, its message (subject, body, trailers) or
   its author or committer name or email match a deny pattern; a `commit-msg` hook checks the
   message being written, strips any `Claude-Session:` trailer and keeps `Co-Authored-By:` lines.
   The hook prints its mode line on every run and never prints the matched text beyond the file or
   commit and the pattern's index. An absent list is generic mode with a printed warning. Author
   identity is not enforced or changed: commits keep `bernard@gbi-solutions.com`, and the guard
   must not treat that address as a leak. **The leak guard fails closed:** with `keel` missing
   from PATH, or too old to have the scan, the push is refused and `--no-verify` is the deliberate
   way past. This reverses, for the leak guard only, the 2026-09-27 choice to allow a push nothing
   could scan; the supply chain scan keeps that choice.
4. **Citations into withheld documents.** The validators skip a path under `docs/audits/` when
   that directory is absent and check it whenever it is present, from one list both read. Public
   CI is green on a fresh clone with no `docs/audits/`.
5. **keel-internal.** Archived read-only at v0.26.0 and never deleted; nothing new is pushed
   there. Commit SHAs cited before v0.26.0 name private history; one sentence says so where a
   reader will see it, and the citations are not rewritten.
6. **Contributions.** DCO sign-off enforced by a script in this repository run in CI on pull
   requests (the owner's commits included), a `SECURITY.md` saying vulnerabilities are reported
   privately by email to `security@<owner to fill>` and that audits of keel itself stay private
   until their findings are fixed, and no CLA. `CONTRIBUTING.md` states the branch and pull request
   flow, the DCO, the review rule, that an outside contributor cannot merge their own change, and
   the SHA note. The review rule is decision 9 of `docs/07-open-decisions.md` (its section "9. Who
   owns and maintains it"), restated in `docs/standards.md` under "Review" and in the review
   paragraph of `CONTRIBUTING.md`'s "Commits and review": Bernard Tebandeke or `gfsekamanya`
   reviews, either suffices, never the change's own author.

Answered by the owner after review, 2026-10-22: merges are merge commits; `main` needs one
approval with `enforce_admins` on; the `commit-msg` hook adds the sign-off itself; the leak guard
is opted into per repository; the companion repository is private and named by the owner, its
name written in no tracked file; the
ignored-path and root-commit refusals stand; generic patterns are checked everywhere the deny list
is; `tests/export-public.sh` is removed with `git rm`; `CONTRIBUTING.md`'s "No `Co-Authored-By`"
is reversed; `.claude/` is published. The list at the end of this plan records each.

Out of scope: moving the repository to a personal GitHub home (on hold), and any step that pushes,
merges, creates a repository, changes repository settings or deletes anything, except as the
owner's own tasks below.

## What the tree says

Read while planning, against a checkout of the internal repository at v0.26.0. Task 2 proves the
public tree is the same, so these hold in the new working copy.

| Finding | Where |
|---|---|
| The push guard never runs the deny list. `keel scan --push` runs the supply chain scanner only, so client names reach a push unchecked today | `bin/keel#SCANNER="$HERE/tests/supply-chain-scan.sh"`, lines 2080 to 2090 of `bin/keel` |
| The range walk to reuse: every commit reachable from the pushed tip and from no remote-tracking ref of the remote, which covers a rewritten branch and a branch with no upstream. It trusts the remote-tracking refs, so after `git remote set-url` it under-checks, which `docs/03-install-and-distribution.md` already states for key files | line 2175 of `bin/keel`; the paragraph after `keel scan --push <remote> <commit>` in `docs/03-install-and-distribution.md` |
| With no `keel` on PATH the pre-push hook allows the push, a maintainer decision of 2026-09-27 that the leak guard reverses for itself; on the maintainer's machine `keel` on PATH is a symlink into a clone of keel | `bin/keel#keel is not on PATH, so nothing was scanned`; `docs/plans/2026-09-27-push-scan-reads-pushed-commits.md`, the decisions table |
| Today `keel scan` hands any argument it does not know to the supply chain scanner, which ignores it and scans: an older `keel` answers `keel scan --leaks-message <file>` with a clean exit, so a hook may only trust a `keel` whose `--help` names the mode | `cmd_scan` in `bin/keel` |
| A plain `keel guard install` refuses when another tool's `pre-push`, `pre-commit` or `prepare-commit-msg` is present, and writes no `commit-msg` | `guard_foreign_hook` and `cmd_guard` in `bin/keel` |
| `tests/no-internal-leaks.sh` prints each matched pattern and up to 70 characters of the matched line, which is right for CI and the release sweep and wrong for anything that could be pasted into a public pull request | the two `report` calls inside its `DENY` loop |
| The scanner's org-name rules (`\bGBi`, and `gbi` in the two JSON templates) are not deny patterns, so applying deny patterns only to messages and identities cannot flag `bernard@gbi-solutions.com` | `tests/no-internal-leaks.sh`, the `GBI_CANDIDATES` and template blocks |
| The export's only consumer is `tests/test-harness-claims.sh`, lines 342 to 377, which also runs `tests/validate-citations.sh` inside the export | `git grep -n export-public.sh -- tests bin lib hooks .github` |
| The validators resolve against the disk: `validate-skills.sh` in three link loops (lines 172, 204 and 288), `validate-citations.sh` in the missing-file branch (line 145). On a tracked-files copy with no `docs/audits/` both pass today (1,757 citations, 25 skills, measured while planning), so the skip is preventive | `tests/validate-skills.sh`, `tests/validate-citations.sh` |
| 59 tracked files outside `docs/audits/` mention `docs/audits`; 33 name a dated audit file | `git grep -l docs/audits -- . ':!docs/audits'` |
| Both validators also read the audits as citing documents when the clone is present: the audits hold 147 line citations into this tree (`bin/keel`, `tests/no-internal-leaks.sh`, `docs/03-install-and-distribution.md` among them), which go stale as the public tree moves | `find docs ...` in both validators; `git grep` over `docs/audits` |
| `tests/test-no-leaks.sh` holds three literal developer home-path samples (its lines 154, 207 and 253). The scanner skips that file by name; a push scan reading every changed file would not, and `docs/standards.md` ("An exception to a scanner is written on the line") rules out a skip list | `tests/test-no-leaks.sh`; `skip_file` in `tests/no-internal-leaks.sh` |
| A comment in `tests/test-harness-claims.sh` names `tests/export-public.sh` outside the export block (line 420 of that file) | `git grep -n export-public tests/test-harness-claims.sh` |
| CI also builds `sandbox` on push, by a comment dated 2026-10-17 | lines 4 to 8 of `.github/workflows/ci.yml` |
| No skill, agent, template, output style, hook or `lib/` file names `sandbox`, `keel-internal` or the public export; the word "export" in skills is the APEX export | `grep -rnE 'sandbox|keel-internal|export-public' skills agents templates output-styles hooks lib bin` |
| `CONTRIBUTING.md` says "No `Co-Authored-By`", which decision 3 contradicts, and a mandatory `Signed-off-by:` is a footer under `conventions.no_attribution_footers`' own description | line 152 of `CONTRIBUTING.md`; the `prepare-commit-msg` hook body in `bin/keel` |
| `.claude/settings.json` and `.claude/keel-nudge` are what `keel init` writes into every project: plugin names, permission deny and ask lists, and the plugin-less nudge. They carry no identifier, the internal suite and both scanners pass with them tracked, and `docs/06-repo-layout.md` already lists them | `git ls-tree HEAD .claude/` |
| `tests/test-eval-harness.sh` greps the release runbook for `all <n> concurrently` and cites its "Symptoms" section | `tests/test-eval-harness.sh#the release runbook dispatches the pinned count` |
| `git push --dry-run` runs the pre-push hook (git 2.43, measured while planning), so the refused push of task 17 sends nothing either way | a scratch repository |
| A `commit-msg` hook sees comment lines, and a message given with `-F` keeps a `#` line in the commit; `git commit --amend --no-edit` runs `commit-msg` again (measured) | a scratch repository |

**`.claude/` is published,** because both files are generic `keel init` output carrying no
identifier, as the row above says; only `docs/audits/` is withheld.

## Risks, and where each is covered

1. **Any push is public at once, and the guard is local and advisory.** `git push --no-verify`
   skips it, and nothing on GitHub runs it: pull request titles and bodies, review comments,
   release notes and merge commits made on GitHub are never seen by a hook. Where the residual risk
   sits: cloud sessions never push (no implementer or coordinator task pushes); a machine without
   the deny list runs the generic patterns and says so on every push; a machine with the leak guard
   on and no usable `keel` refuses the push (task 6); a clone where the guard is not installed has
   no local check at all, and CI's generic mode only catches developer paths. Tasks 5, 6, 13 and 17.
2. **The new working copy must start from exactly v0.26.0.** Task 2 compares the public tree with
   the internal v0.26.0 tree minus the withheld paths, blob by blob, before any change.
3. **`docs/audits/` must be ignored before anything is cloned into it.** Task 2 writes it to
   `.git/info/exclude` before the clone and checks `git status`; task 3 commits the `.gitignore`
   entry in the first commit and a test pins it; task 5 refuses a push that adds an ignored path,
   which is what a force-added audit would be.
4. **A rewritten range, and a new branch with no upstream.** Task 5 extends the walk of
   `keel scan --push` rather than writing another, with a case for each. The walk trusts
   remote-tracking refs, so task 5 also refuses a range holding a root commit (an unrelated history
   joined to this one), and task 16 stops the old checkout from pushing anywhere.
5. **The `keel` on the owner's PATH points into the old checkout,** which has no leak guard, and
   it serves every repository on his machine. Task 2 repoints it at a second clone of the public
   repository, `$STABLE`, which only ever holds `main`: the machine-wide `keel` never runs a
   development branch. In-progress hooks run only inside the working copy, through an explicit
   `PATH="$NEW/bin:$PATH"` (task 13), until the first merge brings the leak guard to `main` and
   task 15 updates `$STABLE`.
6. **An agent session's `keel` may predate the leak guard.** Claude Code puts the installed
   plugin's `bin/` on the session's PATH, and the installed plugin is v0.26.0 until a release
   carries this change. Once the leak guard is armed, a commit or push from such a session in this
   repository is refused (fail closed) until the plugin is updated or the session's PATH puts
   `$STABLE/bin` first. Accepted, and named in the list at the end.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` over the files `verify.lint` names. `verify.test_affected` is null.
- Every implementer task runs in the new working copy task 2 creates, on the branch
  `public-first`, never on `main`. Where that copy is reached through the remote device shell, each
  call is a fresh shell stopped at 180 seconds: run the task's Done-when commands there and leave
  `tests/run-tests.sh` (which runs `tests/test-keel.sh`, longer than that) to task 12. Where it is
  not, the boundary run is `tests/run-tests.sh`.
- Shell runs on bash 3.2 (macOS `/bin/bash`) and on bash 5: no `${var,,}`, `${var^^}`, `mapfile`,
  `readarray`, `declare -A`, `[[ -v name ]]`, `local -n`, `realpath` or `readlink -f`. An array that
  can be empty expands under `set -u` as `${a[@]+"${a[@]}"}`. No `sed -i`: BSD sed needs a suffix
  and GNU sed refuses one, so a file is rewritten through a temporary file. Generated hook bodies
  obey the same rules, because they run under whatever `bash` the owner's PATH finds.
- `shellcheck -x` runs at default severity, so an info finding fails the lint. A generated hook is
  linted with `shellcheck -s bash` by its test, the way `tests/test-keel.sh` lints the pre-push.
- A test file holding a quiet grep pipeline loads the shim on its `set -uo pipefail` line, exactly
  `set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"`, and `lib/` and `bin/` hold
  no quiet grep pipeline at all: `tests/test-grep-quiet.sh` enforces both.
- `docs/standards.md`: no em or en dashes anywhere, fenced blocks included; prose lines at most 100
  columns; no `@` links; relative links resolve. No task edits `docs/standards.md`: other documents
  cite its line numbers.
- **Citations.** `tests/validate-citations.sh` fails a citation that lands on a blank line or past
  the end of its file. These files are cited by line elsewhere, so they are edited without moving
  a cited line: `tests/validate-skills.sh` and `tests/validate-citations.sh` keep their line counts
  (every change is to an existing line); `tests/test-harness-claims.sh` keeps lines 342 to 377 at
  36 lines; `.github/workflows/ci.yml` keeps lines 1 to 117 at their count and grows only at the
  end; lines 1 to 52 of `CONTRIBUTING.md` and the line count of `README.md` above line 233 are
  unchanged; `.gitignore` grows only at its end; `docs/runbooks/going-public.md` keeps lines 1 to
  129 at their count; `tests/run-tests.sh` keeps its line count (new `add` calls join an existing
  line). **`bin/keel` grows only below its scan walk:** the last line of it any document cites is
  line 2174, so every new line of `bin/keel` goes after line 2180 (the `rev-list` walk of
  `scan_push`), and above it only existing lines change in place (the `_need` list and the first
  line of `cmd_scan`). Adding two source lines beside the other `lib/` sources near the top was
  measured by the plan's reviewer to leave 14 citations stale across 8 files; the placement above
  was measured while planning to leave all 1,986 passing, together with this plan's insertions in
  `docs/03-install-and-distribution.md`, `docs/06-repo-layout.md`, `CHANGELOG.md` and
  `CONTRIBUTING.md`. **Every task runs `tests/validate-citations.sh` before its last step, and a
  report from it stops the task:** the task does not repair another file's citation, because its
  staging list names only its own files and a repair there would go uncommitted (in a batch, it
  would turn the gate red). The report names each stale citation, and the coordinator adds a task
  for it. Write any line reference in prose as "line N of `file`", never in the citation form.
- **No literal developer home path in anything committed**, tests, documents and this plan's tick
  notes alike: the leak guard's generic patterns would refuse the push. Output quoted in a document
  or a `--note` writes the home directory as `<home>` or `~`, as task 2 behaviour 4 does.
- A test file that makes commits or runs a hook isolates git configuration itself, because only
  `tests/run-tests.sh` does and the device gates run test files directly: it exports
  `GIT_CONFIG_SYSTEM=/dev/null` and a `GIT_CONFIG_GLOBAL` pointing at a file it writes (with
  `user.name`, `user.email` and `commit.gpgsign = false`), unsets `GIT_CONFIG_COUNT` and any
  `GIT_CONFIG_KEY_*` and `GIT_CONFIG_VALUE_*`, and every leak-guard case sets `KEEL_DENY_FILE` and
  `HOME` explicitly, so the owner's real list and identity never reach a test.
- `keel guard install --leak-guard` is run only in the main working copy, never inside a batch
  worktree: worktrees share `.git/hooks`, so an install there replaces the hooks of every
  worktree at once.
- Tests use invented identifiers only, never a real client, partner, repository or schema name:
  `Quillbank`, `zephyr-ledger`, `QBK` and the like. A sample of a generic pattern (a developer home
  path) is assembled from pieces in the test, `"/ho""me/someone"`, so `tests/no-internal-leaks.sh`
  never reports the test file itself. A deny list a test writes lives outside the fixture tree, as
  `tests/test-no-leaks.sh` explains.
- Nothing the leak guard prints contains the text a pattern matched, the pattern itself, a commit
  subject, or a path or ref name that itself matches a pattern.
- `hard_block_paths` are `hooks`, `lib/harness`, `settings.json`, `.github/workflows`,
  `templates/ci-review.yml` and `lib/context_watch.py`. Only task 8 touches one
  (`.github/workflows/ci.yml`), and it is the coordinator's, so the implementer routing stays
  `keel-implementer`. The generated hooks live in `bin/keel`, not under `hooks/`.
- No task edits anything under `skills/`, `agents/`, `templates/` or `output-styles/`, so no
  release gate arm is owed by this plan.
- **Records, and one stated departure.** `docs/standards.md` ("Documentation lands with the change")
  and `CONTRIBUTING.md` ask a task run alone to write its `CHANGELOG.md` and `README.md` changes in
  its own commit. Here tasks 3 and 8 run alone and still leave both to task 11, because every task
  lands in the same first pull request and the entry describes one change made across eleven
  tasks: per-task entries would be fragments of one sentence. The pull request carries the records
  either way, which is what the rule protects.
- Documents state the current state; history goes to `CHANGELOG.md` (`docs/standards.md`, "Shipped
  prose states the current state"). The one exception is `docs/runbooks/going-public.md`, which is
  itself an executed record and says so in its first lines.
- Exact text given in a task is used exactly, rewrapped to 100 columns where it replaces wrapped
  prose. If a text this plan says to replace is not found exactly once, stop and report.
- Do not edit this plan file, other than ticking it.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Implementers stage
  and never commit, except a task in a declared concurrent batch, which commits inside its own
  worktree as its last step says; the coordinator commits everything else after both review
  passes. Every commit is made with `git commit -s`, so it carries the sign-off task 7's check
  requires.
- No implementer or coordinator task pushes, merges, creates or archives a repository, changes a
  repository setting, or deletes anything outside the tracked tree. The one removal in the tree is
  task 4's `git rm tests/export-public.sh`, a reviewed change in the first pull request.

---

### Task 1: The private companion repository for the audits (owner)

The owner runs this task in his own terminal. It creates a repository, which no agent does.

**Files:** none. This task changes no file in the public repository.

**Depends on:** none

**Behaviours:**

1. A new **private** companion repository, `$COMPANION` below, named by the owner in his
   terminal and in no tracked file, holds the 27 audit files of
   `docs/audits/` at v0.26.0 at its root, on a branch `main`. Its URL is never written into a
   tracked file of the public repository: a submodule would publish the URL, which
   `docs/runbooks/going-public.md` section 2 rules out. Example: the check below prints `private`
   and `27`.
2. **Option A, keeping the audits' history**, on a throwaway clone (needs `git filter-repo`). The
   rewritten history keeps the original commit messages, two of which name a client: acceptable in
   a private repository, and the reason this repository must never be made public.

   `INTERNAL` and `AUDITS` are the SSH URLs you use for `gbi-solutions-ltd/keel-internal` and for
   the new companion repository, in the form your machine's SSH configuration expects, and
   `COMPANION` is the companion repository's `owner/name`.

   ```bash
   INTERNAL=<the SSH URL of gbi-solutions-ltd/keel-internal>
   COMPANION=<owner/name of the companion repository>
   AUDITS=<the SSH URL of the companion repository>
   git clone "$INTERNAL" "$TMPDIR/audits-seed"
   cd "$TMPDIR/audits-seed"
   git switch main && git describe --exact-match HEAD          # v0.26.0
   git filter-repo --subdirectory-filter docs/audits
   git ls-files | wc -l                                         # 27
   gh repo create "$COMPANION" --private
   git remote add origin "$AUDITS"
   git push -u origin main
   ```

3. **Option B, the fallback**, a plain copy with one commit:

   ```bash
   OLD=<the path of your keel-internal checkout>
   COMPANION=<owner/name of the companion repository>
   AUDITS=<the SSH URL of the companion repository>
   mkdir "$TMPDIR/audits-seed" && cd "$TMPDIR/audits-seed" && git init -q -b main
   git -C "$OLD" archive v0.26.0 docs/audits | tar -x --strip-components=2
   ls ./*.md | wc -l                                            # 27
   git add -- ./*.md
   git commit -s -m "audits: the 27 audits of keel-internal at v0.26.0"
   gh repo create "$COMPANION" --private --source . --remote origin --push
   ```

4. The check, whichever option ran:

   ```bash
   gh api "repos/$COMPANION" -q .visibility    # private
   git ls-remote --heads "$AUDITS" main
   ```

**Done when:** there is no command in the profile for this. The check in behaviour 4 prints
`private` and a `refs/heads/main` line.

- [x] **Step 1.1: There is no test for this** Note: owner task; witnessed: keel-audits-repo is private (signed-out API 404) and holds 27 audit files on main (browser read 2026-10-24); did not witness the commands run

This task is the owner's: run option A or option B, then behaviour 4, in your own terminal.

- [x] **Step 1.2: Hand over** Note: owner reported seeding the repo (option B); witnessed the 27 files and private visibility, not the push output

Nothing is staged. Report which option ran and the two outputs of behaviour 4.

---

### Task 2: The new working copy, a fresh clone proved identical to v0.26.0 (owner)

The owner runs this task in his own terminal. Every later task works in the copy it makes.

**Files:** none. This task commits nothing; it leaves three untracked paths for task 11.

**Depends on:** task 1

**Behaviours:**

1. Set the paths and URLs once; every command below uses them. `PUBLIC` and `AUDITS` are the SSH
   URLs you use for `gbi-solutions-ltd/keel` and for the companion repository.

   ```bash
   OLD=<the path of your keel-internal checkout>
   NEW=<a new path for the public working copy, which must not exist yet>
   STABLE=<a second new path, for a clone of the public repository that only ever holds main>
   PUBLIC=<the SSH URL of gbi-solutions-ltd/keel>
   AUDITS=<the SSH URL of the companion repository>
   git clone "$PUBLIC" "$NEW"
   git clone "$PUBLIC" "$STABLE"
   cd "$NEW"
   git rev-parse --short HEAD                  # a21b3eb
   git describe --exact-match HEAD             # v0.26.0
   ```

2. **The tree is the v0.26.0 export, blob for blob** (risk 2). Stop and report on any difference.

   ```bash
   git -C "$OLD" ls-tree -r v0.26.0 \
     | awk -F'\t' '$2 !~ /^(docs\/audits\/|\.claude\/|\.keel\/handoff\.md$)/' > "$TMPDIR/internal.tree"
   git ls-tree -r v0.26.0 > "$TMPDIR/public.tree"
   diff "$TMPDIR/internal.tree" "$TMPDIR/public.tree" && echo IDENTICAL
   ```

   Expected: `IDENTICAL`.

3. **`docs/audits/` is ignored before anything is cloned into it** (risk 3). The `.gitignore`
   entry is task 3's first commit; until then `.git/info/exclude` holds it.

   ```bash
   printf 'docs/audits/\n' >> .git/info/exclude
   git clone "$AUDITS" docs/audits
   git status --porcelain                      # prints nothing
   git check-ignore -v --no-index docs/audits/x.md   # .git/info/exclude:<n>:docs/audits/ ...
   ls docs/audits/*.md | wc -l                 # 27
   ```

4. **The deny list is in place.**

   ```bash
   tests/no-internal-leaks.sh
   ```

   Expected, with the home directory shown here as `<home>` and `<N>` the number of patterns the
   owner's list holds (not written into this public plan):

   ```text
   mode  internal deny list loaded from <home>/.config/keel/internal-deny-list.txt (<N> patterns)
   OK    no project-specific identifiers
   ```

5. **The machine-wide `keel` is the stable clone's** (risk 5). The pre-push hook runs the `keel`
   on PATH, and on this machine that is a symlink into a clone of keel. It is pointed at `$STABLE`,
   which only ever holds `main`, so no repository on this machine is ever checked by a development
   branch; in-progress hooks run only inside `$NEW`, by an explicit `PATH="$NEW/bin:$PATH"`
   (task 13).

   ```bash
   k="$(command -v keel)"
   if [ -z "$k" ]; then
       echo "no keel on PATH: put a symlink to $STABLE/bin/keel in a directory on PATH, then rerun"
   elif [ -L "$k" ]; then
       ln -sfn "$STABLE/bin/keel" "$k" && ls -l "$k"     # -> $STABLE/bin/keel
   else
       echo "$k is a real file, not a symlink: leave it, and put a symlink to $STABLE/bin/keel"
       echo "in a directory earlier on PATH, then rerun"
   fi
   keel version                                         # 0.26.0
   ```

   The `ln` runs only on a symlink, so a real file, or a plugin cache's own `bin/keel`, is never
   overwritten. Report which branch ran.

6. **The identity is the old checkout's.** Commits keep `bernard@gbi-solutions.com`.

   ```bash
   git -C "$OLD" config --local --get-regexp '^(user|commit|gpg|tag)\.'
   ```

   Set each line it prints here with `git config <key> <value>`, then:

   ```bash
   git config user.email                       # bernard@gbi-solutions.com
   ```

7. **The v0.26.0 guard is installed, and the work branch exists.**

   ```bash
   keel guard install
   keel guard status                           # push guard: active
   git switch -c public-first
   ```

8. **Three untracked paths for task 11:** this plan file, which the coordinator hands over, copied
   to `docs/plans/2026-10-22-public-first-development.md`; and the two `.claude/` files, taken from
   v0.26.0 of the old checkout.

   ```bash
   mkdir -p .claude
   git -C "$OLD" show v0.26.0:.claude/settings.json > .claude/settings.json
   git -C "$OLD" show v0.26.0:.claude/keel-nudge > .claude/keel-nudge && chmod +x .claude/keel-nudge
   git hash-object .claude/settings.json .claude/keel-nudge
   git status --porcelain
   ```

   Expected: the two ids `d9bc11d10332077dd9c698931cd7f72d85eff4a8` and
   `7a96c3285ba442f3c7fde7ab3a979d25ed30b4a5` (the blobs of the tree this plan was written
   against), and `git status --porcelain` printing exactly `?? .claude/` and
   `?? docs/plans/2026-10-22-public-first-development.md`.

9. **The old release scripts stay where they are.** `.git/keel-release/` in the old checkout holds
   `land.sh` and `publish.sh`, written for the export model; they are obsolete, nothing is copied
   from them, and nothing deletes them. The release procedure becomes the runbook of task 10, and
   nothing from it lives in the private companion repository, which holds the audits only.
   Example: `ls "$OLD/.git/keel-release"` still lists `land.sh` and `publish.sh`, and
   `ls "$NEW/.git/keel-release"` reports no such directory.

**Done when:** there is no command in the profile for this. Behaviour 2 prints `IDENTICAL`,
behaviour 3's `git status --porcelain` prints nothing, behaviour 4 prints the owner's pattern
count and `OK`, and
behaviour 8 prints the two ids and the two untracked paths.

- [x] **Step 2.1: There is no test for this** Note: owner task; witnessed on the device: behaviour 2 IDENTICAL (564 files each), behaviour 6 identity, behaviour 8 hashes d9bc11d and 7a96c32 and the two untracked paths. Behaviours 3, 4, 5, 7 are the owner reported outputs (status clean bar the two paths, 27 audits, mode line 25 patterns plus OK, keel symlink to keel-stable, guard install, branch public-first, which I saw exists)

This task is the owner's: run behaviours 1 to 8 in order in your own terminal, and stop at the
first output that differs from the one given.

- [x] **Step 2.2: Hand over** Note: owner reported the outputs of behaviours 3 to 7; I did behaviours 6 and 8 myself on the device

Nothing is staged. Report each behaviour's output, with the home directory in behaviour 4's mode
line elided as `<home>`.

---

### Task 3: One list of withheld paths, and validators that skip one only while it is absent

**Files:**
- Create: `tests/withheld.sh` and `tests/test-withheld.sh`
- Modify: `.gitignore`, `tests/run-tests.sh`, `tests/validate-skills.sh`,
  `tests/validate-citations.sh`, `tests/test-validate-skills.sh` and
  `tests/test-validate-citations.sh`

**Interfaces:**
- Produces: `tests/withheld.sh`, sourced and never run, not executable, first line
  `#!/usr/bin/env bash`. It holds the one list, `_wh_paths=( docs/audits )`, and three functions:
  - `withheld_list` prints each listed path, one per line.
  - `withheld_under <path>` returns 0 when `<path>`, normalised, equals a listed path or lies
    under one, whether or not it exists; otherwise 1.
  - `withheld_skip <path>` returns 0 when `withheld_under <path>` does and that listed path does
    not exist relative to the current directory; otherwise 1. Every caller runs from the
    repository root.
- Produces: the form both validators load it with, replacing their existing `set -uo pipefail`
  line (line 15 of `tests/validate-skills.sh`, line 55 of `tests/validate-citations.sh`):

```bash
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/withheld.sh"
```

- Produces: `.gitignore` ends with a comment line and the line `docs/audits/`.

**Depends on:** task 2

**Behaviours:**

1. Normalisation and the skip, run in a directory with no `docs/audits`: `withheld_skip` returns 0
   for `docs/audits/2026-01-01-security.md`, `docs/plans/../audits/x.md`,
   `skills/a/../../docs/audits/x.md`, `./docs/audits/x.md`, `docs/audits` and `docs/audits/`; and
   1 for `docs/auditsx/y.md`, `docs/plans/x.md` and `../docs/audits/x.md`, which climbs out of the
   repository. With an empty directory `docs/audits` present, it returns 1 for
   `docs/audits/x.md`. Normalisation drops `.` segments and empty segments and folds `seg/..`, in
   shell, without `realpath`, so it never needs the path to exist.
2. Every variable the file names starts with `_wh_`, because `shellcheck -x` follows the source
   into both validators and does not scope a function's locals, as the grep shim found with its
   `_gq_` prefix. It holds no quiet grep pipeline. Example: `shellcheck -x` on both validators
   reports nothing.
3. The withheld path is ignored by the committed `.gitignore` and nothing is tracked under it.
   `tests/test-withheld.sh` asserts, for each path `withheld_list` prints, that
   `git check-ignore -v --no-index "<path>/x.md"` names `.gitignore` as its source (git reports the
   `.gitignore` entry when `.git/info/exclude` holds the same pattern, measured while planning), and
   that `git ls-files -- "<path>"` prints nothing. Example: on the tree, both hold; with the
   `.gitignore` line removed, the first fails even though task 2's `.git/info/exclude` still
   ignores the directory, because a contributor's clone has no such exclude.
4. The three link loops of `tests/validate-skills.sh` skip a withheld target while it is absent and
   check it while it is present. Each of lines 172, 204 and 288 becomes
   `[ -e "<same path>" ] || withheld_skip "<same path>" || report ...`, on the same line. Examples,
   as fixture trees run through the real validator from their root:
   - `docs/runbooks/r.md` holding the link `[a](../audits/2026-01-01-security.md)` and no
     `docs/audits`: exit 0. The same with an empty `docs/audits/`: exit 1, `broken link`. The same
     with that file present: exit 0.
   - `skills/example/SKILL.md` linking `../../docs/audits/x.md`, and a reference file under
     `skills/example/references/` linking `../../../docs/audits/x.md`, with no `docs/audits`: no
     broken-link report for either.
5. `tests/validate-citations.sh` skips a missing cited file only when it is withheld and absent.
   The `if [ "$has_ext" -eq 1 ] ...` line (line 145) gains `&& ! withheld_skip "$path" && !
   withheld_skip "$dir/$path"` on the same line. Examples, as fixture trees, with the citing
   document `docs/plans/p.md` holding each line below outside any fence:

   ```text
   See `docs/audits/a.md:3`.
   See `../audits/a.md:3`.
   ```

   With no `docs/audits`: exit 0 for each. With `docs/audits/` present and no `a.md`: exit 1, the
   message naming `does not exist`. With `docs/audits/a.md` of five non-blank lines: exit 0; of two
   lines: exit 1, naming `is 2 lines long`. A citation, in the citation form, of line 3 of a
   `docs/plans/missing.md` that does not exist still fails with no `docs/audits` present. The
   phrase form has its own missing-file branch further down the file (the
   `if [ "$seg" != "$path" ] && [ -d "$seg" ]; then` line in the loop over phrase citations), and
   it gains the same two checks on the same line. Examples, the citing line being:

   ```text
   See `docs/audits/a.md#some text`.
   ```

   with no `docs/audits`: exit 0; with `docs/audits/` present and no `a.md`: exit 1, naming
   `does not exist`.
6. **A withheld document is never a citing document of the public checks,** present or not. The
   private audits are dated records holding 147 line citations into this tree, which go stale as it
   moves; checking them would turn the owner's local run red on files the public never sees, and
   would make a public change wait on a private repository. So `tests/validate-citations.sh` leaves
   out of its documents every file `withheld_under` names (the `[ -n "$f" ] && files+=("$f")`
   line gains `&& ! withheld_under "$f"` before the append), and the docs loop of
   `tests/validate-skills.sh` does the same for its dash and link checks (its `[ -f "$f" ] ||
   continue` line, line 279, becomes `{ [ -f "$f" ] && ! withheld_under "$f"; } || continue`).
   The audits get no check of their own: they are records, whose line numbers say when they were
   written, as the records list in `tests/validate-citations.sh` already treats `docs/audits/*`.
   Example, as a fixture with `docs/audits/a.md` present and holding, outside any fence, a
   citation of line 99999 of a two-line `docs/b.md` and an em dash: both validators exit 0; the
   same text in `docs/plans/p.md` makes each exit 1.
7. `tests/validate-skills.sh` and `tests/validate-citations.sh` keep their line counts. Example:
   `wc -l` on each prints what it printed before the task.
8. The new cases go at the end of `tests/test-validate-skills.sh` and
   `tests/test-validate-citations.sh`, before each file's summary `printf`, past every cited line.
   `tests/test-withheld.sh` is in the house shape (executable, a header comment saying why the list
   exists and what it replaced, `ok` and `bad` helpers that return 0, a last line
   `<n> passed, <m> failed`, non-zero on any failure), and `tests/run-tests.sh` runs it: the call
   `add "tests/test-withheld.sh" "tests/test-withheld.sh"` is appended, after `; `, to the existing
   line `add "tests/test-grep-quiet.sh" "tests/test-grep-quiet.sh"`, so no line of
   `tests/run-tests.sh` moves (its lines 54 to 56 and 94 are cited, and two inserted lines would
   put the second citation on a blank line, measured while planning). Example:
   `grep -c test-withheld.sh tests/run-tests.sh` prints `1` and `wc -l tests/run-tests.sh` is
   unchanged.
9. `.gitignore` gains, at its end, a comment saying the directory is a clone of a private
   repository holding the audits, and the line `docs/audits/`. Example: `tail -1 .gitignore`
   prints `docs/audits/`.

**Done when:** `tests/test-withheld.sh`, `tests/test-validate-skills.sh`,
`tests/test-validate-citations.sh`, `tests/validate-skills.sh` and `tests/validate-citations.sh`
pass, and `shellcheck -x tests/withheld.sh tests/test-withheld.sh tests/validate-skills.sh
tests/validate-citations.sh` reports nothing where `shellcheck` is installed.

- [x] **Step 3.1: Build it test first** Note: red witnessed in the report (7 cases failing for the named reason, tests/withheld.sh missing); present-directory cases passed on arrival, as the task expects; boundary tests/run-tests.sh not run by the implementer, run by the coordinator after the commit

Follow `keel:tdd` for behaviours 1, 3, 4, 5 and 6: write `tests/test-withheld.sh` and the new
fixture cases, run them, and watch them fail, then write `tests/withheld.sh`, the `.gitignore` lines
and the in-place validator changes, and watch them pass.
Run: `tests/test-withheld.sh && tests/test-validate-skills.sh && tests/test-validate-citations.sh`
Expected before the implementation: FAIL. `tests/test-withheld.sh` reports that
`tests/withheld.sh` does not exist; the absent-directory cases of behaviours 4 and 5 fail because
the validators report the withheld target as broken or missing; behaviour 6's case fails because
both validators report the audit's stale citation and dash; the present-directory cases pass,
which is right: they pin that a present clone is still checked. Expected after: PASS. Quote the
failing output in your report.

Run: `git add -N tests/withheld.sh tests/test-withheld.sh`, then
`tests/validate-skills.sh && tests/validate-citations.sh && tests/test-grep-quiet.sh`, then the
boundary run the global constraints name.
Expected: PASS, or reds this task did not cause, each named.

- [x] **Step 3.2: Hand over** Note: rounds: 1; routing: keel-implementer; loop: light

```bash
git add tests/withheld.sh tests/test-withheld.sh .gitignore tests/run-tests.sh \
        tests/validate-skills.sh tests/validate-citations.sh tests/test-validate-skills.sh \
        tests/test-validate-citations.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -s -m "test: one list of withheld paths, skipped by the validators only while absent"`.
Paste the `git status --porcelain` output into your report; it also shows task 2's untracked
`.claude/` and plan file, which stay unstaged until task 11. If it lists anything else this task
did not touch, say so and leave it unstaged.

---

### Task 4: Retire the export; the fresh-clone check runs on a tracked-files copy

**Files:**
- Delete: `tests/export-public.sh`
- Modify: `tests/test-harness-claims.sh` and `docs/ideas/links-into-export-excluded-paths.md`

**Interfaces:**
- Consumes: `withheld_list` from `tests/withheld.sh`, task 3.

**Depends on:** task 3

**Behaviours:**

1. **Why retire rather than reduce.** Nothing exports any more: the public repository is the tree.
   The script's exclusion list moved to `tests/withheld.sh` and `.gitignore`, and its one consumer
   needs only a copy of the tracked files, which is the six-line loop the script already held.
   Keeping a script named for a step that no longer exists invites someone to run the old
   procedure. `git rm tests/export-public.sh`. The comment in `tests/test-harness-claims.sh` that
   still names it, outside the block (the sentence starting "tests/export-public.sh publishes",
   lines 420 and 421 of that file), is rewritten on the same two lines to say the public repository
   is the tracked tree, so an untracked agent definition ships to nobody. Example:
   `git grep -n export-public.sh -- tests bin lib hooks .github` prints nothing.
2. In `tests/test-harness-claims.sh`, lines 342 to 377 (from the comment beginning
   `# ...and both manifests actually ship.` to `rm -rf "$xd"`) become a block of exactly 36 lines,
   so the lines after it do not move. It loads the list with these two lines, the form the file
   already uses for `lib/harness/resolve.sh` under its `# shellcheck source-path=SCRIPTDIR/..`
   directive (lines 122 to 124 of the file; it runs from the repository root):

   ```bash
   # shellcheck source=tests/withheld.sh
   . tests/withheld.sh
   ```

   It asserts:
   - `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `hooks/hooks.json`,
     `hooks/hooks.codex.json` and `skills/keel/SKILL.md` are tracked (`git ls-files
     --error-unmatch`), in a case named "both plugin manifests and both hook manifests are tracked,
     so they ship". Example: passes on the tree; fails naming the path when one is removed from the
     index with `git rm --cached`.
   - A copy of the tracked files, made in a `mktemp -d` directory with the `git ls-files` and
     `cp -p` loop the export used (so a tracked file's working-tree content is what is copied, and
     an untracked file is not), holds no path `withheld_list` prints, and inside it
     `tests/validate-citations.sh` and `tests/validate-skills.sh` both exit 0. Case names: "a fresh
     clone holds no withheld path", "every citation resolves in a fresh clone" and "every relative
     link resolves in a fresh clone". This is public CI's condition, checked on a machine where
     `docs/audits/` is present. Example: passes on the tree; with a scratch document added with
     `git add -N` holding a citation, in the citation form, of line 3 of a `docs/plans/missing.md`
     that does not exist, the citation case fails, and with that document removed it passes again.
3. The comment opening the block says what it replaced and why: the export is gone because the
   public repository is the tree, and running the validators on a tracked-files copy is how a
   machine holding the private clone sees what a fresh clone sees. Example: within lines 342 to
   377, `grep -c 'fresh clone'` counts at least `2` (the comment and a case name) and
   `grep -c 'export-public'` counts `0`; the reviewer reads the comment against this behaviour.
4. `docs/ideas/links-into-export-excluded-paths.md` records the outcome: its table's Status row
   becomes `**solved 2026-10-22** by tests/withheld.sh, which both validators read`, its
   Recommendation and Next rows say nothing is left to do, and a closing section says the third
   option of its own table was taken (a shared file both read), why the drift problem is gone (one
   list, and a test that ties it to `.gitignore`), and that a citation into a withheld path is now
   skipped while the path is absent rather than reported. Its prose citation of lines 42 to 47 of
   the export script is rewritten in a form that is not a citation, for example "the `case` in
   `excluded()` of `tests/export-public.sh`, which was removed on 2026-10-22". Example:
   `tests/validate-citations.sh` passes, and `grep -c 'solved 2026-10-22'` on the file prints `1`.
5. `wc -l tests/test-harness-claims.sh` prints the same number before and after (447 when this plan
   was written).

**Done when:** `tests/test-harness-claims.sh` passes, and `shellcheck -x
tests/test-harness-claims.sh` reports nothing where `shellcheck` is installed.

- [x] **Step 4.1: Build it test first** Note: tests first; old block failed on the retired script, mutation quoted

Follow `keel:tdd`. `git rm tests/export-public.sh` first and run the old block.
Run: `tests/test-harness-claims.sh`
Expected before the implementation: FAIL, the case `tests/export-public.sh runs` reports
`non-zero exit`. Then write the new block and watch it pass, and run behaviour 2's scratch-document
mutation once, quoting its FAIL. Expected after: PASS. Quote both failing outputs in your report.

Run: `tests/test-harness-claims.sh && tests/validate-citations.sh`
Expected: PASS. This task is in a declared concurrent batch with task 5, so the suite runs once at
the join (the header's batch gate) and this task schedules no boundary run.

- [x] **Step 4.2: Commit** Note: e3c3782 (merged as b7bea37); rounds: 1; routing: keel-implementer; loop: light

You are in your own worktree, so this task commits rather than handing over. `git rm` has already
staged the removal of `tests/export-public.sh`.

```bash
git add tests/test-harness-claims.sh docs/ideas/links-into-export-excluded-paths.md
git commit -s -m "test: retire the public export; check a fresh clone from a tracked-files copy"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 5: One deny-list loader, and `keel scan --leaks` for a push and for a message

**Files:**
- Create: `lib/deny-list.sh` and `tests/test-leak-guard.sh`
- Modify: `tests/no-internal-leaks.sh`, `tests/test-no-leaks.sh`, `bin/keel`,
  `tests/run-tests.sh` and `docs/03-install-and-distribution.md`

**Interfaces:**
- Consumes: the walk of `scan_push` in `bin/keel` (line 2175 of `bin/keel`), which this task's
  range reuses rather than restates.
- Produces: `lib/deny-list.sh`, sourced by `tests/no-internal-leaks.sh` on its `set -uo pipefail`
  line and by `bin/keel` from a source line below its scan walk (behaviour 3):

```bash
deny_load    # no arguments; sets the four names below; returns 0
DENY         # array: '/Users/[a-z]' '/home/[a-z]', then each pattern line of the file, in order
DENY_WHERE   # array, same length: 'generic pattern 1' 'generic pattern 2' 'deny list line <n>'...
DENY_FILE    # ${KEEL_DENY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/keel/internal-deny-list.txt}
DENY_LOADED  # how many patterns came from the file; 0 when it is absent
```

  `<n>` is the pattern's line number in the file, comment and blank lines counted, so the owner
  finds a pattern by opening the file at that line.
- Produces: two `keel scan` modes. `keel scan --leaks <remote> [<object>:<ref>]...`, where
  `<object>` is a commit or tag id and `<ref>` the remote ref it is pushed to (a ref name cannot
  hold `:`, so the split is unambiguous); and `keel scan --leaks-message <file>`. Exit 0 with no
  finding, 1 with any, 2 on a usage error, an object that is neither a commit nor a tag, or a
  history walk that fails. Their output lines, exactly:

```text
leak guard: deny list loaded from <path> (<n> patterns)
leak guard: WARNING no deny list at <path>, so only the 2 generic patterns ran. Client names are not checked on this machine.
leak guard: <where>: <which>
leak guard: <sha7> has no parent, so this push carries a history the remote does not have
leak guard: <sha7> <path>: a path this repository ignores
leak guard: <sha7> message line <n>: a Claude-Session trailer
leak guard: checked <c> commit(s), <t> tag(s) and <r> ref name(s), no findings
leak guard: nothing pushed, nothing checked
leak guard: message checked, no findings
leak guard: <n> finding(s)
```

  `<path>` is `DENY_FILE` with a leading `$HOME/` written `~/`. `<which>` is a `DENY_WHERE`
  entry. `<sha7>` is `git rev-parse --short=7`. `<where>` is one of `<sha7> message line <n>`,
  `<sha7> author name`, `<sha7> author email`, `<sha7> committer name`, `<sha7> committer email`,
  `<sha7> <path> line <n>`, `<sha7> a changed path`, `<sha7> a changed path line <n>`,
  `tag <sha7> message line <n>`, `tag <sha7> tagger name`, `tag <sha7> tagger email`,
  `a pushed ref name` and, for `--leaks-message`, `message line <n>`. The first line printed is
  always one of the two mode lines. **Wherever a line would name a path, and that path matches any
  pattern, `a changed path` is printed in its place**, in every line above, the ignored-path line
  included: the output names the pattern's index and never the path. For a message given to
  `--leaks-message`, the trailer line reads `leak guard: message line <n>: a Claude-Session
  trailer`.

**Depends on:** task 2

**Behaviours:**

1. **The loader.** With `KEEL_DENY_FILE` naming this file, written outside any fixture tree:

   ```text
   # invented identifiers for the leak guard's tests

   Quillbank
   zephyr-ledger
   \bQBK\b
   ```

   `deny_load` leaves `DENY` with five entries, `DENY_WHERE` as `generic pattern 1`,
   `generic pattern 2`, `deny list line 3`, `deny list line 4`, `deny list line 5`, and
   `DENY_LOADED` 3. With the file absent: two entries and `DENY_LOADED` 0. A last line with no
   newline is still read. Every name it sets starts with `DENY` or `deny_`. These cases go in
   `tests/test-no-leaks.sh`, after its existing cases, sourcing the loader in a subshell.
2. **`tests/no-internal-leaks.sh` behaves exactly as before.** It loads the list through
   `deny_load` (on its `set -uo pipefail` line, `set -uo pipefail; . "$(dirname
   "${BASH_SOURCE[0]}")/../lib/deny-list.sh"`, which `shellcheck -x` 0.11.0 resolves through
   `.shellcheckrc`, measured while planning) and builds its mode line from `DENY_FILE` and
   `DENY_LOADED` as it does today, so its output is byte for byte what it was. The comment block
   explaining why the list lives outside the tree moves to `lib/deny-list.sh`, with a one-line
   pointer left behind. Example: every existing case of `tests/test-no-leaks.sh` passes unchanged,
   and `KEEL_DENY_FILE=<the file above> tests/no-internal-leaks.sh --list-patterns` prints the
   five patterns, generic first.
2a. **`tests/test-no-leaks.sh` holds no literal developer path any more.** Its three samples (the
   `m_abs_path` line, the line of the coverage sample beginning `Paths like`, and the `awk` line of
   `m_many_hits`) build the home-path prefixes from pieces, `"/Us""ers/someone"` and
   `"/ho""me/someone"`, so the text written into each fixture is byte for byte what it was. The
   scanner's skip of this file by name stays (it still holds the invented client names), but the
   push scan of behaviour 8 reads every changed file and has no skip list, by `docs/standards.md`'s
   rule against one; without this, this task's own change to the file would be refused on the
   first push. Example: `grep -cE '/Users/[a-z]|/home/[a-z]' tests/test-no-leaks.sh` prints `0`,
   and the coverage case still reports every loaded pattern fired.
3. **Where the code goes in `bin/keel`, so no cited line moves** (the global constraint on
   citations). Only two existing lines above the scan walk change, in place: the second line of
   the `_need` list (`lib/harness/resolve.sh lib/harness/claude.sh VERSION; do`) gains
   `lib/deny-list.sh` before `VERSION`, so a copy of the plugin without it fails with
   `incomplete install`; and the first line of `cmd_scan`, `[ -x "$SCANNER" ] || die ...`, is
   prefixed on the same line with `case "${1:-}" in --leaks|--leaks-message) leak_scan "$@";
   return ;; esac;`. Everything new, the `leak_scan` function and its helpers, and the source of
   the loader with a `# shellcheck source=lib/deny-list.sh` line above it, goes in one block placed
   after line 2180 of `bin/keel`, directly before `scan_push_gone`'s comment. Example:
   `grep -c 'lib/deny-list.sh' bin/keel` prints `3`, `sed -n 2174p bin/keel` prints the same line
   as before the task, and `tests/validate-citations.sh` passes.
4. **The mode line comes first, every run.** With `HOME` set to a temporary directory `H` and
   `KEEL_DENY_FILE=H/deny.txt` holding the file above, `keel scan --leaks origin` prints
   `leak guard: deny list loaded from ~/deny.txt (3 patterns)` then
   `leak guard: nothing pushed, nothing checked`, exit 0. With `KEEL_DENY_FILE=H/absent.txt` its
   first line is:

   ```text
   leak guard: WARNING no deny list at ~/absent.txt, so only the 2 generic patterns ran. Client names are not checked on this machine.
   ```
5. **Which commits are checked: the walk `keel scan --push` makes.** Every commit reachable from a
   pushed commit and from no remote-tracking ref of `<remote>`: `git rev-list <commits> --not
   --remotes=<remote>`, with its status checked, since a walk that stops partway would read as a
   clean range. A tag object's own message and tagger are checked and the tag is peeled to its
   commit for the walk. Examples, each in a fixture with a bare remote `origin`, `main` pushed and
   fetched, and the deny file above:
   - A branch with two new commits pushed as `<tip>:refs/heads/topic`: exit 0 and
     `leak guard: checked 2 commit(s), 0 tag(s) and 1 ref name(s), no findings`.
   - **A rewritten branch.** `origin/topic` at commit A; locally A is amended to A' whose message
     names `Quillbank`: A' is checked and reported, `leak guard: <A'> message line 1: deny list
     line 3`, exit 1.
   - **A new branch with no upstream**, made from `origin/main` with one commit: exactly that
     commit is checked (`checked 1 commit(s)`).
   - **A remote with no fetched refs here** (`keel scan --leaks <path-of-the-bare-remote> ...`):
     the whole history is in range, so the root rule of behaviour 11 fires, exit 1.
6. **Messages: every line, subject, body and trailers.** A commit whose message is
   `fix: retry`, a blank line, then `See zephyr-ledger notes` gives
   `leak guard: <sha7> message line 3: deny list line 4`. An annotated tag pushed as
   `<tag id>:refs/tags/v9.9.9` whose message's second line holds `QBK` gives
   `leak guard: tag <sha7> message line 2: deny list line 5`.
7. **Author and committer.** A commit authored `Pat <pat@zephyr-ledger.example>` gives
   `leak guard: <sha7> author email: deny list line 4`, and one committed with that identity
   `committer email`. **The owner's identity is not a leak:** a commit authored and committed
   `Owner <owner@gbi-solutions.com>` with the message `feat: GBi house defaults` gives no finding,
   because the organisation rules of `tests/no-internal-leaks.sh` are not deny patterns and are
   never applied here.
8. **Files a commit in range added, modified or changed in type**, from `git diff-tree -r -c
   --root --no-renames --diff-filter=AMT` over the range (the listing `scan_push` makes, with the
   commit id kept so each finding names its commit). **Binary files are skipped** by the scanner's
   own test, `grep -I`, run once over the whole candidate directory rather than once per file:
   `LC_ALL=C grep -rIl '' <dir>` lists the text files, and only those are searched; a file it does
   not list (binary, or empty) is not. Example: a commit adding `img.bin` holding a NUL byte and
   `Quillbank` gives no finding, which the accepted risks name. A commit adding `docs/n.md` whose
   line 2 is `Quillbank` gives
   `leak guard: <sha7> docs/n.md line 2: deny list line 3`, and still does when a later commit in
   the same range deletes the file. The same file already on `origin/main` gives nothing.
9. **Paths and ref names are checked, and never printed when they match.** A commit adding
   `notes/zephyr-ledger.md` holding `Quillbank` on line 1 gives
   `leak guard: <sha7> a changed path: deny list line 4` and
   `leak guard: <sha7> a changed path line 1: deny list line 3`. A push to
   `refs/heads/fix/zephyr-ledger-timeout` gives `leak guard: a pushed ref name: deny list line 4`.
   In both cases the whole output holds no `zephyr-ledger`.
10. **An ignored path is refused.** With `private/` in the fixture's `.gitignore`, a commit made
    with `git add -f private/n.md` gives `leak guard: <sha7> private/n.md: a path this repository
    ignores`, exit 1. Ignored means what `git check-ignore --no-index` says in this working tree,
    which reads `.gitignore` and `.git/info/exclude`; this is what a force-added audit would be.
    With `private/zephyr-ledger.md` instead, the line reads `leak guard: <sha7> a changed path: a
    path this repository ignores`, beside the path finding, and the output holds no
    `zephyr-ledger`.
10a. **A `Claude-Session:` trailer is refused at push,** whatever made the commit: a cherry-pick,
    a rebase pick, a clone without the hook, or `--no-verify`. A line of a commit message whose
    key is `Claude-Session:` in any case gives `leak guard: <sha7> message line <n>: a
    Claude-Session trailer`, counted as a finding. Example: a commit made with `--no-verify` and
    the message `fix: x`, a blank line, `Claude-Session: https://claude.ai/code/session_example`
    gives that line with `message line 3`, exit 1; `--leaks-message` on a file holding that line
    gives `leak guard: message line 3: a Claude-Session trailer`.
11. **A root commit in range is refused.** A push from a fixture with no fetched refs of the remote
    gives `leak guard: <sha7> has no parent, so this push carries a history the remote does not
    have`, exit 1. The public repository has one root, already pushed, so a second root means an
    unrelated history, the private one included, is being joined to it; and after `git remote
    set-url` the walk trusts refs that describe another repository, which this rule backs up.
12. **Matched text is never printed.** Over the full output of a fixture holding every finding
    above, the output contains none of `Quillbank`, `zephyr-ledger` or `QBK`, none of the three
    patterns, and no commit subject. Generic patterns are covered too: a message holding a
    developer home path (assembled from pieces in the test) gives
    `message line <n>: generic pattern 2` and the output holds no part of that path.
13. **Summary and exit.** Any finding ends the output with `leak guard: <n> finding(s)`, exit 1.
    `keel scan --leaks` with no remote exits 2 with a usage line; an object that is neither a
    commit nor a tag exits 2 naming it as `is not a commit or tag in this repository`.
14. **`keel scan --leaks-message <file>`** checks every line up to, and not including, a scissors
    line (`# ------------------------ >8 ------------------------`), comment lines included,
    because git commits a `#` line under some cleanup modes. A file `chore: tidy`, a blank line,
    `QBK follow-up` gives `leak guard: message line 3: deny list line 5`, exit 1; `QBK` only below
    a scissors line gives `leak guard: message checked, no findings`, exit 0; a missing file exits
    2. It works on any text file, which is how task 10's runbook checks a pull request body and
    release notes before they are posted.
15. **One grep per pattern.** Candidate files (blobs, messages, identity lines) are written to one
    temporary directory, removed however the command ends, and each pattern is one `grep` over
    all of them, as `tests/no-internal-leaks.sh` does after it measured 6,400 processes the other
    way. Example: with the three-pattern deny file and a range of 30 commits each adding 30 files,
    a `grep` wrapper put first on PATH that logs each call records 6 calls: the one binary test of
    behaviour 8 and one per pattern (the two generic patterns and the three loaded ones), not one
    per file. No timing bound is asserted: a wall
    clock under four parallel jobs and on a macOS runner would make the case flaky.
16. **Help and docs.** `keel --help` gains the lines
    `  scan --leaks <remote> [<object>:<ref>]...   check what a push carries against the deny list`
    and `  scan --leaks-message <file>   check a message or any text file against the deny list`,
    with the `scan --push` line unchanged. `docs/03-install-and-distribution.md` gains a section
    after the `keel scan --push` paragraph describing both modes: what is checked, the walk and its
    trust in remote-tracking refs, the root and ignored-path rules, the `Claude-Session` rule,
    that nothing matched is printed (nor a path that matches), generic mode, binary files being
    skipped, and the exit codes. It says plainly that the root rule makes a first push to an empty
    repository, or a push to a remote named by URL, need `git push --no-verify`. Example:
    `tests/test-doc-claims.sh` and `tests/test-harness-claims.sh` pass, and
    `grep -c 'no-verify'` on the new section counts at least `1`.
17. **`tests/test-leak-guard.sh`** is in the house shape, runs `bin/keel` from this checkout,
    isolates git configuration as the global constraints say (its own `GIT_CONFIG_GLOBAL` with
    `user.name`, `user.email` and `commit.gpgsign = false`, `GIT_CONFIG_SYSTEM=/dev/null`, the
    `GIT_CONFIG_COUNT` family unset) and sets `KEEL_DENY_FILE` and `HOME` in every case, so a run
    on the owner's machine gives what a run in CI gives (example: with the owner's real list in
    place, the suite's counts are the same as with none),
    builds each fixture under one `mktemp -d` removed at exit, and is run by `tests/run-tests.sh`
    through the call `add "tests/test-leak-guard.sh" "tests/test-leak-guard.sh"`, appended after
    `; ` to the existing line that begins `add "tests/test-grep-quiet.sh"`, so no line moves.
    Example: `grep -c test-leak-guard.sh tests/run-tests.sh` prints `1`, `wc -l
    tests/run-tests.sh` is unchanged, and `tests/no-internal-leaks.sh` passes with the file
    staged.

**Done when:** `tests/test-leak-guard.sh` and `tests/test-no-leaks.sh` pass, `bash -n bin/keel`
exits 0, and `shellcheck -x lib/deny-list.sh tests/no-internal-leaks.sh tests/test-no-leaks.sh
tests/test-leak-guard.sh bin/keel` reports nothing where `shellcheck` is installed.

**Why one task and not two.** The loader's only new consumer is `keel scan --leaks`, its own cases
are four, and a reviewer who rejects the scan's design rejects the loader built for it; the
refactor of `tests/no-internal-leaks.sh` is pinned by that file's existing tests, unchanged.

- [x] **Step 5.1: Build it test first** Note: tests first, 26 passed 61 failed before; 87 and 31 after

Follow `keel:tdd` for behaviours 1, 2a and 4 to 15 (10a included): write the loader cases in
`tests/test-no-leaks.sh` and the cases of `tests/test-leak-guard.sh`, run them, and watch them fail,
then write `lib/deny-list.sh`, the scanner's change and the two `keel scan` modes, and watch them
pass. Then behaviours 16 and 17.
Run: `tests/test-no-leaks.sh && tests/test-leak-guard.sh`
Expected before the implementation: FAIL. The loader cases fail because `lib/deny-list.sh` does
not exist; the `keel scan --leaks` cases fail because `keel scan` hands `--leaks` to the supply
chain scanner, which ignores it and scans the working tree: no mode line is printed and a
`Quillbank` message exits 0. Behaviour 2a's `grep -c` prints `3`. Expected after: PASS. Quote the
failing output in your report.

Run: `git add -N lib/deny-list.sh tests/test-leak-guard.sh`
Run: `tests/no-internal-leaks.sh && tests/test-doc-claims.sh`
Run: `tests/validate-citations.sh && tests/test-grep-quiet.sh`
Expected: PASS for the last two lines. `bin/keel` gained lines only below line 2180, as
behaviour 3 places them, so no citation moved; if `tests/validate-citations.sh` reports anything,
stop and report it rather than repair another file, since the commit below names only this task's
files. This task is in a declared concurrent batch with task 4,
so the suite runs once at the join (the header's batch gate) and this task schedules no boundary
run.

- [x] **Step 5.2: Commit** Note: fe43b1d (merged as c1b3d13); rounds: 1; routing: keel-implementer; loop: light; gate: run-tests.sh and test-keel.sh pass at the join

You are in your own worktree, so this task commits rather than handing over.

```bash
git add lib/deny-list.sh tests/test-leak-guard.sh tests/no-internal-leaks.sh \
        tests/test-no-leaks.sh bin/keel tests/run-tests.sh docs/03-install-and-distribution.md
git commit -s -m "feat(scan): keel scan --leaks checks a push and a message against the deny list"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 6: `keel guard install --leak-guard`, the push and commit-message hooks

**Files:**
- Modify: `bin/keel`, `tests/test-leak-guard.sh` and `docs/03-install-and-distribution.md`

**Interfaces:**
- Consumes: `keel scan --leaks` and `keel scan --leaks-message`, task 5, found through `keel --help`
  holding `scan --leaks`.
- Produces: `keel guard install --leak-guard`, `keel guard install --no-leak-guard`; a third line
  `LEAK_GUARD=1` or `LEAK_GUARD=0` in the generated `pre-push`, after the `VERIFY_KEYS` line; an
  executable `commit-msg` carrying keel's mark, written only while the leak guard is on. The texts
  it prints, exactly:

```text
installed pre-push, pre-commit, prepare-commit-msg and commit-msg in <dir>, where no checkout can replace them
the leak guard is on: each push and each commit message is checked against the deny list
the leak guard is off; removed keel's commit-msg
keel guard: push refused by the leak guard.
keel guard: the leak guard is on and keel is not on PATH, so nothing was checked. Push refused.
keel guard: the keel on PATH is too old for the leak guard, so nothing was checked. Push refused.
keel guard: commit refused by the leak guard. The message is kept in .git/COMMIT_EDITMSG; edit it and commit again.
keel guard: the leak guard is on and the keel on PATH cannot check a message, so nothing was checked. Commit refused.
leak guard: on, deny list loaded (<n> patterns)
leak guard: on, WARNING no deny list at <path>, generic patterns only
leak guard: on, but commit-msg is missing or not keel's. Re-run 'keel guard install --leak-guard'
```

  After `keel guard: push refused by the leak guard.` the hook prints, on stderr:

```text
Each finding above names a commit, a field or a file, and the deny list line whose pattern
matched, never the matched text. Open the deny list on this machine to see the pattern, and do not
paste it anywhere public. Rewrite the commit (git commit --amend, or git rebase -i), then push
again.

A Claude-Session trailer is removed from every commit not yet pushed by running the commit-msg
hook over each of them again, where <upstream> is what the branch is based on (origin/main):

  git rebase <upstream> --exec 'git commit --amend --no-edit'

To push anyway, deliberately and on the record:  git push --no-verify
```

**Depends on:** task 5

**Behaviours:**

1. **Opt in per repository.** The leak guard changes what every push and commit does, so it is
   never on by default, and the deny list's presence does not turn it on: the deny list lives in
   the owner's home, and on by presence would refuse his pushes to a client's own repository,
   which names that client legitimately. `keel guard install --leak-guard` writes `LEAK_GUARD=1`
   and the `commit-msg` hook and prints the first two lines above. A plain `keel guard install` in
   a repository that never opted in writes `LEAK_GUARD=0`, writes no `commit-msg`, and prints the
   three lines it prints today. Example: after each, `sed -n 3p .git/hooks/pre-push` prints the
   value, and `.git/hooks/commit-msg` exists only after the first.
2. **A reinstall keeps the choice.** A plain `keel guard install` where the installed `pre-push`
   holds `LEAK_GUARD=1` keeps it on and rewrites `commit-msg`, so a reinstall after an upgrade
   cannot switch it off silently; `--no-leak-guard` writes `LEAK_GUARD=0`, removes `commit-msg`
   only when it carries keel's mark, and prints `the leak guard is off; removed keel's commit-msg`.
   Example: install with the flag, reinstall without it, and `LEAK_GUARD=1` remains.
3. **Another tool's `commit-msg`.** `--leak-guard` refuses when `.git/hooks/commit-msg` exists
   without keel's mark, with the message `guard_foreign_hook` already gives (`... is another tool's
   hook, and installing would overwrite it. Remove or rename it, then re-run.`), and writes
   nothing. A plain install still ignores a foreign `commit-msg`, so no repository that never
   opted in is refused where it was not before. Example: both cases, with a foreign hook written by
   the test.
4. **The pre-push hook, with `LEAK_GUARD=1`.** For every line git feeds it that is not a delete,
   it collects `<local sha>:<remote ref>`, unpeeled, and after the default-branch and profile
   checks and before the supply chain scan it runs `keel scan --leaks "$1" <pairs>`. A non-zero
   exit prints the refusal block above and exits 1. Run by hand with no arguments, it runs
   `keel scan --leaks origin` with no pairs, so the mode line still prints. Example, in a fixture
   with a bare remote, `KEEL_DENY_FILE` naming the file of task 5 and `keel` on PATH: a branch
   commit whose message names `Quillbank`, fed to `.git/hooks/pre-push origin <url>` in the shape
   of the cases under "the push guard" in `tests/test-keel.sh`, exits 1 with output holding
   `deny list line 3` and `push refused by the leak guard` and not `Quillbank`; a clean branch
   exits 0 with output holding `leak guard: deny list loaded`.
5. **Generic mode lets a clean push through, and says so.** With the deny file absent, a clean push
   exits 0 and the output holds the `WARNING no deny list` line.
6. **Fail closed when the leak guard cannot run.** With `LEAK_GUARD=1`, no `keel` on PATH prints
   `... keel is not on PATH, so nothing was checked. Push refused.` and exits 1; a `keel` whose
   `--help` lacks `scan --leaks` prints `... too old for the leak guard ...` and exits 1. The help
   is read whole, as the hook already reads it for `scan --push`. This reverses, for the leak guard
   only, the 2026-09-27 choice to allow a push nothing could scan, by the owner's decision of
   2026-10-22: the leak guard is opted into, and what it guards against cannot be removed once
   pushed. The supply chain scan keeps the 2026-09-27 choice. With `LEAK_GUARD=0` both cases
   behave exactly as today. Example: the four cases, using `PATH=/usr/bin:/bin` and an old stub
   `keel` as the existing cases do.
7. **The `commit-msg` hook.** In this order, rewriting the message file through a temporary file:
   (a) it removes every line whose key is `Claude-Session:` in any case, and keeps every other line
   byte for byte, `Co-Authored-By:` lines included; (b) it adds `Signed-off-by: <name> <email>`, the
   name and email `git var GIT_AUTHOR_IDENT` gives, with `git interpret-trailers --in-place
   --if-exists addIfDifferent`; (c) it runs `keel scan --leaks-message "$1"`, and on exit 1 prints
   the commit-refused line and exits 1. **A usable `keel` is one whose `--help`, read whole, names
   `scan --leaks-message`**, the same capability check the pre-push hook makes: an older `keel`
   answers that command by running the supply chain scan and exiting 0, so trusting its exit would
   pass every message. With no `keel` on PATH, or one without the mode, it prints the Interfaces
   line ending `cannot check a message, so nothing was checked. Commit refused.` and exits 1: the
   commit fails closed, as the push does. Example, with `KEEL_DENY_FILE` naming task 5's deny file,
   `HOME` a temporary directory, `user.name` `Test Owner` and `user.email` `owner@example.com`,
   committing this message with `git commit -F`:

   ```text
   feat: x

   Co-Authored-By: Claude <noreply@anthropic.com>
   Claude-Session: https://claude.ai/code/session_example
   ```

   gives a commit whose message is exactly:

   ```text
   feat: x

   Co-Authored-By: Claude <noreply@anthropic.com>
   Signed-off-by: Test Owner <owner@example.com>
   ```

   A line `claude-session: x` is removed too. `git commit --amend --no-edit` then leaves the message
   unchanged. A message naming `Quillbank` is refused, and `git rev-parse HEAD` is unchanged. With
   `PATH=/usr/bin:/bin`, and again with an old stub `keel` whose help lacks the mode and which
   exits 0 for anything, a clean message is refused with that `Commit refused.` line.
8. **`keel guard status`** prints one of the three `leak guard:` lines after its existing lines when
   the installed `pre-push` holds `LEAK_GUARD=1`, and nothing new otherwise, so no repository that
   never opted in sees its status change. Example: all three states, the third by removing
   `commit-msg` after install.
9. **`keel guard uninstall`** also removes `commit-msg` when it carries keel's mark, and leaves
   another tool's. Example: both.
10. **The generated hooks are clean.** `shellcheck -s bash` reports nothing on the generated
    `pre-push` and `commit-msg`, and where `/bin/bash` is 3.2, `/bin/bash -n` parses both; where
    either tool is absent the case prints `SKIP` with the reason. Example: both cases pass or skip.
11. **Help and docs.** The `guard` line of `keel --help` becomes
    `  guard install [--leak-guard|--no-leak-guard]|status|uninstall   ...`, keeping the rest of
    its text. The `keel guard install` section of `docs/03-install-and-distribution.md` describes
    the flag, the fourth hook and what it does to a message, the fail-closed posture for both hooks
    and that it reverses, for the leak guard, the 2026-09-27 choice the paragraph on the pre-push
    hook states for the supply chain scan (that paragraph is edited to say so), that
    `keel guard install --leak-guard` belongs in the main working copy and never in a worktree,
    and the residual: `--no-verify` skips both hooks, and
    nothing made on GitHub (merge commits, pull request titles and bodies, release notes) passes
    through a hook. Example: `tests/test-doc-claims.sh` and `tests/test-harness-claims.sh` pass.
12. The cases go in `tests/test-leak-guard.sh`. `tests/test-keel.sh`'s guard cases are not edited
    and must still pass; they run in task 12, since that file takes longer than the device allows.
    Example: `git diff --stat` for this task lists no `tests/test-keel.sh`.

**Done when:** `tests/test-leak-guard.sh` passes, `bash -n bin/keel` exits 0, and `shellcheck -x
bin/keel tests/test-leak-guard.sh` reports nothing where `shellcheck` is installed.
`tests/test-keel.sh`, whose guard cases pin the install output this task changes, takes about six
minutes and is not this task's to run: the batch gate for tasks 6 and 7 runs it at the join.

- [x] **Step 6.1: Build it test first** Note: tests first, 116 passed 53 failed before; 169 after

Follow `keel:tdd` for behaviours 1 to 10: write the cases, run them, and watch them fail, then
change `bin/keel` and watch them pass. Then behaviour 11.
Run: `tests/test-leak-guard.sh`
Expected before the implementation: FAIL. The install cases fail because `keel guard install
--leak-guard` writes no `commit-msg` and no `LEAK_GUARD` line; the hook cases fail because the
pre-push lets a `Quillbank` message through. Task 5's cases still pass. Expected after: PASS. Quote
the failing output in your report.

Run: `tests/test-leak-guard.sh && tests/test-doc-claims.sh && tests/test-harness-claims.sh`
Run: `tests/validate-citations.sh`
Expected: PASS. Every change to `bin/keel` here (`guard_hook_body`, the `commit-msg` body,
`cmd_guard`, the help lines) lies below line 2180, so no citation moves; if
`tests/validate-citations.sh` reports anything, stop and report it rather than repair another
file, since the commit below names only this task's files. This task is in a declared concurrent
batch with task 7, so the suite runs once at
the join (the header's batch gate) and this task schedules no boundary run.

- [x] **Step 6.2: Commit** Note: 3270f27 (implementer ec15ea0, amended once for doc line width); rounds: 2; routing: keel-implementer; loop: light; gate: run-tests.sh and test-keel.sh pass at the join

You are in your own worktree, so this task commits rather than handing over.

```bash
git add bin/keel tests/test-leak-guard.sh docs/03-install-and-distribution.md
git commit -s -m "feat(guard): an opt-in leak guard on every push and commit message"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 7: A DCO sign-off check for pull requests

**Files:**
- Create: `tests/check-dco.sh` and `tests/test-check-dco.sh`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Produces: `tests/check-dco.sh <base> <head>`, executable, consumed by task 8's CI job and by
  tasks 12 and 13. Exit 0 when every checked commit is signed off, 1 when any is not, 2 on a usage
  error or a revision that is not a commit. Its lines, exactly:

```text
usage: tests/check-dco.sh <base> <head>
SKIP  <sha7> authored by <name>, a bot
FAIL  <sha7>: no Signed-off-by for <author email>
OK    <n> commit(s) signed off
<m> commit(s) without a sign-off. Add one to each with: git rebase --signoff <base>
```

**Depends on:** task 2

**Behaviours:**

1. It checks every commit of `git rev-list --no-merges <base>..<head>`. A commit passes when its
   message holds a line `Signed-off-by: <any name> <email>` whose email equals the author email,
   compared without case, which is what the Developer Certificate of Origin asks of the author.
   Example, in a fixture: a base commit, then A committed with `git commit -s`, then B without:
   `tests/check-dco.sh <base> <B>` prints `FAIL  <B7>: no Signed-off-by for <B's author email>` and
   the summary line, exit 1; `tests/check-dco.sh <base> <A>` prints `OK    1 commit(s) signed off`,
   exit 0.
2. Exempt: a merge commit, which carries no change of its own to certify (and the merge GitHub
   makes for a pull request is not in the range at all); and a commit whose author name ends in
   `[bot]`, which cannot certify anything and is printed as `SKIP`. Example: a range whose only
   unsigned commit is a merge passes; one authored `dependabot[bot]` prints
   `SKIP  <sha7> authored by dependabot[bot], a bot` and passes.
3. Edges: a sign-off whose email differs from the author's only in case passes; one for another
   email fails; a `Signed-off-by:` text in the subject line only, not as a line of its own, fails;
   an empty range prints `OK    0 commit(s) signed off`; one argument prints the usage line and
   exits 2; a base that is not a commit exits 2.
4. Plain bash, runs under bash 3.2, no network, reads nothing but git. The header comment says why
   the check is a script here rather than a third-party app (decision 6), why merges and bots are
   exempt, and how to fix a failure (`git rebase --signoff <base>`, then push the branch again).
   Example: `grep -c 'rebase --signoff' tests/check-dco.sh` prints at least `1`, and
   `shellcheck -x tests/check-dco.sh` reports nothing.
5. `tests/test-check-dco.sh` is in the house shape, isolates git configuration as the global
   constraints say (its fixtures commit with their own `user.name` and `user.email` and
   `commit.gpgsign = false`, never the owner's identity or signing key), and `tests/run-tests.sh`
   runs it through the call `add "tests/test-check-dco.sh" "tests/test-check-dco.sh"`, appended
   after `; ` to the existing line that begins `add "tests/test-grep-quiet.sh"`, so no line moves.
   `tests/check-dco.sh` itself is not in the suite, since it needs a base. Example: `grep -c
   test-check-dco.sh tests/run-tests.sh` prints `1`, and `wc -l tests/run-tests.sh` is unchanged.

**Done when:** `tests/test-check-dco.sh` passes, and `shellcheck -x tests/check-dco.sh
tests/test-check-dco.sh` reports nothing where `shellcheck` is installed.

- [x] **Step 7.1: Build it test first** Note: tests first, 6 passed 22 failed before; 27 after

Follow `keel:tdd` for behaviours 1 to 3: write the cases, run them, and watch them fail, then write
the script and watch them pass.
Run: `tests/test-check-dco.sh`
Expected before the implementation: FAIL, every case fails because `tests/check-dco.sh` does not
exist. Expected after: PASS. Quote the failing output in your report.

Run: `tests/test-check-dco.sh && tests/test-grep-quiet.sh`
Expected: PASS. This task is in a declared concurrent batch with task 6, so the suite runs once at
the join (the header's batch gate) and this task schedules no boundary run.

- [x] **Step 7.2: Commit** Note: 6409720; rounds: 1; routing: keel-implementer; loop: light; reviewer flagged the stderr 'not a commit' line as outside the exact-lines list, accepted as a diagnostic for the exit-2 case; gate passes at the join

You are in your own worktree, so this task commits rather than handing over.

```bash
git add tests/check-dco.sh tests/test-check-dco.sh tests/run-tests.sh
git commit -s -m "test: a DCO sign-off check for the commits of a pull request"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 8: CI checks the sign-off on pull requests and stops building `sandbox` (coordinator)

The coordinator makes this edit itself: `.github/workflows` is a hard-block path, and
`hooks/sensitive-guard` puts the commit to the owner before it is made.

**Files:**
- Modify: `.github/workflows/ci.yml`

**Depends on:** task 7

**Behaviours:**

1. Lines 5 to 8 of `.github/workflows/ci.yml` (the three comment lines about `sandbox` and
   `branches: [main, sandbox]`) become exactly these four lines, so no later line moves and the
   citations of lines 3 to 6, 14, 16, 36 to 38, 43 to 53 and 85 elsewhere stay where they are:

   ```yaml
       # main only. Work reaches main through pull requests, which the pull_request trigger below
       # builds on every push to their branch, so a branch needs no push build of its own, and a
       # branch pushed with no pull request open is checked by the local guard alone.
       branches: [main]
   ```

2. A job is appended at the end of the file, after the `supply-chain` job, exactly:

   ```yaml

     # On pull requests only. Every commit in the pull request carries a Signed-off-by line for its
     # author, the Developer Certificate of Origin, checked by a script in this repository rather
     # than a third-party app. Merge commits and bot-authored commits are exempt, for the reasons in
     # tests/check-dco.sh. A separate job so that it can be a required check on its own.
     dco:
       name: DCO sign-off
       if: github.event_name == 'pull_request'
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
           with:
             fetch-depth: 0

         - name: Every commit is signed off by its author
           env:
             BASE_SHA: ${{ github.event.pull_request.base.sha }}
             HEAD_SHA: ${{ github.event.pull_request.head.sha }}
           run: tests/check-dco.sh "$BASE_SHA" "$HEAD_SHA"
   ```

3. Nothing else in the file changes. Example: `grep -c sandbox .github/workflows/ci.yml` prints
   `0`, `grep -c 'name: DCO sign-off' .github/workflows/ci.yml` prints `1`,
   and `tests/validate-citations.sh` passes.

**Done when:** `tests/validate-citations.sh` passes and behaviour 3's two counts print. The
workflow itself first runs on task 13's pull request, and task 14 reads it.

- [x] **Step 8.1: There is no test for this** Note: no test for a workflow; behaviour 3: sandbox count 0, DCO job count 1, citations OK

This task is the coordinator's. A workflow cannot be run before it is pushed; the checks of
behaviour 3 are what can be run here. Make the two edits, run behaviour 3, and read the diff
through once against the text above.

- [x] **Step 8.2: Hand over** Note: 768abad; coordinator task, hard-block path edited by the coordinator; rounds: 0; routing: coordinator; loop: n/a

```bash
git add .github/workflows/ci.yml
git status --porcelain
```

The coordinator commits, after the owner approves the hard-block prompt, with
`git commit -s -m "ci: check DCO sign-off on pull requests; build main and pull requests only"`.

---

### Task 9: CONTRIBUTING and SECURITY say how the public repository is worked

**Files:**
- Create: `SECURITY.md`
- Modify: `CONTRIBUTING.md` and `docs/06-repo-layout.md`

**Depends on:** tasks 6 and 7

**Behaviours:**

1. `SECURITY.md`, new at the root: a title `# Security policy`; that a vulnerability in keel is
   reported privately by email to `` `security@<owner to fill>` `` (in a code span, so the angle
   brackets render), never in an issue, a pull request or a discussion; what a report should hold
   (the version, the steps, the impact as the reporter sees it); that security audits of keel
   itself are kept in a private repository until their findings are fixed, so a fix can ship before
   its description; and that there is no CLA. It promises no response time, which nobody has
   decided. Example: `grep -c 'security@<owner to fill>' SECURITY.md` prints `1`, and
   `tests/validate-skills.sh` passes.
2. `CONTRIBUTING.md` gains a section `## Branches, pull requests and sign-off`, placed directly
   before `## Commits and review`, saying: the repository is public and so is every branch pushed
   to it; work happens on a short-lived branch from `main` and reaches `main` through a pull
   request, and `main` is always releasable; every commit carries `Signed-off-by:` for its author
   under the Developer Certificate of Origin (`git commit -s`), checked on every pull request by
   the `DCO sign-off` job (`tests/check-dco.sh`), merge and bot commits exempt, and fixed with
   `git rebase --signoff main`; where the leak guard is installed its `commit-msg` hook adds the
   sign-off for the configured identity, so a maintainer's commits carry it without `-s`; there is
   no CLA; vulnerabilities go by email as `SECURITY.md` says, never in an issue; maintainers
   holding the deny list run `keel guard install --leak-guard` in their main working copy; and an
   audit a skill writes to `docs/audits/` is committed in that clone, never in this repository:
   `git -C docs/audits add <file>`, `git -C docs/audits commit -s -m "audits: <file>"`,
   `git -C docs/audits push`, where `git status` in this repository shows nothing because the
   directory is ignored.
   It closes with exactly this sentence: "Commit SHAs cited in `CHANGELOG.md`,
   `tests/evals/results.md`, `docs/plans/` and `docs/ideas/` for work before v0.26.0 name commits
   in the private repository keel was developed in until then, which is archived, so they do not
   resolve in this one." Example: `grep -c '^## Branches, pull requests and sign-off$'
   CONTRIBUTING.md` prints `1`, and `grep -c 'so they do not' CONTRIBUTING.md` prints `1`.
3. In `## Commits and review`, the line beginning `- **No attribution footers.**` becomes:
   "- **Trailers.** `Signed-off-by` on every commit. `Co-Authored-By` may stay. No `Claude-Session`
   line: the leak guard's `commit-msg` hook removes it. No robot emoji and no generated-with line."
   The review paragraph after it states the review rule in full, as decision 9 of
   `docs/07-open-decisions.md` and the "Review" section of `docs/standards.md` hold it: Bernard
   Tebandeke or `gfsekamanya` reviews, either suffices, never the change's own author; and adds
   that an outside contributor
   cannot merge their own change, because merging needs write access and `main` requires an
   approving review. Example: `grep -c 'cannot merge their own change' CONTRIBUTING.md` prints `1`.
4. Lines 1 to 52 of `CONTRIBUTING.md` are unchanged. Example: `head -52 CONTRIBUTING.md` is byte
   for byte what it was, and `tests/validate-citations.sh` passes.
5. `docs/06-repo-layout.md`'s first tree gains `├── SECURITY.md` between `├── README.md` and
   `├── SOURCES.md`, because `tests/test-doc-claims.sh` fails when a tracked top-level entry is
   missing from it. Example: with `SECURITY.md` added with `git add -N`, that test passes.
6. `README.md` is not edited here: it is a shared record, and its rows for these documents are
   task 11's, after the batch. Example: `git diff --stat` for this task lists no `README.md`.

**Done when:** `tests/test-doc-claims.sh` and `tests/validate-skills.sh` pass. These two are this
task's own checks: they read the documents it writes.

- [x] **Step 9.1: There is no test for this** Note: docs task, no failing test; Done-when passed

These are documents, and no failing test comes before them. Run `git add -N SECURITY.md` first,
so the tree checks see it. Make the edits, then run the Done-when commands,
`tests/validate-citations.sh` and the check of each behaviour's example. Expected: PASS, and each
check prints what its example says. Quote the outputs in your report. This task is in a declared
concurrent batch with task 10, so the suite runs once at the join.

- [x] **Step 9.2: Commit** Note: 46b4a7c (implementer d08bbb4); rounds: 1; routing: keel-implementer; loop: light; gate passes at the join

You are in your own worktree, so this task commits rather than handing over.

```bash
git add SECURITY.md CONTRIBUTING.md docs/06-repo-layout.md
git commit -s -m "docs: contributing and a security policy for the public repository"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 10: The release runbook for one public repository, and going-public as history

**Files:**
- Modify: `docs/runbooks/cutting-a-release.md` and `docs/runbooks/going-public.md`

**Depends on:** tasks 4 and 6

**Behaviours:**

1. `cutting-a-release.md`'s opening says it covers the eval gate, the version-bump pull request,
   the merge, the annotated tag on the merged commit and the GitHub release, all in
   `gbi-solutions-ltd/keel`; the two-repository table and the paragraph after it are replaced by
   one paragraph of current state: there is one repository, it is public, and every branch pushed
   to it is public the moment it lands. How releases were cut before is history, which the
   `CHANGELOG.md` entry of task 11 and `going-public.md` hold, not this runbook. Example:
   `grep -c keel-internal` on the file prints `1` (behaviour 7's "Do not" line) and
   `grep -c '| internal |'` prints `0`.
2. Sections 0 and 1 keep their content, and the sentence that holds `Dispatch all 7 concurrently`
   keeps that phrase, which `tests/test-eval-harness.sh` reads. Example: that file's runbook case
   passes.
3. Section 2, the bump, is done on a branch `release/X.Y.Z` from `main`; the four places, the two
   expected red tests before the commit and the commit `release: X.Y.Z` stay as written, with the
   commit made with `-s`. Example: `grep -c 'release/X.Y.Z'` on the file prints at least `1`, and
   the two `FAIL` lines quoted in that section are still there.
4. Section 3 becomes "Land it": push the release branch (the leak guard's mode line must say the
   deny list is loaded with the owner's full count), wait for CI on the release commit and read
   `headSha`,    write the gate result into the pull request body and check that file with
   `keel scan --leaks-message <file>` before `gh pr create --body-file <file>`, review by the
   reviewer who is not the author, then `gh pr merge <n> --merge` and read the merge commit with
   `gh pr view <n> --json state,mergeCommit`. Example: `grep -c 'leaks-message'` on the file
   prints at least `2` once behaviour 5 is written too.
5. Section 4 becomes "Sweep, tag and release": `git fetch origin --tags`, then on a detached
   checkout of the merge commit run `tests/no-internal-leaks.sh` and require both the full pattern
   count and `OK` (the release-time sweep, over the tracked tree; the untracked `docs/audits/` is
   not in `git ls-files`), check the tag message file and the release notes file with `keel scan
   --leaks-message`, `git tag -a vX.Y.Z <merge-sha> -F <message-file>`, `git push origin vX.Y.Z`
   (the leak guard checks the tag's message), `gh release create vX.Y.Z --repo
   gbi-solutions-ltd/keel --title "keel X.Y.Z" --notes-file <notes> --latest`, then verify through
   the API that `VERSION` at the tag is X.Y.Z and that `docs/audits` at the tag is a 404. The
   `.claude` 404 check goes, since `.claude/` is published. Release notes still carry no path that
   exists only in the private clone. Example: the file holds `contents/docs/audits?ref=` and no
   `contents/.claude?ref=`.
6. The steps for the export, the commit inside it, the sweep from inside it, the sync and the file
   count are gone from the procedure, and so are the Symptoms rows about the export (the count
   disagreement and the export's citation failure). New Symptoms rows: the leak guard's `WARNING no
   deny list` line (do not push; restore the list); `keel is not on PATH` from the leak guard (put
   this working copy's `bin/keel` on PATH); a `DCO sign-off` failure (`git rebase --signoff main`,
   then push the branch again); a validator reporting a broken citation into `docs/audits/` on the
   owner's machine (the private clone is behind or missing a file: pull it). The "Symptoms"
   heading stays. Example: `grep -c 'export-public' docs/runbooks/cutting-a-release.md` prints
   `0`, and `grep -c 'rebase --signoff'` on it prints at least `1`.
7. "Do not": the `sandbox` lines go; "Do not push the public tree from this repository" becomes
   "Do not add `keel-internal` as a remote of this working copy, and never push its history: it is
   archived, and every deny pattern is reachable in it"; "Do not stay on `main` after merging"
   becomes "Start every change on its own branch from `main`". "Who decides what": the export
   exclusion row becomes "What is withheld (`tests/withheld.sh`) | Bernard. `docs/audits/` is the
   standing answer". Example: `grep -c 'archived, and every deny pattern'` on the file prints `1`.
8. `going-public.md` lines 3 to 5 (the `**EXECUTED 2026-08-17.**` paragraph) become exactly three
   lines saying: executed 2026-08-17; superseded for this repository on 2026-10-22, when
   development moved into the public repository `gbi-solutions-ltd/keel` and
   `gbi-solutions-ltd/keel-internal` was archived read-only at v0.26.0; the steps below remain the
   record and the route for the next repository published. Lines 1 to 129 keep their count, so the
   citations of lines 96 and 128 to 129 hold. Example: `sed -n 3,5p` on the file prints the three
   new lines, and `tests/validate-citations.sh` passes.
9. Section 7a of `going-public.md` opens with a paragraph saying it is obsolete for this repository
   since 2026-10-22: there is no export, and a change that is not a release lands through a pull
   request like any other. Example: the first paragraph under the `## 7a.` heading holds
   `obsolete for this repository`.
10. No `sandbox` remains in either runbook, and the release runbook names no export step.
    Example: `grep -c sandbox docs/runbooks/cutting-a-release.md docs/runbooks/going-public.md`
    prints `0` for each (6 and 0 when this plan was written), and
    `grep -cE 'rsync|export-public|keel-export' docs/runbooks/cutting-a-release.md` prints `0`.

**Done when:** `tests/test-harness-claims.sh` and `tests/validate-citations.sh` pass. These are
this task's own checks: the first reads the runbooks for claims, the second the citations of lines
96 and 128 to 129 of `going-public.md`.

- [x] **Step 10.1: There is no test for this** Note: docs task, no failing test; Done-when passed

These are runbooks, and no failing test comes before them. Make the edits, then run the Done-when
commands, `tests/validate-skills.sh`, `tests/test-eval-harness.sh` and the check of each
behaviour's example. Expected: PASS. Quote the outputs in your report. This task is in a declared
concurrent batch with task 9, so the suite runs once at the join.

- [x] **Step 10.2: Commit** Note: de686d1 (implementer 9720249, amended once: opening claim made true, section 3 reordered so CI is awaited after the pull request exists, a fault in the plan's step order); rounds: 2; routing: keel-implementer; loop: light; gate passes at the join

You are in your own worktree, so this task commits rather than handing over.

```bash
git add docs/runbooks/cutting-a-release.md docs/runbooks/going-public.md
git commit -s -m "docs(runbooks): release from the one public repository"
git status --porcelain
```

Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it uncommitted.

---

### Task 11: Records: changelog, README, layout, the published `.claude/`, and this plan

**Files:**
- Create: `.claude/settings.json`, `.claude/keel-nudge` and
  `docs/plans/2026-10-22-public-first-development.md`
- Modify: `CHANGELOG.md`, `README.md` and `docs/06-repo-layout.md`

**Depends on:** tasks 3 to 10

**Behaviours:**

1. `CHANGELOG.md` gains `## Unreleased` above `## 0.26.0 - 2026-10-22`, then a blank line, then
   this entry, wrapped to 100 columns with the two-space continuation indent the file uses, so
   that line 12 of the file is a line of the entry and not blank:
   "- Development moved into the public repository. Work lands through short-lived branches and
   pull requests into `main`, and a release is a version-bump pull request followed by an annotated
   tag and a GitHub release in the same repository (`docs/runbooks/cutting-a-release.md`).
   `tests/export-public.sh` is gone. The 27 audits under `docs/audits/` live in a private companion
   repository cloned at that path and ignored by `.gitignore`; `tests/withheld.sh` holds the one
   list of withheld paths, and the validators skip a path in it only while it is absent.
   `keel guard install --leak-guard` adds a local leak guard: `keel scan --leaks` checks every
   commit a push carries (files, paths, messages, author and committer, tag messages and ref names)
   against the deny list and never prints what matched, refuses a pushed `Claude-Session:` trailer,
   and fails closed when it cannot run; a `commit-msg` hook checks each message, removes
   `Claude-Session:` trailers and adds a sign-off. Pull requests are checked for a
   DCO `Signed-off-by` line by `tests/check-dco.sh`. `.claude/` is published. See
   `CONTRIBUTING.md` and `SECURITY.md`."
   Example: `sed -n 10,12p CHANGELOG.md` prints `## Unreleased`, a blank line and the entry's first
   line, and `tests/validate-citations.sh` passes.
2. `docs/06-repo-layout.md`'s first tree: under `lib/`, `│   ├── deny-list.sh` after
   `│   ├── detect-stack.sh`; under `tests/`, `│   ├── export-public.sh` removed and
   `│   ├── check-dco.sh`, `│   ├── test-check-dco.sh`, `│   ├── test-leak-guard.sh`,
   `│   ├── test-withheld.sh` and `│   ├── withheld.sh` added in alphabetical order with the
   lines around them; and the `│   ├── audits/` line under `docs/` gains the comment
   `# private: a clone of a separate repository, ignored by .gitignore`. Example:
   `grep -c 'withheld.sh' docs/06-repo-layout.md` prints `2`, `grep -c export-public
   docs/06-repo-layout.md` prints `0`, and `tests/test-doc-claims.sh` passes.
3. The two `.claude/` files task 2 copied in are added unchanged. Example: `git hash-object
   .claude/settings.json .claude/keel-nudge` prints the two ids task 2 printed, and `git ls-files
   -s .claude/keel-nudge` shows mode `100755`. `tests/no-internal-leaks.sh` and
   `tests/supply-chain-scan.sh` pass with them staged (the second honours its own allowance for
   `.claude/keel-nudge`).
4. This plan file is added as it stands, ticks included. Example: `git diff --cached --stat`
   lists `docs/plans/2026-10-22-public-first-development.md` as a new file.
5. `README.md`'s documentation table: the `docs/runbooks/cutting-a-release.md` row says "How a
   release is cut: the eval gate, the version-bump pull request, the tag and the GitHub release, in
   the one public repository"; the `docs/runbooks/going-public.md` row says "What publishing this
   repository required in 2026-08, each step annotated, and why development moved into it on
   2026-10-22"; the `CONTRIBUTING.md` row says "How to contribute: branches and pull requests,
   sign-off, review, and why the order of adding a skill matters", and names `SECURITY.md`. Each
   row is edited in place, so the file's line count above line 233 is unchanged. Example:
   `grep -c 'version-bump pull request' README.md` prints `1`, and `tests/test-doc-claims.sh` and
   `tests/validate-citations.sh` pass.

**Done when:** `tests/test-doc-claims.sh`, `tests/validate-citations.sh`,
`tests/validate-skills.sh`, `tests/no-internal-leaks.sh` and `tests/supply-chain-scan.sh` pass.

- [x] **Step 11.1: There is no test for this** Note: records, no failing test; Done-when passed

These are records, and no failing test comes before them. Make the edits, stage the four created
paths, then run the Done-when commands and the check of each behaviour's example. Expected: PASS.
Quote the outputs in your report.

- [x] **Step 11.2: Hand over** Note: committed by the coordinator; rounds: 1; routing: keel-implementer; loop: light

```bash
git add CHANGELOG.md README.md docs/06-repo-layout.md .claude/settings.json .claude/keel-nudge \
        docs/plans/2026-10-22-public-first-development.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with
`git commit -s -m "docs: changelog, layout, the published .claude and the public-first plan"`.
Paste the `git status --porcelain` output into your report; it should now list nothing untracked.

---

### Task 12: Verify the whole change (coordinator)

The coordinator runs this task itself.

**Files:** none. This task changes no file; a failure becomes a further task of this plan.

**Depends on:** task 11

**Behaviours:**

1. **The fresh-clone condition.** The branch reaches the cloud workspace with its history, so that
   behaviour 6 can read `main..HEAD` there. **This part is the owner's:** in his terminal, in the
   working copy, he runs
   `git bundle create "$TMPDIR/public-first.bundle" main public-first` and uploads the file to the
   coordinator's chat. The coordinator then makes the copy, which holds no `docs/audits/`, and a
   local `main`, since a clone of a bundle creates only `origin/main`:

   ```bash
   git clone -b public-first <the uploaded bundle> <copy>
   git -C <copy> branch main origin/main
   git -C <copy> rev-parse main public-first      # two ids, matching the owner's
   ```

   The cloud workspace injects git configuration through
   `GIT_CONFIG_COUNT` and `GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n` (a `url.insteadOf` rewrite) that
   `tests/run-tests.sh` does not clear, and with it the suite is red before any change (one failure
   in `tests/test-ci-review.sh`, reported by the plan's reviewer), so the run is:

   ```bash
   cd <copy>
   env -u GIT_CONFIG_COUNT $(env | sed -n 's/^\(GIT_CONFIG_\(KEY\|VALUE\)_[0-9]*\)=.*/-u \1/p') \
       GIT_CONFIG_GLOBAL=/dev/null tests/run-tests.sh
   ```

   Expected: `All test files passed`, `tests/test-keel.sh`'s guard cases included, and the lint
   step prints `OK    shellcheck clean`. The report states that the environment was cleared and
   why.
2. **The owner's condition.** In the working copy, with `docs/audits/` present:
   `tests/validate-skills.sh`, `tests/validate-citations.sh`, `tests/test-withheld.sh` and
   `tests/test-harness-claims.sh` pass, so a present clone is still checked and agrees with the
   tree.
3. **The lint on CI's `shellcheck` too.** `verify.lint` exits 0 under `shellcheck` 0.9.0 (CI's
   `ubuntu-latest` package; `pip install shellcheck-py==0.9.0.6` in a venv) as well as the
   workspace's, since the parent-relative source of `tests/no-internal-leaks.sh` was measured on
   0.11.0 only. Fallback if 0.9.0 reports SC1091 there: a `# shellcheck source=lib/deny-list.sh`
   line above a separate source line, in a further task, never a `disable=`.
4. **Bash 3.2, on the owner's machine,** which ships it as `/bin/bash`: in the working copy (the
   device shell, or the owner's terminal), with a symlink to `/bin/bash` first on PATH as the CI
   macOS step makes, the new test files run under 3.2:

   ```bash
   /bin/bash --version | sed -n 1p                  # GNU bash, version 3.2...
   mkdir -p "$TMPDIR/bash32" && ln -sf /bin/bash "$TMPDIR/bash32/bash"
   for t in tests/test-withheld.sh tests/test-leak-guard.sh tests/test-check-dco.sh; do
       PATH="$TMPDIR/bash32:$PATH" /bin/bash "$t" | tail -1
   done
   ```

   Expected: each ends `0 failed`. The CI macOS job's 3.2 step then covers the whole suite on the
   first pull request, and task 14 reads it.
5. **A rehearsal of the leak guard over this branch's real range**, in the cloud copy of behaviour
   1, with a deny file written here holding the same invented lines as task 5's (that one lives in
   a test's temporary directory and is gone). The bare remote holds `main` only, so every commit of
   `public-first` is new to it, as it will be to the public repository:

   ```bash
   printf '%s\n' '# invented identifiers for the leak guard rehearsal' '' 'Quillbank' \
       'zephyr-ledger' '\bQBK\b' > "$TMPDIR/rehearsal-deny.txt"
   git init -q --bare "$TMPDIR/rehearsal.git"
   git push -q --no-verify "$TMPDIR/rehearsal.git" main:refs/heads/main
   git remote add rehearsal "$TMPDIR/rehearsal.git" && git fetch -q rehearsal
   bin/keel guard install --leak-guard
   KEEL_DENY_FILE="$TMPDIR/rehearsal-deny.txt" PATH="$PWD/bin:$PATH" \
       git push --dry-run rehearsal public-first
   ```

   Expected: `checked <n> commit(s)` with `<n>` the count of `git rev-list main..public-first`,
   `no findings`, and no `push refused`: this is what proves `tests/test-no-leaks.sh` (task 5
   behaviour 2a) and every other changed file pass the generic patterns. Then a commit whose
   message names `Quillbank` is refused, with output holding `deny list line 3` and not
   `Quillbank`; and with `KEEL_DENY_FILE` pointing at an absent file a clean push shows the
   `WARNING` line and is allowed.
6. **The branch's own commits.** `tests/check-dco.sh main HEAD` prints `OK` (every commit was made
   with `-s`); `git log main..HEAD --format=%B | grep -ci '^claude-session:'` is recorded, and any
   count above 0 is handed to task 13, whose behaviour 3 removes them.
7. **The plan's ticks are committed last,** so task 13 starts from a clean tree (its rebase
   refuses a dirty one, and this plan file has been tracked since task 11). The coordinator ticks
   steps 12.1 and 12.2 and commits the file alone, in the working copy:
   `git commit -s -m "docs(plans): tick public-first through task 12" -- <this file>`.
   Ticks for tasks 13 to 17 are made by the coordinator after task 17, from the owner's reports,
   and land with the next pull request. Example: `git status --porcelain` in the working copy
   prints nothing afterwards.

**Done when:** there is no command in the profile for this. The evidence is the report: each
behaviour's output, and any failure named with its file and cause and the task added for it.

- [x] **Step 12.1: There is no test for this** Note: behaviours 1 to 3, 5, 6 run: fresh clone suite All test files passed with the injected git settings cleared (they redden tests/test-ci-review.sh otherwise); lint OK on shellcheck 0.9.0; docs/audits present on the owner's copy: four checks pass; rehearsal and DCO ok (9 signed off, 0 Claude-Session); behaviour 4 bash 3.2 NOT run, owner's terminal

Run behaviours 1 to 6 and note each result with its output.

- [x] **Step 12.2: Hand over** Note: ticks committed alone as the plan says; rounds: 0; routing: coordinator; loop: n/a

Behaviour 7 is the only commit: the plan's ticks. Hand the results to the owner with task 13.

---

### Task 13: Fill the security address, arm the leak guard, open the first pull request (owner)

The owner runs this task in his own terminal, in the new working copy, on `public-first`.

**Files:**
- Modify: `SECURITY.md`

**Depends on:** task 12

**Behaviours:**

1. **The security address.** Replace `security@<owner to fill>` in `SECURITY.md` with the real
   address, and commit it.

   ```bash
   git status --porcelain                       # prints nothing (task 12 committed the ticks)
   grep -n 'owner to fill' SECURITY.md          # the one line to change
   git add SECURITY.md
   git commit -s -m "docs(security): the address for private vulnerability reports"
   grep -c 'owner to fill' SECURITY.md          # 0
   ```

2. **Arm the leak guard from this branch, inside this working copy only.** The machine-wide `keel`
   is `$STABLE`'s, v0.26.0, which has no leak guard; until the first merge the in-progress code
   runs only here, through an explicit PATH. Every git command below that commits or pushes in
   this task carries `PATH="$NEW/bin:$PATH"`; without it the hooks find v0.26.0 and refuse, which
   is the fail-closed behaviour working as intended.

   ```bash
   "$NEW/bin/keel" guard install --leak-guard
   PATH="$NEW/bin:$PATH" keel guard status
   ```

   Expected, among the lines: `push guard: active` and
   `leak guard: on, deny list loaded (<N> patterns)`, with `<N>` the count task 2 behaviour 4
   printed.

3. **Normalise the branch's messages.** Commits made before the hook existed get the trailer
   removed and the sign-off added; `git commit --amend --no-edit` runs `commit-msg` again (measured
   while planning). This rewrites only commits that were never pushed. The tree must be clean
   first: no `--autostash`, because anything uncommitted here is a surprise to report, not to
   carry through a rewrite.

   ```bash
   git status --porcelain                       # prints nothing; stop and report otherwise
   PATH="$NEW/bin:$PATH" git rebase main --exec 'git commit --amend --no-edit'
   # if an amend is refused part way (a deny finding in a message), git stops the rebase there:
   # git rebase --abort puts the branch back exactly as it was; report the finding, do not
   # --no-verify past it
   git log main..HEAD --format=%B | grep -ci '^claude-session:'   # 0
   tests/check-dco.sh main HEAD                                     # OK    <n> commit(s) signed off
   ```

4. **The release-time sweep over the tree, and a dry run of the push.**

   ```bash
   tests/no-internal-leaks.sh                   # mode ... (<N> patterns), then OK
   PATH="$NEW/bin:$PATH" git push --dry-run -u origin public-first
   ```

   Expected from the dry run, among its lines:
   `leak guard: deny list loaded from ~/.config/keel/internal-deny-list.txt (<N> patterns)` and
   `leak guard: checked <n> commit(s), 0 tag(s) and 1 ref name(s), no findings`, and no
   `push refused`. Stop on any finding. Every commit checked here is authored and committed as
   `bernard@gbi-solutions.com`, so a clean run is also the proof, against the real list, that the
   guard does not treat that address as a leak; an `author email` or `committer email` finding
   means a deny pattern matches it, and is reported rather than worked around.

5. **Push, and open the pull request** with a body file checked first.

   ```bash
   PATH="$NEW/bin:$PATH" git push -u origin public-first
   "$NEW/bin/keel" scan --leaks-message <body-file>   # leak guard: message checked, no findings
   gh pr create --repo gbi-solutions-ltd/keel --base main --head public-first \
       --title "Develop in the public repository" --body-file <body-file>
   ```

**Done when:** there is no command in the profile for this. Behaviour 1's last check prints `0`,
behaviour 2 shows `<N>` patterns, behaviour 3 prints `0` and `OK`, behaviour 4 shows no finding, and
`gh pr create` prints the pull request's URL.

- [x] **Step 13.1: There is no test for this** Note: owner task; owner's terminal. Witnessed: the address is in SECURITY.md, services@gbi-solutions.com, edit read on the owner's copy. The planned rebase in behaviour 3 was aborted (it runs the working tree's keel, which predates the leak guard at the first commit) and skipped: messages were already signed off with no Claude-Session trailer. Dry run output pasted by the owner: 25 patterns, 11 commits checked, no findings. Pull request created in the browser (gh login lacked access to the repository): PR #3, 11 commits; bash 3.2 cases ran on macOS CI

This task is the owner's: run behaviours 1 to 5 in order, stopping at the first output that differs
from the one given.

- [x] **Step 13.2: Hand over** Note: owner reported; PR #3 head 6163ed9; witnessed on GitHub: all five CI jobs passed on that head

Report each behaviour's output and the pull request's number.

---

### Task 14: Confirm CI runs on the public repository (owner)

Whether GitHub Actions runs on this repository is checked here, not assumed: standard hosted
runners are free for public repositories, and the organisation's own Actions settings decide the
rest.

**Files:** none. This task changes no file.

**Depends on:** task 13

**Behaviours:**

1. CI ran on the first pull request, on its head commit, and every job finished.

   ```bash
   gh pr checks <n> --repo gbi-solutions-ltd/keel
   gh run list --repo gbi-solutions-ltd/keel --branch public-first --limit 5 \
       --json headSha,status,conclusion,name
   git rev-parse HEAD
   ```

   Expected: the jobs `Validate skills and templates`, `Tests on macOS`, `Python lint`,
   `Supply chain` and `DCO sign-off` each `pass`, on a run whose `headSha` equals
   `git rev-parse HEAD`; and the macOS job's log shows `GNU bash, version 3.2` in its 3.2 step.
2. If runs stay queued, or fail with a billing or spending-limit message, stop: nothing is merged
   until the organisation's Actions settings are fixed, and the report quotes the message.

**Done when:** there is no command in the profile for this. Behaviour 1's output, with the head SHA
matching.

- [x] **Step 14.1: There is no test for this** Note: witnessed in the browser pane: the CI run on 6163ed9, Validate skills and templates, Tests on macOS, Python lint, Supply chain and DCO sign-off all successful; the macOS step 'Run tests under the bash macOS ships (3.2)' succeeded; the log line printing the bash version was not read

This task is the owner's: run behaviour 1, or record behaviour 2's message.

- [x] **Step 14.2: Hand over** Note: run 40088350682, headSha 6163ed9, no billing block

Report the checks' output and the run's `headSha`.

---

### Task 15: Protect `main`, then review and merge the first pull request (owner)

The owner runs this task. Changing a repository setting and merging are his alone.

**Files:** none. This task changes no file.

**Depends on:** task 14

**Behaviours:**

0. **Before protecting `main`: the reviewer can approve.** GitHub counts an approval towards a
   required review only from someone with write access to the repository, and with
   `enforce_admins` on, every pull request the owner authors waits for `gfsekamanya`.

   ```bash
   gh api repos/gbi-solutions-ltd/keel/collaborators/gfsekamanya/permission -q .permission
   ```

   Expected: `write`, `maintain` or `admin`. Anything else (`read`, `none`, or a 404 because they
   are not a collaborator) is fixed by the owner first, for example with
   `gh api -X PUT repos/gbi-solutions-ltd/keel/collaborators/gfsekamanya -f permission=push`, and
   the check is run again after the invitation is accepted. An organisation team granting write
   access counts the same.
1. **Protect `main`.** A pull request is required, one approving review that the author cannot
   give (decision 9), the four checks that are not advisory, no force pushes and no deletion, and
   the same for administrators, so the owner's own changes are reviewed too. `Tests on macOS` stays
   advisory, as `.github/workflows/ci.yml` says.

   First read and keep whatever protection is there now, because the `PUT` replaces it whole (a
   404 means there is none):

   ```bash
   gh api repos/gbi-solutions-ltd/keel/branches/main/protection > "$TMPDIR/main-protection-before.json"
   cat "$TMPDIR/main-protection-before.json"
   ```

   Report anything it held that the settings below do not, before running them.

   ```bash
   gh api -X PUT repos/gbi-solutions-ltd/keel/branches/main/protection --input - <<'JSON'
   {
     "required_status_checks": {
       "strict": true,
       "contexts": ["Validate skills and templates", "Python lint", "Supply chain", "DCO sign-off"]
     },
     "enforce_admins": true,
     "required_pull_request_reviews": {
       "required_approving_review_count": 1,
       "dismiss_stale_reviews": true
     },
     "restrictions": null,
     "allow_force_pushes": false,
     "allow_deletions": false,
     "required_conversation_resolution": true
   }
   JSON
   gh api repos/gbi-solutions-ltd/keel/branches/main/protection \
       -q '[.enforce_admins.enabled, .required_pull_request_reviews.required_approving_review_count, .required_status_checks.contexts]'
   ```

   Expected:

   ```text
   [true,1,["Validate skills and templates","Python lint","Supply chain","DCO sign-off"]]
   ```
2. **Review and merge.** `gfsekamanya` reviews and approves, since the owner is the author. Then:

   ```bash
   gh pr merge <n> --repo gbi-solutions-ltd/keel --merge
   gh pr view <n> --repo gbi-solutions-ltd/keel --json state,mergeCommit -q '.state + " " + .mergeCommit.oid'
   git switch main && git pull --ff-only
   git -C "$STABLE" pull --ff-only
   keel --help | sed -n '/scan --leaks/p'      # the machine-wide keel now has the leak guard
   git switch -c <the next branch>
   ```

   Expected: `MERGED <sha>`, and two `scan --leaks` help lines. No tag: this is not a release.
   From here pushes in `$NEW` need no `PATH` prefix.
3. **If the reviewer is unavailable,** nothing merges, by design. What unblocks it is the owner
   relaxing protection for that one merge and recording it: switch `enforce_admins` off, merge,
   switch it on again, and say so on the pull request.

   ```bash
   gh api -X DELETE repos/gbi-solutions-ltd/keel/branches/main/protection/enforce_admins
   gh pr merge <n> --repo gbi-solutions-ltd/keel --merge --admin
   gh api -X POST repos/gbi-solutions-ltd/keel/branches/main/protection/enforce_admins
   gh pr comment <n> --repo gbi-solutions-ltd/keel \
       --body "Merged without review on <date>: <reason>. enforce_admins was off for this merge only."
   gh api repos/gbi-solutions-ltd/keel/branches/main/protection -q .enforce_admins.enabled   # true
   ```

   The next pull request's `CHANGELOG.md` entry names the unreviewed merge, so it is in the
   history as well as on the pull request.

**Done when:** there is no command in the profile for this. Behaviour 0's permission, behaviour
1's read-back and behaviour 2's `MERGED` line and help lines; behaviour 3's outputs when it ran.

- [x] **Step 15.1: There is no test for this** Note: owner reported: reviewer gfsekamanya has admin; protection read back [true,1,[Validate skills and templates,Supply chain,Python lint,DCO sign-off]]. Deviation: PR #3 was merged by its author before main was protected (merge commit 2591577), so the first pull request had no review; the owner also deleted the remote branch. Recorded in CHANGELOG.md in PR #4

This task is the owner's: run behaviours 0, 1 and 2 in order, and behaviour 3 only if needed.

- [x] **Step 15.2: Hand over** Note: owner reported; stable checkout (origin gbi-solutions-ltd/keel) fast-forwarded a21b3eb..2591577 and keel --help shows both scan --leaks lines

Report the protection read-back and the merge commit.

---

### Task 16: Archive keel-internal, and stop the old checkout publishing anything (owner)

The owner runs this task. Archiving changes a repository setting; nothing is deleted.

**Files:** none. This task changes no file.

**Depends on:** task 15

**Behaviours:**

1. **Nothing is left behind in the old checkout.** Anything listed is carried into the new working
   copy by hand as a new change through a pull request, or recorded as abandoned; nothing is pushed
   to `keel-internal`.

   ```bash
   git -C "$OLD" status --porcelain
   git -C "$OLD" fetch origin
   git -C "$OLD" log --oneline v0.26.0..HEAD
   git -C "$OLD" log --oneline origin/main..HEAD
   ```

   Expected: the first command prints nothing; each `log` prints nothing, or only commits the
   report names as carried over or abandoned.

2. **Archive it, read-only.**

   ```bash
   gh repo archive gbi-solutions-ltd/keel-internal --yes
   gh api repos/gbi-solutions-ltd/keel-internal -q .archived    # true
   ```

3. **The old checkout cannot push anywhere by name, and is guarded if pushed by URL.** Its `origin`
   gets a push URL that cannot resolve, and the leak guard (now on `main`, which `keel` on PATH
   runs) is installed there too, so a push by URL meets the root-commit rule and the deny list.

   ```bash
   git -C "$OLD" remote set-url --push origin "archived-do-not-push"
   (cd "$OLD" && keel guard install --leak-guard && keel guard status)
   git -C "$OLD" push --dry-run origin HEAD     # fails: archived-do-not-push is not a repository
   ```

   `.git/keel-release/` in the old checkout is left as it is.

**Done when:** there is no command in the profile for this. Behaviour 2 prints `true`, and
behaviour 3's dry run fails as stated.

- [x] **Step 16.1: There is no test for this** Note: owner reported: old checkout clean but for the untracked early draft of this plan (abandoned), nothing ahead of v0.26.0 or origin/main; keel-internal archived 2026-10-24, witnessed in the browser: archived by the owner, read-only

This task is the owner's: run behaviours 1 to 3.

- [x] **Step 16.2: Hand over** Note: owner reported: push URL archived-do-not-push, dry run failed as expected; keel guard status shows push guard active and leak guard on with 25 patterns

Report the outputs, and the date of the archive for task 17.

---

### Task 17: A second pull request, and a push refused on purpose (owner)

The owner runs this task. It proves the flow end to end, and that the guard refuses.

**Files:**
- Modify: `CHANGELOG.md`

**Depends on:** task 16

**Behaviours:**

1. **The refused push, sending nothing.** A dry run, with an invented deny list, from a detached
   commit, so even a guard that failed open would send nothing and leave no branch.

   ```bash
   git switch --detach main
   printf '# an invented pattern for a probe\nZephyrprobe\n' > "$TMPDIR/probe-deny.txt"
   git commit --allow-empty -m "chore: probe Zephyrprobe"
   KEEL_DENY_FILE="$TMPDIR/probe-deny.txt" git push --dry-run origin \
       HEAD:refs/heads/probe/leak-guard > "$TMPDIR/probe.out" 2>&1
   echo "exit $?"
   cat "$TMPDIR/probe.out"
   grep -c Zephyrprobe "$TMPDIR/probe.out"
   git switch -q -
   ```

   Expected: `exit 1`, then among the lines of `probe.out` (with `<sha7>` the probe commit):

   ```text
   leak guard: deny list loaded from <TMPDIR>/probe-deny.txt (1 patterns)
   leak guard: <sha7> message line 1: deny list line 2
   leak guard: 1 finding(s)
   keel guard: push refused by the leak guard.
   error: failed to push some refs to '<the public repository's SSH URL>'
   ```

   and `grep -c` printing `0`: the push's own output never holds the probe word. The commit
   command and `git switch` print the commit's subject themselves, which is why the check reads the
   push's output alone. The `commit-msg` hook ran with the real list, which does not hold the
   probe word, so the commit itself was allowed.
2. **The second pull request.** A real change that could not have landed earlier: the
   `## Unreleased` entry of `CHANGELOG.md` gains the sentence "`gbi-solutions-ltd/keel-internal`
   was archived read-only on <the date from task 16>." The commit message deliberately carries a
   `Claude-Session:` line, to see the hook remove it.

   ```bash
   git switch -c docs/record-the-archive main
   # edit CHANGELOG.md as above
   git add CHANGELOG.md
   printf 'docs(changelog): record that keel-internal is archived\n\nClaude-Session: https://claude.ai/code/session_probe\n' > "$TMPDIR/msg"
   git commit -F "$TMPDIR/msg"
   git log -1 --format=%B                       # no Claude-Session line; a Signed-off-by line
   git push -u origin docs/record-the-archive
   gh pr create --repo gbi-solutions-ltd/keel --base main --fill
   ```

   Then CI passes, including `DCO sign-off`; `gfsekamanya` approves; the owner merges with
   `gh pr merge <n> --merge` and reads `MERGED <sha>` back as in task 15.

**Done when:** there is no command in the profile for this. Behaviour 1's output as given,
behaviour 2's `git log` showing a sign-off and no `Claude-Session`, and the second `MERGED` line.

- [x] **Step 17.1: There is no test for this** Note: owner reported, screenshot read: probe push dry run exit 1, finding on deny list line 2, push refused by the leak guard, grep count 0, detached commit so nothing sent; PR #4 witnessed: commit e960b99 has Signed-off-by and no Claude-Session line, DCO and other checks passed, merging blocked until review, then approved and merged by gfsekamanya as 8f6448d

This task is the owner's: run behaviours 1 and 2.

- [x] **Step 17.2: Hand over** Note: move complete; rounds: 0; routing: owner; loop: n/a

Report the outputs. The move is complete.

---

## Decided after review

Each of these was a planning assumption; the owner answered every one on 2026-10-22, and the plan
is written to the answer.

1. **The leak guard is opted into per repository** (`--leak-guard`), not switched on by the deny
   list's presence: on by presence would refuse the owner's pushes to client repositories that
   name their own client. Task 6.
2. **The `commit-msg` hook adds the sign-off** for the configured identity, and `CONTRIBUTING.md`
   says so. Without it, every commit an agent makes from a plan's `git commit -m` lacks one and
   every pull request fails the DCO job. Task 6, behaviour 7(b); task 9, behaviour 2.
3. **The leak guard fails closed,** at push and at commit, when `keel` is missing from PATH or too
   old to have the scan. This reverses, for the leak guard only, the 2026-09-27 choice the supply
   chain scan keeps, and `docs/03-install-and-distribution.md` says so. Task 6, behaviours 6, 7
   and 11.
4. **Three refusals beyond the deny list:** a pushed path the repository ignores (a force-added
   audit), a range holding a root commit (an unrelated history), and a `Claude-Session:` line in a
   pushed message. The root rule also refuses a push by URL or a first push to an empty
   repository, where `--no-verify` is the deliberate way. Task 5, behaviours 10, 10a and 11.
5. **Generic patterns apply to messages, identities and ref names as well as files,** so a commit
   message holding a developer home path is refused. Task 5, behaviour 12.
6. **The companion repository is private and named by the owner;** its name appears in no
   tracked file, this plan included: commands carry it as `$COMPANION` and `$AUDITS`. Task 1.
7. **`main` needs one approval, with `enforce_admins` on,** so the owner's own pull requests,
   release pull requests included, wait for `gfsekamanya`'s review. Task 15 checks the reviewer's
   write access first and says what unblocks a merge when the reviewer is unavailable.
8. **Pull requests are merged with merge commits** (`--merge`), so each release tag sits on a
   merge commit. Tasks 15 and 17.
9. **`tests/export-public.sh` is removed with `git rm`** in the first pull request. Task 4.
10. **`CONTRIBUTING.md`'s "No `Co-Authored-By`" is reversed** to match decision 3, and
    `conventions.no_attribution_footers` in `.keel/profile.json` is left true: it only stops the
    `Keel-Version` trailer. Task 9.
11. **`.claude/` is published:** both files are the generic output of `keel init`, carry no
    identifier, and already appear in `docs/06-repo-layout.md`. Tasks 2 and 11.

## Accepted risks

- **Binary files are not scanned** by the leak guard, as `tests/no-internal-leaks.sh` does not
  scan them: a client name inside an image or an archive goes unseen.
- **Nothing made on GitHub passes through a hook:** pull request titles and bodies, review
  comments, release notes, and merge commits made by the merge button. Task 10's runbook checks
  the body and notes files with `keel scan --leaks-message` before they are posted; nothing checks
  what is typed into GitHub directly.
- **`--no-verify` skips both hooks,** and a clone without the guard installed has no local check;
  CI's generic mode catches developer paths only. The `Claude-Session` push rule (task 5,
  behaviour 10a) catches the trailer whatever made the commit, on any machine where the guard is
  armed.
- **An agent session's `keel` may predate the leak guard** (risk 6): commits and pushes from such
  a session in this repository are refused until the installed plugin carries the leak guard or
  the session's PATH puts `$STABLE/bin` first.
- **The remote-tracking walk trusts refs that `git remote set-url` can make stale.** The root
  rule, and task 16's push URL on the old checkout, back it up; a stale ref on the new working copy
  under-checks.
- **The audits are checked by nothing.** They are records in a private repository, left out of
  the public checks on purpose (task 3, behaviour 6).

## Left out on purpose

None of these blocks a task; each is named so a reader does not take its absence for an oversight.

- **`docs/07-open-decisions.md` decision 2** still records the repository as private. It is a
  dated decision record, and its update belongs to the owner.
- **`docs/standards.md`'s note on the deny list** still describes moving it out of the tree as a
  plan. No task edits that file, since other documents cite its line numbers.
- **A tag ruleset** protecting `v*` tags from deletion or a move: worth adding, not decided.
- **Actions settings for first-time contributors' pull requests** stay at GitHub's default
  (approval required); revisit when outside contributions start.
- **A backup of the deny list** in the private companion repository would make a second machine
  quicker to set up and would widen where the list lives. Not planned.
- **Rewriting the SHA citations** before v0.26.0: decision 5 says not to.

## Found during execution

Recorded by the coordinator as the tasks ran, so the next reader of this plan sees where it and the
tree disagreed.

1. **Task 4, behaviour 1's example cannot print nothing.** `git grep -n export-public.sh -- tests
   bin lib hooks .github` still prints `tests/evals/results.md:2670`, a dated eval record that no
   task lists and that is history, not a procedure. It was left as it is.
2. **Task 5 leaves a gap that fails open.** A deny-list line that is not a valid regular expression
   makes `grep` exit 2; its stderr is discarded, so that pattern is silently never applied, and the
   scan still exits 0 and says it loaded the file. The task text asked for no behaviour here and the
   same gap exists in `tests/no-internal-leaks.sh`. Worth a follow-up: warn on stderr naming
   `deny list line <n>`, or exit 2.
3. **Task 7 prints one line the Interfaces block does not list.** For a base or head that is not a
   commit it prints `not a commit: <rev>` on stderr before exiting 2. Accepted as the diagnostic of
   a case the task only says exits 2.
4. **Task 10, behaviour 4 ordered the release steps so that CI was awaited before a pull request
   existed.** CI builds on pull requests and on pushes to `main` only (task 8), so the wait is now
   after `gh pr create`.
5. **Task 10 leaves one stale sentence.** The old first paragraph of section 7a of
   `docs/runbooks/going-public.md` still says the release runbook carries that section's export
   and sync steps. Section 7a is marked obsolete for this repository, and the file is an executed
   record, so it was not rewritten.
6. **Task 12, behaviour 5 expected `no findings` against a deny file holding the invented names,
   which cannot hold.** The new tests and this plan use those names as fixtures on purpose, so
   the guard correctly finds them (127 findings, all on the three invented lines). The generic
   patterns alone (no deny file) check 9 commits and find nothing, which is what the rehearsal
   was meant to prove. The owner's real deny list is the run that matters, in task 13.
7. **Task 12, behaviour 1 ran without the bundle from the owner.** The coordinator already held
   the branch's history, so the fresh clone was made from the cloud copy, and the commits were
   carried to the owner's working copy by a bundle fetched there (fast-forward, clean tree). The
   untracked `.claude/` and an older plan file that stood in the way were first copied to
   `.git/pre-ff/` in that working copy.
8. **Task 12, behaviour 4 (bash 3.2) was not run.** The device shell is a Linux VM with bash 5.1;
   only the owner's terminal has `/bin/bash` 3.2. It is handed to task 13.
